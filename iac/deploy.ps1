# PowerShell script to deploy the Bicep infrastructure template

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Prefix = "claims"
    ,
    [Parameter(Mandatory=$false)]
    [bool]$EnableOpenAI = $true
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting deployment of Claim Status API infrastructure..." -ForegroundColor Green

# Login to Azure (if not already logged in)
Write-Host "Checking Azure login status..."
try {
    $context = az account show --query "id" -o tsv 2>$null
    if ($context -ne $SubscriptionId) {
        Write-Host "Logging in to Azure..."
        az login
        az account set --subscription $SubscriptionId
    }
} catch {
    Write-Host "Logging in to Azure..."
    az login
    az account set --subscription $SubscriptionId
}

# Create resource group if it doesn't exist
Write-Host "Creating resource group: $ResourceGroupName"
az group create --name $ResourceGroupName --location $Location

# Deploy Bicep template
Write-Host "Deploying Bicep template..."
$deploymentName = "claims-api-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "main.bicep" `
    --parameters `
        prefix=$Prefix `
        location=$Location `
        environment=$Environment `
        enableOpenAI=$EnableOpenAI `
    --name $deploymentName `
    --verbose

# Get deployment outputs
Write-Host "Retrieving deployment outputs..."
$outputs = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

# Display important information
Write-Host "`n✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host "`n📋 Deployment Summary:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName"
Write-Host "  Container Registry: $($outputs.containerRegistryName.value)"
Write-Host "  Container App: $($outputs.containerAppName.value)"
Write-Host "  Container App URL: https://$($outputs.containerAppFqdn.value)"
Write-Host "  API Management: $($outputs.apiManagementName.value)"
Write-Host "  APIM Gateway URL: $($outputs.apiManagementGatewayUrl.value)"
Write-Host "  Azure OpenAI: $($outputs.openAiAccountName.value)"
Write-Host "  Log Analytics Workspace: $($outputs.logAnalyticsWorkspaceId.value)"

# Post-deploy: Inject OpenAI key & env var if enabled and resource deployed
if ($EnableOpenAI -and $outputs.openAiAccountName.value -ne 'disabled') {
    Write-Host "\n🔐 Fetching Azure OpenAI key and configuring Container App secret..." -ForegroundColor Cyan
    try {
        $openAiKey = az cognitiveservices account keys list `
            -g $ResourceGroupName `
            -n $outputs.openAiAccountName.value `
            --query key1 -o tsv
        if (-not $openAiKey) { throw 'OpenAI key retrieval returned empty value.' }

        $containerAppName = $outputs.containerAppName.value
        # Set secret
        az containerapp secret set -g $ResourceGroupName -n $containerAppName --secrets openai-api-key=$openAiKey | Out-Null

        # Patch environment to reference secret if not already present
        $hasKeyEnv = az containerapp show -g $ResourceGroupName -n $containerAppName --query "properties.template.containers[0].env[].name" -o tsv | Select-String -SimpleMatch 'AZURE_OPENAI_API_KEY'
        if (-not $hasKeyEnv) {
            Write-Host "Adding AZURE_OPENAI_API_KEY env var referencing secret..."
            az containerapp update -g $ResourceGroupName -n $containerAppName `
                --set-env-vars AZURE_OPENAI_API_KEY=secretref:openai-api-key | Out-Null
        } else {
            Write-Host "AZURE_OPENAI_API_KEY already present; skipping env patch." -ForegroundColor Yellow
        }
        Write-Host "✅ OpenAI secret injected and environment updated." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to inject OpenAI key: $_" -ForegroundColor Red
    }
} else {
    Write-Host "\nℹ️ OpenAI not enabled or account disabled—skipping key injection." -ForegroundColor Yellow
}

# Save outputs to file for CI/CD pipeline
$outputsFile = "deployment-outputs.json"
$outputs | ConvertTo-Json -Depth 10 | Out-File $outputsFile
Write-Host "`n💾 Deployment outputs saved to: $outputsFile"

Write-Host "`n🔧 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Build and push your container image to ACR"
Write-Host "2. (Optional) If OpenAI disabled, re-run with -EnableOpenAI:\n   pwsh ./deploy.ps1 -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -Location '$Location' -Environment $Environment -Prefix $Prefix -EnableOpenAI:$true"
Write-Host "3. Configure APIM API and policies"
Write-Host "4. Deploy Container App revision with your pushed image (if not already referenced)"
Write-Host "5. Test the API endpoints through APIM"

Write-Host "`n📚 Sample commands:" -ForegroundColor White
Write-Host "# Build and push image:"
Write-Host "docker build -t $($outputs.containerRegistryLoginServer.value)/claim-status-api:latest ."
Write-Host "az acr login --name $($outputs.containerRegistryName.value)"
Write-Host "docker push $($outputs.containerRegistryLoginServer.value)/claim-status-api:latest"
Write-Host ""
Write-Host "# Test Container App directly:"
Write-Host "curl https://$($outputs.containerAppFqdn.value)/health"
Write-Host "curl https://$($outputs.containerAppFqdn.value)/claims/CLM001"
if ($EnableOpenAI -and $outputs.openAiAccountName.value -ne 'disabled') {
    Write-Host "\n# Test summary endpoint (after image uses secret):" -ForegroundColor White
    Write-Host "curl https://$($outputs.containerAppFqdn.value)/claims/CLM001/summarize"
}
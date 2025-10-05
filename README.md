# Claim Status API with GenAI Summaries - Azure Container Apps Lab

This repository contains a complete implementation of the "Claim Status API with GenAI Summaries" hands-on lab, featuring a containerized Node.js API deployed on Azure Container Apps with comprehensive monitoring, security scanning, and AI-powered claim summarization.

## Architecture Overview

The solution implements a modern cloud-native architecture with the following components:

- **Azure Container Apps**: Serverless container hosting platform
- **Azure Container Registry**: Secure container image storage
- **Azure API Management**: API gateway with policies and rate limiting
- **Azure OpenAI**: GPT-3.5-turbo for claim summarization
- **Azure Log Analytics**: Centralized logging and monitoring
- **Azure Application Insights**: Application performance monitoring

## 📂 Project Structure

```
├── .env.example                    # Environment configuration template
├── .gitignore                      # Git ignore rules
├── Dockerfile                      # Container build configuration
├── package.json                    # Node.js dependencies and scripts
├── README.md                       # This documentation
├── .github/
│   └── workflows/
│       └── ci-cd.yml              # GitHub Actions CI/CD pipeline
├── apim/
│   ├── api-definition.json        # OpenAPI specification for APIM
│   ├── get-claim-policy.xml       # APIM policy for GET operations
│   ├── global-policy.xml          # Global APIM policies (CORS, routing)
│   └── post-summarize-policy.xml  # APIM policy for POST operations
├── iac/
│   ├── deploy.ps1                 # PowerShell deployment script
│   ├── deployment-outputs.json    # Generated deployment outputs
│   └── main.bicep                 # Infrastructure as Code template
├── mocks/
│   ├── claims.json                # Sample claim data (8 test claims)
│   └── notes.json                 # Claim notes for AI summarization
├── observability/
│   ├── alert-rules.md             # Azure Monitor alert configurations
│   ├── azure-workbook.md          # Monitoring dashboard JSON
│   └── kql-queries.md             # Log Analytics KQL queries
├── pipelines/
│   └── azure-pipelines.yml       # Azure DevOps pipeline
├── scans/                         # Security scan results (generated)
└── src/
    ├── aiService.js               # Azure OpenAI integration service
    └── server.js                  # Express.js API server
```

## 📋 Lab Objectives Implemented

✅ **API Development**: RESTful API with health checks and claim endpoints  
✅ **Containerization**: Docker container with security best practices  
✅ **Infrastructure as Code**: Complete Bicep templates for Azure resources  
✅ **Security Scanning**: Trivy vulnerability scanning in CI/CD pipeline  
✅ **API Management**: Gateway with rate limiting and authentication  
✅ **Observability**: Comprehensive monitoring with KQL queries and workbooks  
✅ **GenAI Integration**: Azure OpenAI for intelligent claim summaries  
✅ **CI/CD Pipeline**: Automated build, test, scan, and deployment  

## 🚀 Quick Start

### 1. Run Locally
```bash
# Copy environment file
cp .env.example .env

# Configure Azure OpenAI (optional - uses mocks if not set)
# Edit .env to add:
# AZURE_OPENAI_ENDPOINT=https://your-openai.openai.azure.com/
# AZURE_OPENAI_API_KEY=your-key
# AZURE_OPENAI_DEPLOYMENT_NAME=gpt-35-turbo

# Install and start
npm install
npm start

# Test endpoints
curl http://localhost:3000/health
curl http://localhost:3000/claims/CLM001
curl -X POST http://localhost:3000/claims/CLM001/summarize
```

### 2. Run with Docker
```bash
docker build -t claim-status-api .
docker run -p 3000:3000 --env-file .env claim-status-api
```

## ☁️ Deploy to Azure

### Option A: Automated Deployment (Recommended)
```bash
# Set your parameters
export SUBSCRIPTION_ID="<your-subscription-id>"
export RESOURCE_GROUP="claims-api-lab-rg"
export LOCATION="eastus"

# Deploy using the helper script
cd iac
pwsh ./deploy.ps1 -SubscriptionId $SUBSCRIPTION_ID -ResourceGroupName $RESOURCE_GROUP -Location $LOCATION -Environment dev -Prefix claims
cd ..
```

### Option B: Manual Step-by-Step Deployment
```bash
# 1. Create resource group
RESOURCE_GROUP="claims-api-lab-rg"
LOCATION="eastus"
az group create --name $RESOURCE_GROUP --location $LOCATION

# 2. Deploy infrastructure (generates names automatically)
DEPLOYMENT_NAME="claims-deploy-$(date +%s)"
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file iac/main.bicep \
  --parameters prefix=claims environment=dev \
  --name $DEPLOYMENT_NAME

# 3. Get generated resource names from deployment outputs
ACR_NAME=$(az deployment group show -g $RESOURCE_GROUP -n $DEPLOYMENT_NAME --query "properties.outputs.containerRegistryName.value" -o tsv)
ACR_LOGIN_SERVER=$(az deployment group show -g $RESOURCE_GROUP -n $DEPLOYMENT_NAME --query "properties.outputs.containerRegistryLoginServer.value" -o tsv)
CONTAINER_APP_NAME=$(az deployment group show -g $RESOURCE_GROUP -n $DEPLOYMENT_NAME --query "properties.outputs.containerAppName.value" -o tsv)
APIM_NAME=$(az deployment group show -g $RESOURCE_GROUP -n $DEPLOYMENT_NAME --query "properties.outputs.apiManagementName.value" -o tsv)
APIM_GATEWAY_URL=$(az deployment group show -g $RESOURCE_GROUP -n $DEPLOYMENT_NAME --query "properties.outputs.apiManagementGatewayUrl.value" -o tsv)

echo "Generated Resources:"
echo "  ACR: $ACR_NAME"
echo "  Container App: $CONTAINER_APP_NAME" 
echo "  APIM: $APIM_NAME"
echo "  Gateway URL: $APIM_GATEWAY_URL"

# 4. Build and push container image
az acr login --name $ACR_NAME
IMAGE_TAG="$ACR_LOGIN_SERVER/claim-status-api:1.0.0"
docker build -t $IMAGE_TAG .
docker push $IMAGE_TAG

# 5. Update Container App with new image
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --image $IMAGE_TAG

# 6. Import API definition into APIM
az apim api import \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --path claim-status \
  --api-id claim-status-api \
  --specification-format OpenApi \
  --specification-path apim/api-definition.json

# 7. Get subscription key and test
SUBSCRIPTION_KEY=$(az apim subscription list \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --query "[0].primaryKey" -o tsv)

echo "Testing API endpoints:"
curl -i "$APIM_GATEWAY_URL/claim-status/health" -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY"
curl -i "$APIM_GATEWAY_URL/claim-status/claims/CLM001" -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY"
curl -i -X POST "$APIM_GATEWAY_URL/claim-status/claims/CLM001/summarize" -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY"
```

> **Important:** 
> - Resource names are auto-generated as `${prefix}-${type}-${environment}` (e.g., `claims-apim-dev`)
> - Always use deployment outputs to get actual names
> - The API is imported with `--path claim-status`, so URLs include that prefix when accessed through APIM

### Direct Container App Testing (Bypass APIM)
```bash
# Test Container App directly (no subscription key needed)
CONTAINER_APP_FQDN=$(az deployment group show -g $RESOURCE_GROUP -n $DEPLOYMENT_NAME --query "properties.outputs.containerAppFqdn.value" -o tsv)
curl https://$CONTAINER_APP_FQDN/health
curl https://$CONTAINER_APP_FQDN/claims/CLM001
curl -X POST https://$CONTAINER_APP_FQDN/claims/CLM001/summarize
```

## 📋 **Important Notes**

### Resource Naming Convention
All Azure resources use the pattern `${prefix}-${type}-${environment}`:
- Container Registry: `claimsacr{uniqueId}` (ACR names must be globally unique)
- Container App: `claims-api-dev`
- API Management: `claims-apim-dev` 
- Azure OpenAI: `claims-openai-dev`

### API Testing Paths
- **APIM Gateway**: `https://claims-apim-dev.azure-api.net/claim-status/claims/CLM001`
- **Direct Container**: `https://claims-api-dev.eastus.azurecontainerapps.io/claims/CLM001`

> Note: APIM imports with `--path claim-status`, so all endpoints include this prefix when accessed through APIM.

### Claim ID Validation
Both server and APIM enforce the pattern `CLM###` (e.g., CLM001, CLM002).
Invalid formats return 400 Bad Request.

## 🔗 API Endpoints

### Base URLs
- **Local**: `http://localhost:3000`
- **APIM**: `https://claims-apim-dev.azure-api.net/claim-status`
- **Container App Direct**: `https://claims-api-dev.thankfulmushroom-f9e1ca60.eastus.azurecontainerapps.io`

### Available Test Claims
The API includes 8 predefined test claims with notes for AI summarization:

| Claim ID | Type | Status | Amount | Description |
|----------|------|--------|--------|-------------|
| CLM001 | auto | submitted | $8,500 | Rear-end collision at traffic intersection |
| CLM002 | property | under_review | $15,000 | Water damage from burst pipe in basement |
| CLM003 | auto | approved | $3,200 | Hail damage to vehicle windshield and hood |
| CLM004 | health | pending_documents | $2,500 | Emergency room visit for chest pain |
| CLM005 | property | in_progress | $12,000 | Fire damage to kitchen from electrical fault |
| CLM006 | auto | rejected | $4,500 | Single vehicle accident - hit guardrail |
| CLM007 | health | settled | $1,800 | Urgent care visit for broken finger |
| CLM008 | property | submitted | $7,500 | Storm damage to roof and siding |

### Endpoints

#### Health Check
```http
GET /health
```
Returns service health status and dependency information.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-23T10:30:00Z",
  "service": "claim-status-api",
  "version": "1.0.0",
  "dependencies": {
    "mockData": {
      "claims": 8,
      "notes": 5
    },
    "azureOpenAI": "connected" // or "mock_mode"
  }
}
```

#### Get Claim Information
```http
GET /claims/{id}
```
**Parameters:**
- `id`: Claim ID in format `CLM###` (e.g., CLM001, CLM002, etc.)

**Response:**
```json
{
  "id": "CLM001",
  "claimNumber": "CLM001",
  "type": "auto",
  "status": "submitted",
  "customerName": "John Smith",
  "customerEmail": "john.smith@email.com",
  "incidentDate": "2024-01-15",
  "estimatedAmount": 8500,
  "description": "Rear-end collision at traffic intersection",
  "priority": "medium",
  "createdDate": "2024-01-15T09:30:00Z"
}
```

#### Generate Claim Summary
```http
POST /claims/{id}/summarize
```
**Parameters:**
- `id`: Claim ID in format `CLM###` (e.g., CLM001)

**Response:**
```json
{
  "claimId": "CLM001",
  "summary": "Auto insurance claim for rear-end collision at traffic intersection with estimated damages of $8,500.",
  "customerSummary": "Your claim CLM001 is being processed. The incident involved rear-end collision damage, and we're reviewing the police report and repair estimates.",
  "adjusterSummary": "Vehicle damage assessment shows significant rear bumper and trunk damage. Police report confirms other driver at fault. Repair estimate of $8,200 from certified shop appears reasonable.",
  "nextStep": "Schedule vehicle inspection and finalize repair authorization",
  "generatedAt": "2024-01-23T10:30:00Z"
}
```

**Error Responses:**
- `400 Bad Request`: Invalid claim ID format
- `404 Not Found`: Claim not found or no notes available
- `500 Internal Server Error`: AI service error or processing failure

## Azure OpenAI Integration

### Setup Steps

1. **Create Azure OpenAI Resource**
   ```bash
   # Create Azure OpenAI resource
   az cognitiveservices account create \
     --name "claims-openai-dev" \
     --resource-group "claims-api-lab-rg" \
     --location "eastus" \
     --kind "OpenAI" \
     --sku "S0" \
     --custom-domain "claims-openai-dev"
   
   # Get the endpoint and key
   OPENAI_ENDPOINT=$(az cognitiveservices account show \
     --name "claims-openai-dev" \
     --resource-group "claims-api-lab-rg" \
     --query "properties.endpoint" -o tsv)
   
   OPENAI_KEY=$(az cognitiveservices account keys list \
     --name "claims-openai-dev" \
     --resource-group "claims-api-lab-rg" \
     --query "key1" -o tsv)
   
   echo "OpenAI Endpoint: $OPENAI_ENDPOINT"
   echo "OpenAI Key: $OPENAI_KEY"
   ```

2. **Deploy GPT-3.5-turbo Model**
   ```bash
   # Deploy the GPT-3.5-turbo model
   az cognitiveservices account deployment create \
     --name "claims-openai-dev" \
     --resource-group "claims-api-lab-rg" \
     --deployment-name "gpt-35-turbo" \
     --model-name "gpt-35-turbo" \
     --model-version "0613" \
     --model-format "OpenAI" \
     --sku-capacity 10 \
     --sku-name "Standard"
   
   # Verify deployment
   az cognitiveservices account deployment show \
     --name "claims-openai-dev" \
     --resource-group "claims-api-lab-rg" \
     --deployment-name "gpt-35-turbo"
   ```

3. **Configure Environment Variables**:
   ```bash
   AZURE_OPENAI_ENDPOINT=https://claims-openai-dev.openai.azure.com/
   AZURE_OPENAI_API_KEY=your-api-key
   AZURE_OPENAI_DEPLOYMENT_NAME=gpt-35-turbo
   ```

### AI Features
- **Fallback to Mocks**: If OpenAI isn't configured, API returns realistic mock summaries
- **Token Usage Tracking**: Logs token consumption for cost monitoring
- **Error Handling**: Graceful degradation when AI service is unavailable
- **Input Validation**: Limits notes text to 4000 characters for token management

### Cost Management
- **Typical Usage**: ~150-200 tokens per summary
- **Estimated Cost**: $0.0003 per summary (GPT-3.5-turbo pricing)
- **Monitoring**: Check logs for `TokensUsed: <n>` entries

## Observability & Monitoring

### Pre-built Monitoring Assets

#### 1. KQL Queries ([`observability/kql-queries.md`](observability/kql-queries.md))
Ready-to-use Log Analytics queries for:
- API performance monitoring (response times, error rates)
- Container resource utilization
- AI summary generation metrics
- Security and authentication monitoring
- Business intelligence (popular claims, usage patterns)

**Example Query - Error Rate Analysis:**
```kql
ContainerAppConsoleLogs_CL
| where ContainerName_s == "claim-status-api"
| where Log_s contains "Request completed"
| extend StatusCode = extract(@"Status: (\d+)", 1, Log_s)
| summarize 
    TotalRequests = count(),
    ErrorRequests = countif(toint(StatusCode) >= 400),
    ErrorRate = round(100.0 * countif(toint(StatusCode) >= 400) / count(), 2)
    by bin(TimeGenerated, 5m)
| render timechart
```

#### 2. Azure Monitor Workbook ([`observability/azure-workbook.md`](observability/azure-workbook.md))
Comprehensive monitoring dashboard with:
- API performance overview
- Container health metrics
- GenAI operations tracking
- APIM analytics
- Business intelligence visualizations

#### 3. Alert Rules ([`observability/alert-rules.md`](observability/alert-rules.md))
Pre-configured alerts for:
- High error rates (>10% in 5 minutes)
- High response times (P95 > 5 seconds)
- Container resource exhaustion (>80% CPU/memory)
- AI service failures
- Security violations

### Quick Monitoring Commands
```bash
# View live logs
az containerapp logs show -n claims-api-dev -g claims-api-lab-rg --follow

# Check container status
az containerapp show -n claims-api-dev -g claims-api-lab-rg --query "properties.runningStatus"

# View recent revisions
az containerapp revision list -n claims-api-dev -g claims-api-lab-rg --query "[].{name:name,active:properties.active,createdTime:properties.createdTime}"
```

## CI/CD Pipelines

This project supports both GitHub Actions and Azure DevOps pipelines for maximum flexibility.

### GitHub Actions (Recommended)

The GitHub Actions workflow provides a comprehensive CI/CD pipeline with security scanning, dynamic resource discovery, and automated deployment.

#### Features
- ✅ **Multi-stage pipeline**: Build → Security Scan → Deploy
- ✅ **Trivy security scanning** with configurable gates
- ✅ **Dynamic resource discovery** (finds Container Apps and APIM automatically)
- ✅ **APIM integration** with API definition import
- ✅ **Environment protection** for production deployments
- ✅ **Comprehensive logging** and deployment summaries

#### Setup Instructions

1. **Fork/Clone Repository**
   ```bash
   git clone https://github.com/gautamkumar121989/claim-status-api.git
   cd claim-status-api
   ```

2. **Configure GitHub Secrets**
   Go to your repository → Settings → Secrets and variables → Actions, and add:
   
   ```bash
   # Azure Container Registry
   REGISTRY_USERNAME=claimsacrcna
   REGISTRY_PASSWORD=<your-acr-admin-password>
   
   # Azure Service Principal (for deployment)
   AZURE_CREDENTIALS='{
     "clientId": "<service-principal-client-id>",
     "clientSecret": "<service-principal-secret>",
     "subscriptionId": "<subscription-id>",
     "tenantId": "<tenant-id>"
   }'
   ```

3. **Create Azure Service Principal**
   ```bash
   # Create service principal with contributor access to resource group
   az ad sp create-for-rbac \
     --name "github-actions-claims-api" \
     --role contributor \
     --scopes "/subscriptions/<subscription-id>/resourceGroups/claims-api-lab-rg" \
     --sdk-auth
   
   # Copy the JSON output to AZURE_CREDENTIALS secret
   ```

4. **Update Environment Variables**
   
   Edit the workflow file [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml) to match your setup:
   ```yaml
   env:
     REGISTRY: claimsacrcna.azurecr.io  # Your ACR login server
     IMAGE_NAME: claim-status-api
     RESOURCE_GROUP: claims-api-lab-rg  # Your resource group
     BICEP_PREFIX: claims
     BICEP_ENVIRONMENT: dev
   ```

5. **Trigger Deployment**
   ```bash
   # Push to master or develop branch
   git add .
   git commit -m "Initial deployment"
   git push origin master
   ```

#### Workflow Stages

**Stage 1: Build**
- Builds Docker image with metadata
- Pushes to Azure Container Registry
- Tags image with branch name, SHA, and build number

**Stage 2: Security Scan**
- Pulls built image from ACR
- Runs Trivy vulnerability scanner
- Creates security report and summary
- Fails on critical vulnerabilities (master branch only)

**Stage 3: Deploy** (master branch only)
- Discovers Azure resources dynamically
- Updates Container App with new image
- Configures APIM backend and imports API definition
- Provides deployment summary with URLs

#### Monitoring the Pipeline

1. **View Workflow Runs**
   - Go to your repository → Actions tab
   - Click on the latest workflow run to see details

2. **Check Deployment Status**
   ```bash
   # View Container App status
   az containerapp show -n <container-app-name> -g <resource-group> --query "properties.runningStatus"
   
   # Check logs
   az containerapp logs show -n <container-app-name> -g <resource-group> --follow
   ```

3. **Test Deployed API**
   ```bash
   # Get APIM subscription key
   SUBSCRIPTION_KEY=$(az apim subscription list \
     --resource-group <resource-group> \
     --service-name <apim-name> \
     --query "[0].primaryKey" -o tsv)
   
   # Test endpoints
   curl -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
     https://<apim-gateway>/claim-status/health
   ```

### Azure DevOps (Alternative)

For organizations using Azure DevOps, a comprehensive pipeline is also available.

#### Setup Instructions

1. **Import Repository**
   - Create new Azure DevOps project
   - Import this Git repository

2. **Create Service Connections**
   ```bash
   # Azure Resource Manager connection
   # - Connection name: azure-subscription
   # - Scope: Resource Group
   # - Resource Group: claims-api-lab-rg
   
   # Container Registry connection  
   # - Connection name: acr-connection
   # - Registry: claimsacrcna.azurecr.io
   ```

3. **Configure Variables**
   
   Create variable group `claim-api-variables`:
   ```yaml
   # Pipeline Variables
   dockerRegistryServiceConnection: 'acr-connection'
   containerRegistry: 'claimsacrcna.azurecr.io'
   imageRepository: 'claim-status-api'
   resourceGroupName: 'claims-api-lab-rg'
   bicepPrefix: 'claims'
   bicepEnvironment: 'dev'
   ```

4. **Create Pipeline**
   - New Pipeline → Azure Repos Git
   - Select repository
   - Existing Azure Pipelines YAML file
   - Path: `/pipelines/azure-pipelines.yml`

#### Pipeline Stages

**Stage 1: Build**
- Builds and pushes Docker image to ACR
- Tags with build ID and latest

**Stage 2: Security Scan**
- Installs Trivy scanner
- Scans container image for vulnerabilities
- Publishes security scan artifacts
- Configurable security gate for critical vulnerabilities

**Stage 3: Deploy**
- Gets resource names from Bicep deployment outputs
- Updates Container App with new image
- Configures APIM backend URL

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| **404 on claim endpoints** | API not imported to APIM | Re-run API import step with correct path |
| **401 Unauthorized** | Missing subscription key | Add `Ocp-Apim-Subscription-Key` header |
| **Empty AI summaries** | OpenAI not configured | Set Azure OpenAI environment variables in Container App |
| **Container not updating** | Old revision active | Check `az containerapp revision list` and set traffic |
| **Pipeline failures** | Resource name mismatch | Use dynamic name resolution in pipeline |
| **ACR login failures** | Incorrect credentials | Verify ACR admin user is enabled and credentials are correct |
| **Deployment timeouts** | Resource dependencies | Check resource creation order in Bicep template |

### Security Scan Issues

| Scan Result | Action Required |
|-------------|----------------|
| **Critical vulnerabilities on master** | Pipeline fails - update base image |
| **High vulnerabilities** | Warning only - monitor and plan updates |
| **Medium/Low vulnerabilities** | Informational - no action required |

### Debugging Commands

```bash
# Check all resources in resource group
az resource list -g claims-api-lab-rg --output table

# Verify Container App is running
az containerapp show -n claims-api-dev -g claims-api-lab-rg --query "properties.runningStatus"

# Check Container App logs for errors
az containerapp logs show -n claims-api-dev -g claims-api-lab-rg --follow

# Test direct Container App endpoint (bypass APIM)
curl https://claims-api-dev.thankfulmushroom-f9e1ca60.eastus.azurecontainerapps.io/health

# Test APIM endpoint with subscription key
curl -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" https://claims-apim-dev.azure-api.net/claim-status/health

# Check OpenAI integration status
curl -X POST https://claims-api-dev.thankfulmushroom-f9e1ca60.eastus.azurecontainerapps.io/claims/CLM001/summarize
```

### Resource Naming Issues

If you encounter resource naming problems:

1. **Check deployment outputs**:
   ```bash
   az deployment group show -g claims-api-lab-rg -n $DEPLOYMENT_NAME --query "properties.outputs"
   ```

2. **Verify resource names match pipeline variables**:
   ```bash
   # List actual resource names
   az containerapp list -g claims-api-lab-rg --query "[].name" -o table
   az apim list -g claims-api-lab-rg --query "[].name" -o table
   ```

3. **Update pipeline variables** to match actual resource names

## Cleanup

### Complete Resource Cleanup
```bash
# Delete entire resource group (removes all resources)
az group delete -n claims-api-lab-rg --yes --no-wait
```

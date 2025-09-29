# Claim Status API with GenAI Summaries - Azure Container Apps Lab

[![Build Status](https://dev.azure.com/your-org/your-project/_apis/build/status/claim-status-api?branchName=main)](https://dev.azure.com/your-org/your-project/_build/latest?definitionId=1&branchName=main)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Azure](https://img.shields.io/badge/Azure-Container%20Apps-blue)](https://azure.microsoft.com/en-us/products/container-apps)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green)](https://nodejs.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue)](https://www.docker.com/)

This repository contains a complete implementation of the "Claim Status API with GenAI Summaries" hands-on lab, featuring a containerized Node.js API deployed on Azure Container Apps with comprehensive monitoring, security scanning, and AI-powered claim summarization.

## 🏗️ Architecture Overview

The solution implements a modern cloud-native architecture with the following components:

- **Azure Container Apps**: Serverless container hosting platform
- **Azure Container Registry**: Secure container image storage
- **Azure API Management**: API gateway with policies and rate limiting
- **Azure OpenAI**: GPT-3.5-turbo for claim summarization
- **Azure Log Analytics**: Centralized logging and monitoring
- **Azure Application Insights**: Application performance monitoring

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
export RESOURCE_GROUP="<your-resource-group>"
export LOCATION="<your-region>"

# Deploy using the helper script
cd iac
pwsh ./deploy.ps1 -SubscriptionId $SUBSCRIPTION_ID -ResourceGroupName $RESOURCE_GROUP -Location $LOCATION -Environment dev -Prefix claims
cd ..
```

### Option B: Manual Step-by-Step Deployment
```bash
# 1. Create resource group
RESOURCE_GROUP="<your-resource-group>"
LOCATION="<your-region>"
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
- **Direct Container**: `https://claims-api-dev.{region}.azurecontainerapps.io/claims/CLM001`

> Note: APIM imports with `--path claim-status`, so all endpoints include this prefix when accessed through APIM.

### Claim ID Validation
Both server and APIM enforce the pattern `CLM###` (e.g., CLM001, CLM002).
Invalid formats return 400 Bad Request.

## 🔗 API Endpoints

### Base URLs
- **Local**: `http://localhost:3000`
- **APIM**: `https://<your-apim>.azure-api.net/claim-status`
- **Container App Direct**: `https://<container-app-fqdn>`

### Endpoints

#### Health Check
```http
GET /health
```
Returns service health status.

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
  "summary": "General claim summary",
  "customerSummary": "Customer-friendly summary",
  "adjusterSummary": "Technical summary for adjusters", 
  "nextStep": "Recommended next action",
  "generatedAt": "2024-01-23T10:30:00Z"
}
```

## 📊 Observability & Monitoring

### View Live Logs
```bash
az containerapp logs show -n $APP_NAME -g $RESOURCE_GROUP --follow
```

### Run KQL Queries
In Azure Portal → Log Analytics workspace:
- Copy queries from `observability/kql-queries.md`
- Example (Requests & Latency):
```kql
ContainerAppConsoleLogs_CL
| where ContainerName_s == "claim-status-api"
| where Log_s contains "Request completed"
| extend StatusCode = extract(@"Status: (\\d+)", 1, Log_s)
| summarize count() by StatusCode, bin(TimeGenerated, 5m)
```

### AI Summary Metrics
Look for log lines: `AI summary generated - ClaimId: CLM001; ProcessingTime: <ms>; TokensUsed: <n>`

### Alerts
Deploy manually (Portal) or convert `observability/alert-rules.md` into ARM/CLI. (Future enhancement: add Bicep module.)

## 🔄 CI/CD Pipelines

This project supports both GitHub Actions and Azure DevOps pipelines for maximum flexibility.

### 🐙 GitHub Actions (Recommended)

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
   git clone <your-repo-url>
   cd claim-status-api
   ```

2. **Configure GitHub Secrets**
   Go to your repository → Settings → Secrets and variables → Actions, and add:
   
   ```bash
   # Azure Container Registry
   REGISTRY_USERNAME=<your-acr-name>
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
     --scopes "/subscriptions/<subscription-id>/resourceGroups/<your-resource-group>" \
     --sdk-auth
   
   # Copy the JSON output to AZURE_CREDENTIALS secret
   ```

4. **Update Environment Variables**
   
   Edit the workflow file [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml) to match your setup:
   ```yaml
   env:
     REGISTRY: <your-acr-name>.azurecr.io  # Your ACR login server
     IMAGE_NAME: claim-status-api
     RESOURCE_GROUP: <your-resource-group>  # Your resource group
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
     https://<apim-gateway>/api/claims/health
   ```

### 🔷 Azure DevOps (Alternative)

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
   # - Resource Group: <your-resource-group>
   
   # Container Registry connection  
   # - Connection name: acr-connection
   # - Registry: <your-acr-name>.azurecr.io
   ```

3. **Configure Variables**
   
   Create variable group `claim-api-variables`:
   ```yaml
   # Pipeline Variables
   dockerRegistryServiceConnection: 'acr-connection'
   containerRegistry: '<your-acr-name>.azurecr.io'
   imageRepository: 'claim-status-api'
   resourceGroupName: '<your-resource-group>'
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

## 🧹 Cleanup
```bash
az group delete -n $RESOURCE_GROUP --yes --no-wait
```

// Main Bicep template for Claim Status API infrastructure
// Deploys: Container Registry, Container Apps Environment, Container App, API Management, Azure OpenAI, Log Analytics

targetScope = 'resourceGroup'

// ----------------- Parameters -----------------
@description('Prefix for all resource names')
param prefix string = 'claims'

@description('Deployment environment (dev|staging|prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'dev'

@description('Azure region for core resources')
param location string = resourceGroup().location

@description('Container image tag (repository: claim-status-api)')
param imageTag string = 'latest'

@description('Azure OpenAI model deployment name inside the OpenAI resource')
param openAiDeploymentName string = 'gpt-35-turbo'

@description('Enable Azure OpenAI resources (set false if subscription not approved)')
param enableOpenAI bool = true

@description('Region for Azure OpenAI (must be an approved OpenAI region)')
param openAiLocation string = 'eastus'

@description('Set to false to use an existing ACR instead of creating one')
param createNewAcr bool = false

@description('The name of the existing ACR to use if createNewAcr is false')
param existingAcrName string = 'claimsacrcna'

// (Removed openAiCapacity; deployment uses default shared capacity for non-provisioned model)

@description('ACR SKU')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Standard'

@description('Common tags')
param commonTags object = {
  project: 'claim-status-api'
  env: environment
}

// ----------------- Variables -----------------
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var acrName = createNewAcr ? '${prefix}acr${uniqueSuffix}' : existingAcrName
var containerAppName = '${prefix}-api-${environment}'
var containerAppEnvironmentName = '${prefix}-env-${environment}'
var apimName = '${prefix}-apim-${environment}'
var openAiName = '${prefix}openai${environment}'          // no hyphens for subdomain
var openAiSubdomain = toLower(openAiName)
var logAnalyticsName = '${prefix}-logs-${environment}'
var appInsightsName = '${prefix}-appi-${environment}'
// Derive ACR credentials safely
var acrCredentials = acr.listCredentials()
var acrPassword = length(acrCredentials.passwords) > 0 ? acrCredentials.passwords[0].value : ''
// OpenAI key variable only resolved when enabled (avoids null resource reference warning)
// Build OpenAI related env var objects only if enabled
// Construct OpenAI endpoint from subdomain to avoid property access on conditional resource
// Construct endpoint deterministically; key will be injected post-deploy via script (Option D)
var constructedOpenAiEndpoint = 'https://${openAiSubdomain}.openai.azure.com/'
// (No conditional env var list needed after making OpenAI mandatory)

// ----------------- Log Analytics -----------------
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// ----------------- ACR -----------------
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = if (createNewAcr) {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  tags: commonTags
  properties: {
    adminUserEnabled: true
    policies: {
      retentionPolicy: {
        days: 7
        status: 'enabled'
      }
    }
  }
}

// Reference to existing or newly created ACR
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: acrName
}

// ----------------- Container Apps Environment -----------------
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvironmentName
  location: location
  tags: commonTags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// ----------------- Application Insights -----------------
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: commonTags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ----------------- Azure OpenAI (conditional) -----------------
resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = if (enableOpenAI) {
  name: openAiName
  location: openAiLocation
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  tags: union(commonTags, { component: 'openai' })
  properties: {
    customSubDomainName: openAiSubdomain
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

resource openAiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = if (enableOpenAI) {
  parent: openAiAccount
  name: openAiDeploymentName
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-35-turbo'
      version: '0125'
    }
    raiPolicyName: 'Microsoft.Default'
  }
}

// ----------------- API Management -----------------
resource apiManagement 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: apimName
  location: location
  tags: commonTags
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: 'admin@${prefix}.com'
    publisherName: '${prefix} API Publisher'
    notificationSenderEmail: 'apimgmt-noreply@mail.windowsazure.com'
  }
}

// APIM Logger
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-03-01-preview' = {
  parent: apiManagement
  name: 'applicationinsights-logger'
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsights.properties.InstrumentationKey
    }
    isBuffered: true
  }
}

// ----------------- Container App -----------------
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  tags: commonTags
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 3000
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.name
          passwordSecretRef: 'acr-password'
        }
      ]
      // Secrets: only ACR initially. OpenAI API key added post-deploy via script.
      secrets: [
        {
          name: 'acr-password'
          value: acrPassword
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'claim-status-api'
          image: '${acr.properties.loginServer}/claim-status-api:${imageTag}'
          // Environment variables (no API key yet; will be patched after secret injection)
          env: concat([
            {
              name: 'NODE_ENV'
              value: 'production'
            }
            {
              name: 'PORT'
              value: '3000'
            }
          ], enableOpenAI ? [
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: constructedOpenAiEndpoint
            }
            {
              name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
              value: openAiDeploymentName
            }
          ] : [])
          resources: {
            cpu: 1
            memory: '2.0Gi'
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3000
              }
              initialDelaySeconds: 30
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 3000
              }
              initialDelaySeconds: 5
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 5
        rules: [
          {
            name: 'http-scaling-rule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: enableOpenAI ? [ openAiDeployment ] : []
}

// ----------------- APIM Backend -----------------
resource apimBackend 'Microsoft.ApiManagement/service/backends@2023-03-01-preview' = {
  parent: apiManagement
  name: 'claim-status-backend'
  properties: {
    description: 'Claim Status API Backend'
    url: 'https://${containerApp.properties.configuration.ingress.fqdn}'
    protocol: 'https'
    credentials: {
      header: {
        'Content-Type': [
          'application/json'
        ]
      }
    }
  }
}

// ----------------- Outputs -----------------
output containerRegistryName string = acr.name
output containerRegistryLoginServer string = acr.properties.loginServer
output containerAppName string = containerApp.name
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
output apiManagementName string = apiManagement.name
output apiManagementGatewayUrl string = apiManagement.properties.gatewayUrl
output openAiEnabled bool = enableOpenAI
output openAiAccountName string = enableOpenAI ? openAiAccount.name : 'disabled'
output openAiEndpoint string = enableOpenAI ? constructedOpenAiEndpoint : ''
output logAnalyticsWorkspaceId string = logAnalytics.properties.customerId

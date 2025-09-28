# Azure Monitor Workbook Configuration

This workbook provides comprehensive monitoring and observability for the Claim Status API deployed on Azure Container Apps.

## Workbook JSON Configuration

```json
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# Claim Status API - Monitoring Dashboard\n\nComprehensive monitoring dashboard for the containerized Claim Status API with GenAI summaries.\n\n---"
      },
      "name": "title"
    },
    {
      "type": 9,
      "content": {
        "version": "KqlParameterItem/1.0",
        "parameters": [
          {
            "id": "timeRange",
            "version": "KqlParameterItem/1.0",
            "name": "TimeRange",
            "type": 4,
            "isRequired": true,
            "value": {
              "durationMs": 3600000
            },
            "typeSettings": {
              "selectableValues": [
                {
                  "durationMs": 300000
                },
                {
                  "durationMs": 900000
                },
                {
                  "durationMs": 1800000
                },
                {
                  "durationMs": 3600000
                },
                {
                  "durationMs": 14400000
                },
                {
                  "durationMs": 43200000
                },
                {
                  "durationMs": 86400000
                }
              ]
            }
          }
        ]
      },
      "name": "parameters"
    },
    {
      "type": 1,
      "content": {
        "json": "## API Performance Overview"
      },
      "name": "apiPerformanceTitle"
    },
    {
      "type": 10,
      "content": {
        "chartId": "workbook-chart-1",
        "version": "MetricsItem/2.0",
        "size": 0,
        "aggregation": 5,
        "timeContext": {
          "durationMs": 0
        },
        "timeContextFromParameter": "TimeRange",
        "resourceType": "microsoft.app/containerapps",
        "metricScope": 0,
        "resourceParameter": "containerApp",
        "metrics": [
          {
            "namespace": "microsoft.app/containerapps",
            "metric": "microsoft.app/containerapps-Requests",
            "aggregation": 1
          },
          {
            "namespace": "microsoft.app/containerapps",
            "metric": "microsoft.app/containerapps-RequestDuration",
            "aggregation": 4
          }
        ],
        "title": "Request Volume and Response Times",
        "gridSettings": {
          "rowLimit": 10000
        }
      },
      "customWidth": "50",
      "name": "requestMetrics"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ContainerAppConsoleLogs_CL\r\n| where ContainerName_s == \"claim-status-api\"\r\n| where Log_s contains \"Request completed\"\r\n| extend StatusCode = extract(@\"Status: (\\d+)\", 1, Log_s)\r\n| summarize \r\n    TotalRequests = count(),\r\n    ErrorRequests = countif(toint(StatusCode) >= 400)\r\n| extend ErrorRate = round(100.0 * ErrorRequests / TotalRequests, 2)\r\n| project ErrorRate, TotalRequests, ErrorRequests",
        "size": 3,
        "title": "Error Rate Summary",
        "timeContext": {
          "durationMs": 0
        },
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "tiles",
        "tileSettings": {
          "titleContent": {
            "columnMatch": "ErrorRate",
            "formatter": 1,
            "formatOptions": {
              "suffix": "%"
            }
          },
          "leftContent": {
            "columnMatch": "TotalRequests",
            "formatter": 12,
            "formatOptions": {
              "palette": "auto"
            }
          },
          "secondaryContent": {
            "columnMatch": "ErrorRequests",
            "formatter": 1
          },
          "showBorder": true
        }
      },
      "customWidth": "50",
      "name": "errorRateTile"
    },
    {
      "type": 1,
      "content": {
        "json": "## Container Health & Resources"
      },
      "name": "containerHealthTitle"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "InsightsMetrics\r\n| where Name in (\"cpuUsageNanoCores\", \"memoryWorkingSetBytes\")\r\n| where parse_json(Tags)[\"container.azm.ms/containername\"] == \"claim-status-api\"\r\n| extend ResourceType = case(\r\n    Name == \"cpuUsageNanoCores\", \"CPU Usage %\",\r\n    Name == \"memoryWorkingSetBytes\", \"Memory Usage MB\",\r\n    \"Unknown\"\r\n)\r\n| extend Value = case(\r\n    ResourceType == \"CPU Usage %\", Val / 1000000000 * 100,\r\n    ResourceType == \"Memory Usage MB\", Val / 1024 / 1024,\r\n    Val\r\n)\r\n| summarize \r\n    AvgValue = avg(Value),\r\n    MaxValue = max(Value)\r\n    by bin(TimeGenerated, 5m), ResourceType\r\n| render timechart",
        "size": 0,
        "title": "Container Resource Utilization",
        "timeContext": {
          "durationMs": 0
        },
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "name": "resourceUtilization"
    },
    {
      "type": 1,
      "content": {
        "json": "## GenAI Operations"
      },
      "name": "genAITitle"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ContainerAppConsoleLogs_CL\r\n| where ContainerName_s == \"claim-status-api\"\r\n| where Log_s contains \"AI summary generated\"\r\n| extend \r\n    ProcessingTime = extract(@\"ProcessingTime: (\\d+)ms\", 1, Log_s),\r\n    TokensUsed = extract(@\"TokensUsed: (\\d+)\", 1, Log_s)\r\n| summarize \r\n    SummaryCount = count(),\r\n    AvgProcessingTime = avg(toint(ProcessingTime)),\r\n    TotalTokensUsed = sum(toint(TokensUsed))\r\n    by bin(TimeGenerated, 15m)\r\n| render timechart",
        "size": 0,
        "title": "AI Summary Generation Performance",
        "timeContext": {
          "durationMs": 0
        },
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "customWidth": "50",
      "name": "aiPerformance"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ContainerAppConsoleLogs_CL\r\n| where ContainerName_s == \"claim-status-api\"\r\n| where Log_s contains \"AI service error\"\r\n| extend ErrorType = extract(@\"ErrorType: ([A-Za-z]+)\", 1, Log_s)\r\n| summarize ErrorCount = count() by bin(TimeGenerated, 5m), ErrorType\r\n| render columnchart",
        "size": 0,
        "title": "AI Service Errors",
        "timeContext": {
          "durationMs": 0
        },
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "customWidth": "50",
      "name": "aiErrors"
    },
    {
      "type": 1,
      "content": {
        "json": "## API Management Analytics"
      },
      "name": "apimTitle"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ApiManagementGatewayLogs\r\n| where ApiId == \"claim-status-api\"\r\n| summarize \r\n    RequestCount = count(),\r\n    AvgResponseTime = avg(ResponseTime),\r\n    P95ResponseTime = percentile(ResponseTime, 95)\r\n    by bin(TimeGenerated, 5m), OperationName\r\n| render timechart",
        "size": 0,
        "title": "APIM Request Analytics by Operation",
        "timeContext": {
          "durationMs": 0
        },
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "customWidth": "50",
      "name": "apimAnalytics"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ApiManagementGatewayLogs\r\n| where ApiId == \"claim-status-api\"\r\n| where ResponseCode == 429\r\n| summarize RateLimitViolations = count() by bin(TimeGenerated, 5m)\r\n| render columnchart",
        "size": 0,
        "title": "Rate Limiting Violations",
        "timeContext": {
          "durationMs": 0
        },
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "customWidth": "50",
      "name": "rateLimiting"
    },
    {
      "type": 1,
      "content": {
        "json": "## Business Intelligence"
      },
      "name": "businessIntelTitle"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ContainerAppConsoleLogs_CL\r\n| where ContainerName_s == \"claim-status-api\"\r\n| where Log_s contains \"Claim accessed\"\r\n| extend ClaimId = extract(@\"ClaimId: (CLM\\d{3})\", 1, Log_s)\r\n| summarize AccessCount = count() by ClaimId\r\n| top 10 by AccessCount\r\n| render barchart",
        "size": 0,
        "title": "Most Accessed Claims",
        "timeContext": {
          "durationMs": 0
        },
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "customWidth": "50",
      "name": "topClaims"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ApiManagementGatewayLogs\r\n| where ApiId == \"claim-status-api\"\r\n| where TimeGenerated >= ago(24h)\r\n| summarize \r\n    RequestCount = count(),\r\n    ErrorRate = round(100.0 * countif(ResponseCode >= 400) / count(), 2)\r\n    by SubscriptionId\r\n| top 5 by RequestCount\r\n| project SubscriptionId, RequestCount, ErrorRate",
        "size": 0,
        "title": "Top API Consumers",
        "timeContext": {
          "durationMs": 0
        },
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "table"
      },
      "customWidth": "50",
      "name": "topConsumers"
    }
  ],
  "styleSettings": {},
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
```

## Manual Setup Instructions

1. **Create New Workbook:**
   - Navigate to Azure Monitor > Workbooks
   - Click "New" to create a blank workbook
   - Click "Advanced Editor" (</> icon)
   - Paste the JSON configuration above
   - Click "Apply"

2. **Configure Data Sources:**
   - Ensure Log Analytics workspace is properly connected
   - Verify Container Apps are sending logs to the workspace
   - Configure API Management to send logs to the same workspace

3. **Customize Time Ranges:**
   - Use the TimeRange parameter to adjust monitoring periods
   - Default is set to 1 hour, but can be adjusted from 5 minutes to 24 hours

4. **Alert Integration:**
   - Use the KQL queries from the workbook to create Azure Monitor alerts
   - Configure notification channels (email, SMS, webhooks)
   - Set appropriate thresholds based on your SLA requirements

## Key Metrics Monitored

### Performance Metrics
- Request volume and response times
- Error rates by status code
- P95 and P99 latency percentiles
- Container resource utilization (CPU, Memory)

### GenAI Specific Metrics
- AI summary generation performance
- Token usage and costs
- AI service error rates and types
- Processing time distribution

### Security & Compliance
- Authentication failures
- Rate limiting violations
- Unusual traffic patterns
- Top API consumers

### Business Intelligence
- Most accessed claims
- Summary usage patterns
- Peak usage times
- Subscriber behavior analysis
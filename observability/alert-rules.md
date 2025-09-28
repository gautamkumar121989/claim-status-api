# Alert Rules Configuration for Claim Status API

This document contains Azure Monitor alert rule configurations for comprehensive monitoring of the Claim Status API.

## 1. High Error Rate Alert

**Alert Name:** `ClaimAPI-HighErrorRate`

**Description:** Triggers when the API error rate exceeds 10% over a 5-minute period.

### KQL Query:
```kql
ContainerAppConsoleLogs_CL
| where ContainerName_s == "claim-status-api"
| where TimeGenerated >= ago(5m)
| where Log_s contains "Request completed"
| extend StatusCode = extract(@"Status: (\d+)", 1, Log_s)
| summarize 
    TotalRequests = count(),
    ErrorRequests = countif(toint(StatusCode) >= 400)
| extend ErrorRate = round(100.0 * ErrorRequests / TotalRequests, 2)
| where ErrorRate > 10
```

### Alert Configuration:
- **Severity:** 2 (Warning)
- **Frequency:** Every 5 minutes
- **Time Window:** 5 minutes
- **Threshold:** ErrorRate > 10
- **Action:** Send email to operations team

## 2. High Response Time Alert

**Alert Name:** `ClaimAPI-HighResponseTime`

**Description:** Triggers when the 95th percentile response time exceeds 5 seconds.

### KQL Query:
```kql
ContainerAppConsoleLogs_CL
| where ContainerName_s == "claim-status-api"
| where TimeGenerated >= ago(5m)
| where Log_s contains "Request completed"
| extend ResponseTime = extract(@"Duration: (\d+)ms", 1, Log_s)
| summarize P95ResponseTime = percentile(toint(ResponseTime), 95)
| where P95ResponseTime > 5000
```

### Alert Configuration:
- **Severity:** 2 (Warning)
- **Frequency:** Every 5 minutes
- **Time Window:** 5 minutes
- **Threshold:** P95ResponseTime > 5000
- **Action:** Send email to development team

## 3. Container Resource Exhaustion Alert

**Alert Name:** `ClaimAPI-ResourceExhaustion`

**Description:** Triggers when CPU or memory usage exceeds 80%.

### KQL Query:
```kql
InsightsMetrics
| where TimeGenerated >= ago(5m)
| where Name in ("cpuUsageNanoCores", "memoryWorkingSetBytes")
| where parse_json(Tags)["container.azm.ms/containername"] == "claim-status-api"
| extend ResourceType = case(
    Name == "cpuUsageNanoCores", "CPU",
    Name == "memoryWorkingSetBytes", "Memory",
    "Unknown"
)
| extend Value = case(
    ResourceType == "CPU", Val / 1000000000 * 100,
    ResourceType == "Memory", Val / 1024 / 1024 / 1024 * 100,
    Val
)
| summarize MaxValue = max(Value) by ResourceType
| where MaxValue > 80
```

### Alert Configuration:
- **Severity:** 1 (Error)
- **Frequency:** Every 1 minute
- **Time Window:** 5 minutes
- **Threshold:** MaxValue > 80
- **Action:** Auto-scale container and notify operations team

## 4. AI Service Failure Alert

**Alert Name:** `ClaimAPI-AIServiceFailure`

**Description:** Triggers when AI service errors exceed 5 in a 5-minute period.

### KQL Query:
```kql
ContainerAppConsoleLogs_CL
| where ContainerName_s == "claim-status-api"
| where TimeGenerated >= ago(5m)
| where Log_s contains "AI service error"
| summarize ErrorCount = count()
| where ErrorCount > 5
```

### Alert Configuration:
- **Severity:** 2 (Warning)
- **Frequency:** Every 5 minutes
- **Time Window:** 5 minutes
- **Threshold:** ErrorCount > 5
- **Action:** Send notification to AI/ML team

## 5. Rate Limiting Violations Alert

**Alert Name:** `ClaimAPI-RateLimitViolations`

**Description:** Triggers when rate limiting violations exceed 20 in a 5-minute period.

### KQL Query:
```kql
ApiManagementGatewayLogs
| where ApiId == "claim-status-api"
| where TimeGenerated >= ago(5m)
| where ResponseCode == 429
| summarize ViolationCount = count()
| where ViolationCount > 20
```

### Alert Configuration:
- **Severity:** 3 (Informational)
- **Frequency:** Every 5 minutes
- **Time Window:** 5 minutes
- **Threshold:** ViolationCount > 20
- **Action:** Log to security team dashboard

## 6. Container Restart Alert

**Alert Name:** `ClaimAPI-ContainerRestart`

**Description:** Triggers when container restarts occur.

### KQL Query:
```kql
ContainerInstanceLog_CL
| where ContainerName_s == "claim-status-api"
| where TimeGenerated >= ago(5m)
| where Message contains "Container started"
| summarize RestartCount = count()
| where RestartCount > 0
```

### Alert Configuration:
- **Severity:** 2 (Warning)
- **Frequency:** Every 1 minute
- **Time Window:** 5 minutes
- **Threshold:** RestartCount > 0
- **Action:** Notify operations team immediately

## 7. Suspicious Authentication Activity Alert

**Alert Name:** `ClaimAPI-SuspiciousAuth`

**Description:** Triggers when authentication failures from a single IP exceed 10 in 5 minutes.

### KQL Query:
```kql
ApiManagementGatewayLogs
| where ApiId == "claim-status-api"
| where TimeGenerated >= ago(5m)
| where ResponseCode in (401, 403)
| summarize FailureCount = count() by ClientIP
| where FailureCount > 10
```

### Alert Configuration:
- **Severity:** 1 (Error)
- **Frequency:** Every 1 minute
- **Time Window:** 5 minutes
- **Threshold:** FailureCount > 10
- **Action:** Block IP and notify security team

## 8. Low API Usage Alert

**Alert Name:** `ClaimAPI-LowUsage`

**Description:** Triggers when API requests fall below expected baseline (potential outage).

### KQL Query:
```kql
ApiManagementGatewayLogs
| where ApiId == "claim-status-api"
| where TimeGenerated >= ago(15m)
| summarize RequestCount = count()
| where RequestCount < 5
```

### Alert Configuration:
- **Severity:** 2 (Warning)
- **Frequency:** Every 15 minutes
- **Time Window:** 15 minutes
- **Threshold:** RequestCount < 5
- **Action:** Check service health

## Alert Actions Configuration

### Email Action Group
```json
{
  "name": "ClaimAPI-EmailGroup",
  "actions": [
    {
      "actionType": "Email",
      "emailReceiver": {
        "name": "Operations Team",
        "emailAddress": "ops-team@company.com"
      }
    },
    {
      "actionType": "Email",
      "emailReceiver": {
        "name": "Development Team",
        "emailAddress": "dev-team@company.com"
      }
    }
  ]
}
```

### SMS Action Group
```json
{
  "name": "ClaimAPI-SMSGroup",
  "actions": [
    {
      "actionType": "SMS",
      "smsReceiver": {
        "name": "On-call Engineer",
        "countryCode": "1",
        "phoneNumber": "5551234567"
      }
    }
  ]
}
```

### Webhook Action Group
```json
{
  "name": "ClaimAPI-WebhookGroup",
  "actions": [
    {
      "actionType": "Webhook",
      "webhookReceiver": {
        "name": "Teams Integration",
        "serviceUri": "https://company.webhook.office.com/webhookb2/...",
        "useCommonAlertSchema": true
      }
    }
  ]
}
```

## Deployment via Azure CLI

### Create Alert Rules
```bash
# High Error Rate Alert
az monitor scheduled-query create \
  --name "ClaimAPI-HighErrorRate" \
  --resource-group $RESOURCE_GROUP \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME" \
  --condition "count 'Heartbeat | summarize AggregatedValue = count() by bin(TimeGenerated, 5m) | where AggregatedValue > 10'" \
  --condition-query "ContainerAppConsoleLogs_CL | where ContainerName_s == 'claim-status-api' | where TimeGenerated >= ago(5m) | where Log_s contains 'Request completed' | extend StatusCode = extract(@'Status: (\d+)', 1, Log_s) | summarize TotalRequests = count(), ErrorRequests = countif(toint(StatusCode) >= 400) | extend ErrorRate = round(100.0 * ErrorRequests / TotalRequests, 2) | where ErrorRate > 10" \
  --condition-threshold 1 \
  --condition-operator "GreaterThan" \
  --action-groups "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/microsoft.insights/actionGroups/ClaimAPI-EmailGroup" \
  --evaluation-frequency "PT5M" \
  --window-size "PT5M" \
  --severity 2

# High Response Time Alert
az monitor scheduled-query create \
  --name "ClaimAPI-HighResponseTime" \
  --resource-group $RESOURCE_GROUP \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME" \
  --condition-query "ContainerAppConsoleLogs_CL | where ContainerName_s == 'claim-status-api' | where TimeGenerated >= ago(5m) | where Log_s contains 'Request completed' | extend ResponseTime = extract(@'Duration: (\d+)ms', 1, Log_s) | summarize P95ResponseTime = percentile(toint(ResponseTime), 95) | where P95ResponseTime > 5000" \
  --condition-threshold 1 \
  --condition-operator "GreaterThan" \
  --action-groups "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/microsoft.insights/actionGroups/ClaimAPI-EmailGroup" \
  --evaluation-frequency "PT5M" \
  --window-size "PT5M" \
  --severity 2
```

## Alert Testing

### Test Commands
```bash
# Generate test errors to trigger alerts
curl -X GET "https://$APIM_GATEWAY_URL/claims/INVALID-ID" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY"

# Generate load to test performance alerts
for i in {1..100}; do
  curl -s -o /dev/null -X GET "https://$APIM_GATEWAY_URL/claims/CLM001" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" &
done
wait
```

### Verification
1. Check alert status in Azure Monitor
2. Verify notifications are received
3. Confirm alert resolution when conditions return to normal
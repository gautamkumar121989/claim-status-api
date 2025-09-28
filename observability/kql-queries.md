# KQL Queries for Claim Status API Monitoring

## 1. Application Performance Monitoring

### API Request Volume and Response Times
```kql
ContainerAppConsoleLogs_CL
| where ContainerName_s == "claim-status-api"
| where Log_s contains "Request completed"
| extend RequestId = extract(@"RequestId: ([a-zA-Z0-9-]+)", 1, Log_s)
| extend StatusCode = extract(@"Status: (\d+)", 1, Log_s)
| extend ResponseTime = extract(@"Duration: (\d+)ms", 1, Log_s)
| summarize 
    RequestCount = count(),
    AvgResponseTime = avg(toint(ResponseTime)),
    P95ResponseTime = percentile(toint(ResponseTime), 95),
    P99ResponseTime = percentile(toint(ResponseTime), 99)
    by bin(TimeGenerated, 5m), StatusCode
| render timechart
```

### Error Rate Analysis
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

## 2. Container Health and Resource Monitoring

### Container Restart Events
```kql
ContainerInstanceLog_CL
| where ContainerName_s == "claim-status-api"
| where Message contains "Container started" or Message contains "Container stopped"
| summarize ContainerEvents = count() by bin(TimeGenerated, 1h), Message
| render columnchart
```

### Resource Utilization
```kql
InsightsMetrics
| where Name in ("cpuUsageNanoCores", "memoryWorkingSetBytes")
| where parse_json(Tags)["container.azm.ms/containername"] == "claim-status-api"
| extend ResourceType = case(
    Name == "cpuUsageNanoCores", "CPU",
    Name == "memoryWorkingSetBytes", "Memory",
    "Unknown"
)
| extend Value = case(
    ResourceType == "CPU", Val / 1000000000 * 100, // Convert to percentage
    ResourceType == "Memory", Val / 1024 / 1024, // Convert to MB
    Val
)
| summarize 
    AvgValue = avg(Value),
    MaxValue = max(Value),
    MinValue = min(Value)
    by bin(TimeGenerated, 5m), ResourceType
| render timechart
```

## 3. API Management Analytics

### APIM Request Analytics
```kql
ApiManagementGatewayLogs
| where ApiId == "claim-status-api"
| summarize 
    RequestCount = count(),
    AvgResponseTime = avg(ResponseTime),
    P95ResponseTime = percentile(ResponseTime, 95)
    by bin(TimeGenerated, 5m), OperationName
| render timechart
```

### Rate Limiting Violations
```kql
ApiManagementGatewayLogs
| where ApiId == "claim-status-api"
| where ResponseCode == 429
| summarize RateLimitViolations = count() by bin(TimeGenerated, 5m), SubscriptionId
| render columnchart
```

### Most Active Subscribers
```kql
ApiManagementGatewayLogs
| where ApiId == "claim-status-api"
| where TimeGenerated >= ago(24h)
| summarize 
    RequestCount = count(),
    UniqueOperations = dcount(OperationName),
    ErrorRate = round(100.0 * countif(ResponseCode >= 400) / count(), 2)
    by SubscriptionId
| top 10 by RequestCount
```

## 4. GenAI Operations Monitoring

### AI Summary Generation Performance
```kql
ContainerAppConsoleLogs_CL
| where ContainerName_s == "claim-status-api"
| where Log_s contains "AI summary generated"
| extend 
    ClaimId = extract(@"ClaimId: (CLM\d{3})", 1, Log_s),
    ProcessingTime = extract(@"ProcessingTime: (\d+)ms", 1, Log_s),
    TokensUsed = extract(@"TokensUsed: (\d+)", 1, Log_s)
| summarize 
    SummaryCount = count(),
    AvgProcessingTime = avg(toint(ProcessingTime)),
    P95ProcessingTime = percentile(toint(ProcessingTime), 95),
    TotalTokensUsed = sum(toint(TokensUsed))
    by bin(TimeGenerated, 15m)
| render timechart
```

### AI Service Errors
```kql
ContainerAppConsoleLogs_CL
| where ContainerName_s == "claim-status-api"
| where Log_s contains "AI service error"
| extend 
    ErrorType = extract(@"ErrorType: ([A-Za-z]+)", 1, Log_s),
    ClaimId = extract(@"ClaimId: (CLM\d{3})", 1, Log_s)
| summarize ErrorCount = count() by bin(TimeGenerated, 5m), ErrorType
| render columnchart
```

## 5. Security and Compliance Monitoring

### Authentication Failures
```kql
ApiManagementGatewayLogs
| where ApiId == "claim-status-api"
| where ResponseCode == 401 or ResponseCode == 403
| summarize AuthFailures = count() by bin(TimeGenerated, 5m), ClientIP, ResponseCode
| where AuthFailures > 5  // Potential brute force attempts
| render table
```

### Unusual Traffic Patterns
```kql
ApiManagementGatewayLogs
| where ApiId == "claim-status-api"
| summarize RequestCount = count() by bin(TimeGenerated, 1m), ClientIP
| where RequestCount > 100  // Adjust threshold as needed
| render table
```

## 6. Business Intelligence Queries

### Most Requested Claims
```kql
ContainerAppConsoleLogs_CL
| where ContainerName_s == "claim-status-api"
| where Log_s contains "Claim accessed"
| extend ClaimId = extract(@"ClaimId: (CLM\d{3})", 1, Log_s)
| summarize AccessCount = count() by ClaimId
| top 10 by AccessCount
```

### AI Summary Usage by Claim Type
```kql
ContainerAppConsoleLogs_CL
| where ContainerName_s == "claim-status-api"
| where Log_s contains "AI summary generated"
| extend 
    ClaimId = extract(@"ClaimId: (CLM\d{3})", 1, Log_s),
    ClaimType = extract(@"ClaimType: ([A-Za-z]+)", 1, Log_s)
| summarize SummaryCount = count() by ClaimType, bin(TimeGenerated, 1d)
| render columnchart
```

## 7. Alert Queries

### High Error Rate Alert
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
| where ErrorRate > 10  // Alert if error rate exceeds 10%
```

### High Response Time Alert
```kql
ContainerAppConsoleLogs_CL
| where ContainerName_s == "claim-status-api"
| where TimeGenerated >= ago(5m)
| where Log_s contains "Request completed"
| extend ResponseTime = extract(@"Duration: (\d+)ms", 1, Log_s)
| summarize P95ResponseTime = percentile(toint(ResponseTime), 95)
| where P95ResponseTime > 5000  // Alert if 95th percentile exceeds 5 seconds
```

### Container Resource Exhaustion Alert
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
    ResourceType == "Memory", Val / 1024 / 1024 / 1024 * 100, // Convert to percentage of 1GB
    Val
)
| summarize MaxValue = max(Value) by ResourceType
| where MaxValue > 80  // Alert if resource usage exceeds 80%
```

> Note: Logs now include RequestId, ClaimType, and standardized AI error pattern:
> "AI service error - RequestId: <id>; ClaimId: CLM001; ErrorType: <Type>; Message: <text>"
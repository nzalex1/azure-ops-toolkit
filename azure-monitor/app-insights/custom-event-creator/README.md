# PowerShell Application Insights Logger

Send telemetry from PowerShell automation to Azure Application Insights using a lightweight logger class and direct HTTPS requests.

`pwsh-appIns.ps1` defines `AppInsightsLogger`, which builds Application Insights telemetry envelopes and posts them to the resource's `v2/track` ingestion endpoint. It is intended for operational scripts, scheduled tasks, database checks, and automation that need centralised visibility without installing an Application Insights SDK or Azure PowerShell modules.

> **Current status:** This script is a prototype. The supplied example sends exception telemetry. Custom-event support is present, but requires the corrections below before it preserves event names and custom properties correctly.

## Requirements

- PowerShell with class support (PowerShell 5.0 or later; PowerShell 7+ recommended).
- An existing Azure Application Insights resource.
- A connection string containing both `InstrumentationKey` and `IngestionEndpoint`.
- Outbound HTTPS access to the ingestion endpoint.
- Local ingestion authentication enabled on the resource. This implementation does not obtain Microsoft Entra tokens or send an authorization header.

No `Connect-AzAccount`, Azure CLI login, external PowerShell module, or SDK is used by the script.

## How it works

1. The constructor parses the connection string.
2. The caller sets the telemetry type, message, severity, and other fields.
3. `Exception()` selects a telemetry envelope based on `type` and adds the current UTC timestamp.
4. The envelope is serialised to JSON and submitted using `Invoke-RestMethod`.
5. The script prints a success or failure message, then clears the logger's `message` field.

Despite its name, `Exception()` is the sending method for every telemetry type.

## Prepare the script

Before importing the class into another script:

1. Remove the demonstration block at the bottom, beginning with `$appInsLogger = [AppInsightsLogger]::new(...)`. Otherwise, loading the file immediately attempts to send the embedded sample exception to its configured resource.
2. Replace resource-specific configuration with your own connection string. Keep deployment configuration outside the repository.
3. Apply the event and property corrections below if you want to send custom events.

The comment-based help at the top currently describes a parameterised command-line interface, but the implementation has no `param()` block. Use the class interface shown here; commands such as `./pwsh-appIns.ps1 -TelemetryType Event` are not implemented.

### Correct event names and custom properties

Inside `Exception()`, retain this existing line:

```powershell
$props = if ($this.properties) { [hashtable]$this.Properties } else { @{} }
```

Remove the subsequent hard-coded `$props = @{ ... }` assignment. It currently overwrites all caller-provided properties with the sample `Description` and `Script` values.

In the `event` branch, replace:

```powershell
name = ($this.name -or "PowerShell.Event")
```

with:

```powershell
name = if ([string]::IsNullOrWhiteSpace($this.name)) {
    'PowerShell.Event'
} else {
    $this.name
}
```

PowerShell's `-or` operator returns a Boolean; it does not provide a fallback string. Always assign the intended event name, because the class's default `name` is `Microsoft.ApplicationInsights.Exception`.

## Quick start: send a custom event

After completing the preparation above, load the class and send an event:

```powershell
# Set this in your session or supply it through your automation environment.
$env:APPLICATIONINSIGHTS_CONNECTION_STRING = 'InstrumentationKey=<your-key>;IngestionEndpoint=https://<your-ingestion-host>/;'

# Load the class from a file containing only its definition.
. ./pwsh-appIns.ps1

$logger = [AppInsightsLogger]::new(
    $env:APPLICATIONINSIGHTS_CONNECTION_STRING
)

$logger.type = 'event'
$logger.name = 'DeploymentCompleted'
$logger.properties = @{
    Environment = 'Development'
    Application = 'ExampleApp'
    Version     = '1.2.3'
    Result      = 'Succeeded'
}

$logger.Exception()
```

The endpoint must end with `/`, because the script appends `v2/track` directly. The environment variable is read by the example; the class does not automatically discover it.

Custom events contain a name and custom properties. The current event branch does not include the `message` field; put event details in `properties`.

### Send an exception

```powershell
$logger.type = 'exception'
$logger.severity = '3'
$logger.properties = @{
    Operation = 'DatabaseConsistencyCheck'
    Database  = 'ExampleDatabase'
}

try {
    throw 'Database consistency check failed.'
} catch {
    $logger.message = $_.Exception.Message
    $logger.stackTrace = $_.ScriptStackTrace
    $logger.Exception()
}
```

This example assumes the class has already been loaded and `$logger` created. Custom exception properties require removal of the hard-coded property assignment described above. Exception `typeName` and `method` are also hard-coded in the supplied script; adjust them to describe your automation.

## Class reference

### Configuration and telemetry fields

| Field | Purpose |
| --- | --- |
| `ConnectionString` | Constructor input; parsed when the logger is created. |
| `InstrumentationKey` | Resource identifier extracted from the connection string. |
| `IngestionEndpoint` | Endpoint extracted from the connection string; requires a trailing `/`. |
| `type` | Selects `exception`, `trace`, `event`, `metric`, or `availability`. Set before sending. |
| `name` | Event, metric, or availability name. Default: `Microsoft.ApplicationInsights.Exception`. |
| `message` | Exception or trace text; also referenced by availability telemetry. |
| `stackTrace` | Exception stack text. |
| `properties` | Hashtable of custom dimensions; currently overwritten unless corrected. |
| `severity` | Severity stored as a string; default is `'1'`. Use the numeric values below. |

Changing `ConnectionString` after construction does not reparse the key or endpoint. Create a new logger for a different resource.

| Severity | Value |
| --- | --- |
| Verbose | `0` |
| Information | `1` |
| Warning | `2` |
| Error | `3` |
| Critical | `4` |

The class has no mapping from severity names to numbers.

### Methods

| Method | Behaviour |
| --- | --- |
| `AppInsightsLogger(connectionString)` | Creates the logger and parses the supplied settings. |
| `Exception()` | Builds and submits the selected telemetry type. |
| `Clear()` | Clears `message` only. Other fields remain set. |
| `Display()` | Prints connection details, including the instrumentation key. |

`Push()` is an internal, hidden method used to submit the JSON payload.

## Find custom events in Azure

Open **Logs** for your Application Insights resource and run:

```kusto
customEvents
| where timestamp > ago(1h)
| where name == "DeploymentCompleted"
| project timestamp, name, customDimensions
| order by timestamp desc
```

When querying the associated Log Analytics workspace, use the workspace table and column names:

```kusto
AppEvents
| where TimeGenerated > ago(1h)
| where Name == "DeploymentCompleted"
| project TimeGenerated, Name, Properties
| order by TimeGenerated desc
```

## Current limitations

- **Trace and availability text:** `($this.Message -or "")` produces a Boolean. Replace it with an explicit string fallback before relying on those branches.
- **Metrics:** The metric branch references `$this.Value`, but the class does not declare a `Value` property. Add a numeric property and correct the metric-name fallback before using metrics.
- **Availability:** Duration, success, and run location are fixed sample values. They do not measure an actual check.
- **Unknown types:** Fall back to trace telemetry. An unset `type` fails when `.ToLower()` is called.
- **Delivery handling:** Requests are synchronous. There is no batching, retry policy, local queue, or durable delivery guarantee.
- **Response handling:** The ingestion response is not checked for per-item acceptance or partial failures. The printed `Telemetry sent` message alone does not confirm the item was accepted.
- **Error handling:** Submission exceptions are printed and swallowed. Callers do not receive a structured result or a rethrown submission error.
- **State reuse:** Only `message` is cleared after a send attempt. Set fields explicitly when reusing a logger to avoid carrying values into subsequent telemetry.
- **Timestamp:** Uses the current UTC time; caller-supplied timestamps are not implemented.
- **Authentication:** No API-key parameter or Microsoft Entra authentication is implemented, despite the header comments.
- **Other telemetry types:** Request, dependency, and page-view telemetry are mentioned in the header but have no implementation branches.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Loading the script sends an unexpected exception | Remove the executable demonstration block before dot-sourcing. |
| Event name is `true` rather than the supplied name | Replace the `-or` expression in the event-name field. |
| Custom dimensions contain only sample values | Remove the hard-coded `$props` reassignment. |
| Invalid ingestion URL | Include `IngestionEndpoint` and retain its trailing `/`. |
| Request rejected by ingestion | Review the response, resource configuration, and whether local authentication is disabled. |
| Console says sent, but no event appears | Check the ingestion response for rejected items, then confirm the resource, query scope, time range, and event name. |
| Metric assignment fails | Declare the missing `Value` class property before using metric telemetry. |

## Operational notes

`Push()` prints the complete JSON payload, and `Display()` prints connection details. Review what is captured by console logs before using either with operational data. Avoid including credentials, tokens, or personal information in telemetry properties.

A connection string identifies the telemetry destination; this script does not implement identity-based authentication. Resources configured to require Microsoft Entra authentication need a token-enabled implementation.

## References

- [Application Insights connection strings](https://learn.microsoft.com/en-us/azure/azure-monitor/app/connection-strings)
- [Microsoft Entra authentication for Application Insights](https://learn.microsoft.com/en-us/azure/azure-monitor/app/azure-ad-authentication)
- [Application Insights telemetry data model](https://learn.microsoft.com/en-us/azure/azure-monitor/app/data-model-complete)
- [AppEvents table reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/appevents)


<#
.SYNOPSIS
Send telemetry (trace/event/metric) to Azure Application Insights from PowerShell.

.DESCRIPTION
Utility script to post lightweight telemetry to an Application Insights resource. Supports sending traces, events and metrics with optional custom properties, severity and timestamp. Can use a ConnectionString (preferred) or an InstrumentationKey with an API key/endpoint.

.PARAMETER ConnectionString
Application Insights connection string. Preferred authentication method when available.

.PARAMETER InstrumentationKey
Instrumentation Key (ikey) for the Application Insights resource. Used if ConnectionString is not provided.

.PARAMETER ApiKey
Optional ingestion API key with Data Write permission. Required when posting using ikey against some ingestion endpoints.

.PARAMETER TelemetryType
Type of telemetry to send. Valid values: Exception, Trace, Event, Metric.

.PARAMETER Name
Name of the event or metric, or identifier for the telemetry item. The options are below:
Microsoft.ApplicationInsights.Exception : Exception telemetry (errors, stack traces).
Microsoft.ApplicationInsights.Message : Trace or log messages (with severity levels).
Microsoft.ApplicationInsights.Event : Custom events (e.g., “UserLoggedIn”, “DeploymentStarted”).
Microsoft.ApplicationInsights.Metric : Numeric measurements (e.g., CPU usage, latency).
Microsoft.ApplicationInsights.Request : Incoming request telemetry (HTTP or custom operations).
Microsoft.ApplicationInsights.Dependency : Outbound calls (HTTP, SQL, external services).
Microsoft.ApplicationInsights.PageView : Page view telemetry (web apps).
Microsoft.ApplicationInsights.Availability : Availability test results (ping or synthetic tests).

.PARAMETER Message
Message text for Trace or Event telemetry.

.PARAMETER Value
Numeric value for Metric telemetry.

.PARAMETER Severity
Severity level for Trace telemetry. Typical values: Verbose, Information, Warning, Error, Critical.

.PARAMETER Properties
Hashtable of custom properties (key/value) to attach to the telemetry item.

.PARAMETER Timestamp
Optional DateTime to associate with the telemetry item (defaults to now).

.PARAMETER Endpoint
Optional ingestion endpoint URL. When omitted the endpoint is derived from the ConnectionString or ikey.

.EXAMPLE
# Send a trace with properties
.\pwsh-appIns.ps1 -ConnectionString '<ConnStr>' -TelemetryType Trace -Message 'Job completed' -Severity Information -Properties @{JobId='1234'; Host='web01'}

.EXAMPLE
# Send a metric using ikey + api key
.\pwsh-appIns.ps1 -InstrumentationKey '<ikey>' -ApiKey '<apiKey>' -TelemetryType Metric -Name 'QueueLength' -Value 42

.NOTES
- Requires outbound HTTPS access to Application Insights ingestion endpoint.
- Payloads are sent as JSON via POST; ensure sensitive data is handled appropriately.
- Intended for automation and lightweight telemetry from PowerShell scripts and tasks.
#>
class AppInsightsLogger {
    # Properties (Data)
    [string]$ConnectionString
	[string]$InstrumentationKey
	[string]$IngestionEndpoint
    [string]$name = "Microsoft.ApplicationInsights.Exception" # Error, Trace, Request
	[string]$type
	[string]$message
	[string]$stackTrace
	[hashtable]$properties
	[string]$severity = 1 # $sevMap = @{ "verbose"=0; "information"=1; "info"=1; "warning"=2; "error"=3; "critical"=4 }
	hidden [string]$payload

    AppInsightsLogger([string]$ConnectionString) {
        $this.ConnectionString = $ConnectionString
		$settings = $ConnectionString -replace ';', "`n" | ConvertFrom-StringData
		$this.InstrumentationKey = $settings.InstrumentationKey
		$this.IngestionEndpoint = $settings.IngestionEndpoint
    }

    [void]Display() {
        Write-Host "Conn string: $($this.ConnectionString)"
		Write-Host "type: $($this.type)"
		Write-Host $this.IngestionEndpoint
		Write-Host $this.InstrumentationKey
    }
	
    [void]Clear() {
		$this.Message = $null
    }
	
	hidden [void]Push() {
		Write-Host $this.payload

		$uri = $this.IngestionEndpoint + "v2/track"
		try {
			Invoke-RestMethod -Method Post -Uri $uri -Body $this.payload -ContentType "application/x-json-stream" -ErrorAction Stop
			Write-Host "Telemetry sent"
		}
		catch {
			Write-Host "Failed to send telemetry to $uri. $($_.Exception.Message)"
		}
		$this.Clear()
	}

	[void]Exception() {
		$timeUtc = (Get-Date).ToUniversalTime().ToString("o")

		# normalize properties and severity
		$props = if ($this.properties) { [hashtable]$this.Properties } else { @{} }
		
		$props = @{
			Description  = "Error of failed BB check"
			Script       = "Number one"
		}

		$entry = $null
		switch ($this.type.ToLower()) {
			"exception" {
				$entry = @{
					name = "Microsoft.ApplicationInsights.Exception"
					time = $timeUtc
					iKey = $this.InstrumentationKey
					data = @{
						baseType = "ExceptionData"
						baseData = @{
							ver = 2
							exceptions = @(@{
								typeName     = "MSF.DbCheck.script.Error" # $this.type
								method 	 	 = "PowerShell.SQL.Query" 
								message      = $this.message 
								stack        = $this.stackTrace
								hasFullStack = $false
							})
							severityLevel = $this.severity
							properties    = $props
						}
					}
				}
			}
			"trace" {
				$entry = @{
					name = "Microsoft.ApplicationInsights.Message"
					time = $timeUtc
					iKey = $this.InstrumentationKey
					data = @{
						baseType = "MessageData"
						baseData = @{
							ver = 2
							message = ($this.Message -or "")
							severityLevel = $this.severity
							properties = $props
						}
					}
				}
			}
			"event" {
				$entry = @{
					name = "Microsoft.ApplicationInsights.Event"
					time = $timeUtc
					iKey = $this.InstrumentationKey
					data = @{
						baseType = "EventData"
						baseData = @{
							ver = 2
							name = ($this.name -or "PowerShell.Event")
							properties = $props
						}
					}
				}
			}
			"metric" {
				$metricValue = if ($null -ne $this.Value) { [double]$this.Value } else { 0.0 }
				$entry = @{
					name = "Microsoft.ApplicationInsights.Metric"
					time = $timeUtc
					iKey = $this.InstrumentationKey
					data = @{
						baseType = "MetricData"
						baseData = @{
							ver = 2
							metrics = @(@{
								name  = ($this.name -or "metric")
								value = $metricValue
							})
							properties = $props
						}
					}
				}
			}
			"availability" {
				$availId = [guid]::NewGuid().ToString()
				$duration = "00:00:00.0000000"
				$success = $true
				$runLocation = "PowerShell"

				$entry = @{
					name = "Microsoft.ApplicationInsights.Availability"
					time = $timeUtc
					iKey = $this.InstrumentationKey
					data = @{
						baseType = "AvailabilityData"
						baseData = @{
							ver = 2
							id = $availId
							name = ($this.name -or "PowerShell.Availability")
							duration = $duration
							success = $success
							runLocation = $runLocation
							message = ($this.Message -or "")
							properties = $props
						}
					}
				}
			}
			default {
				# fallback to Message/Trace
				$entry = @{
					name = "Microsoft.ApplicationInsights.Message"
					time = $timeUtc
					iKey = $this.InstrumentationKey
					data = @{
						baseType = "MessageData"
						baseData = @{
							ver = 2
							message = ($this.Message -or "")
							severityLevel = $this.severity
							properties = $props
						}
					}
				}
			}	
		}
		$this.payload = @($entry) | ConvertTo-Json -Depth 6
		$this.Push()
	}
}


$appInsLogger = [AppInsightsLogger]::new("InstrumentationKey=b7e26be2-a2fa-4e77-b14e-43cedaba8168;IngestionEndpoint=https://australiaeast-1.in.applicationinsights.azure.com/;LiveEndpoint=https://australiaeast.livediagnostics.monitor.azure.com/;ApplicationId=7b82739a-a019-47cb-b479-d34133711219")

$appInsLogger.type = "exception"
$appInsLogger.message = "DB check script error"
$appInsLogger.stackTrace = "msf.check.1"
$appInsLogger.severity = "3" 
$extraProperties = @{
    Name       = "DB Check error"
    Role       = "MSF Database Consistency Check"
}
$appInsLogger.Exception()








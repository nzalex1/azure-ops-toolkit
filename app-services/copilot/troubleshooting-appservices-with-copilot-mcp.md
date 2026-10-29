# Troubleshooting Azure App Services and Function Apps with GitHub Copilot and Azure MCP

Use GitHub Copilot in Visual Studio Code to investigate Azure application issues through resource information, Application Insights, and Log Analytics.

## Prerequisites

- A GitHub account with access to GitHub Copilot.
- Visual Studio Code signed in to that GitHub account.
- Azure CLI and access to the subscription containing the application.
- Application telemetry available in Application Insights or Log Analytics.

## 1. Prepare VS Code and Azure access

Install or enable GitHub Copilot and its chat capabilities, plus the Azure tooling required by your environment.

Sign in to Azure and verify the active subscription:

```bash
az login
az account show
```

If necessary, select the subscription explicitly:

```bash
az account set --subscription "<subscription-id>"
```

## 2. Open Copilot Chat

Open the VS Code Command Palette with **Ctrl+Shift+P**, then open **GitHub Copilot: Open Chat** or the available Chat command in your installed version.

Confirm that you are signed in with the intended GitHub account. Once Azure tools are connected, try:

```text
What Azure subscription am I logged into?
```

Copilot needs access to an Azure tool or terminal command to answer from your actual environment; chat alone does not provide subscription access.

## 3. Configure Azure MCP

Open the Command Palette and select **MCP: Add Server**, or configure an MCP server in your VS Code environment.

The source configuration uses this illustrative JSON structure:

```json
{
  "servers": {
    "azure": {
      "command": "npx",
      "args": [
        "-y",
        "@azure/mcp"
      ]
    }
  }
}
```

Use the package version, launch arguments, and installation method supported by your Azure MCP release and environment. The example requires Node.js and `npx`; it is not a version-pinned installation.

Enable the MCP server and its tools in Copilot's tool-capable chat mode. Review requested tool approvals when prompted.

## 4. Verify the connection

Ask Copilot:

```text
List my Azure subscriptions.
```

Then use a subscription returned by the tool:

```text
List Function Apps in subscription <subscription-name-or-id>.
```

Confirm that the returned subscription and resources match the environment you intend to investigate.

## 5. Confirm monitoring permissions

The signed-in Azure identity needs permissions to inspect the application and query its telemetry.

| Scope | Typical access to review |
| --- | --- |
| Web App or Function App and its resource group | Reader |
| Application Insights and the associated Log Analytics workspace | Monitoring Reader or appropriate log-query permissions |

Apply access at the required resource or resource-group scope. Actual query access depends on workspace access settings and any more restrictive permissions in your environment.

## 6. Investigation prompts

Replace the placeholders with your resource names. Tool availability and telemetry coverage determine which checks Copilot can perform.

### Application fails to initialise

```text
Find Function App <function-app-name> in subscription <subscription-id>.
Review Application Insights exceptions from the last 4 hours.
Identify initialisation failures, configuration errors, authentication errors,
and dependency failures.
Summarise the most likely root cause and the evidence supporting it.
```

### Recent exceptions

```text
For Function App <function-app-name>:
Show the latest 20 exceptions.
Group similar exceptions.
Explain the likely root cause for each group.
Show the KQL query and the telemetry evidence used.
```

An Application Insights query for recent exceptions is:

```kusto
exceptions
| where timestamp > ago(4h)
| order by timestamp desc
| take 20
```

### Missing configuration

```text
Review initialisation exceptions for <app-name>.
Check for missing environment variables, unresolved Key Vault references,
missing connection strings, and configuration binding failures.
Report setting names and errors without displaying secret values.
```

An example finding might be:

```text
KeyNotFoundException
Configuration value API_URL was not present.
```

### Managed identity failures

```text
Check whether <function-app-name> has recent managed identity failures.
Search for these terms:
403
Forbidden
ManagedIdentity
Azure.Identity
CredentialUnavailableException

Correlate errors with the affected dependency and identify whether the issue
is identity configuration, permissions, or connectivity.
```

One possible finding is that the application's managed identity lacks access to a Key Vault secret. Confirm that conclusion against the actual error and resource configuration.

### Storage failures

```text
Review the last 24 hours of telemetry for <function-app-name>.
Look for storage-related issues involving:
AzureWebJobsStorage
Blob
Queue
Connection String
StorageException

Identify the affected storage dependency and supporting errors.
```

### A function is not being triggered

```text
Review Function App <function-app-name> telemetry for the last 24 hours.
Compare successful and failed executions.
Investigate why function <function-name> is not being triggered.
Check for disabled functions, trigger listener failures, unavailable storage,
missing messaging permissions, and expired credentials.
Separate confirmed findings from hypotheses or missing evidence.
```

### Combined investigation

```text
Act as an Azure Functions SRE.

Investigate Function App <function-app-name> in subscription <subscription-id>.
Use Application Insights and available Azure resource information.

Check:
- Latest exceptions
- Initialisation issues
- Missing configuration
- Key Vault failures
- Managed identity failures
- Storage failures
- Dependency failures

Provide:
- Most likely root cause
- Evidence and query time range
- Recommended fix
- Confidence level
- Any missing information needed to confirm the diagnosis

Investigate only; do not modify Azure resources.
```

## Alternative: use Azure CLI without MCP

You can use Copilot to help construct commands and interpret results even without an MCP connection.

Ask:

```text
Generate an Azure CLI command to query exceptions from Application Insights
for Function App <function-app-name> during the last 4 hours.
Explain the required identifiers and permissions.
```

Review and run the generated command, then share the relevant output with Copilot after removing sensitive values:

```text
Analyse this query output.
Identify the most likely root cause, cite the supporting entries,
and suggest the next diagnostic check.
```

Validate proposed fixes against the evidence before applying changes. An absence of telemetry is not proof that an application or trigger is healthy.

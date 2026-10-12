# Check Azure App Service Slot Provisioning Status

A lightweight PowerShell polling script that waits for an Azure App Service deployment slot to report a provisioning state of `Succeeded`.

**Script:** [`test-app-service-slot-status.ps1`](test-app-service-slot-status.ps1)

Use this check as a waiting step in deployment automation when a subsequent operation depends on resource provisioning completing. The script only reads resource information; it does not deploy, restart, or swap a slot.

> Provisioning status describes Azure resource provisioning. It does not confirm that the application has started successfully or is serving healthy HTTP responses. Use a separate application health check for that purpose.

## How it works

The script uses a `do` / `while` loop to:

1. Wait 10 seconds, including before the first check.
2. Query Azure resources using `az resource list`.
3. Extract `provisioningState` using a JMESPath query and TSV output.
4. Print the returned status.
5. Exit with code `1` once the attempt counter reaches 20.
6. Otherwise, repeat until the status equals `Succeeded`.

The configured sleep budget is **200 seconds** across 20 attempts. Actual runtime is longer because Azure CLI execution time is additional.

## Requirements

- PowerShell (PowerShell 7 recommended).
- Azure CLI installed and available as `az`.
- An authenticated Azure CLI session or an authenticated pipeline task.
- The correct subscription selected.
- Permission to read the target resource, for example an appropriately scoped Reader role.
- An existing App Service or Function App deployment slot.

Azure PowerShell `Az` modules are not required.

## Configure the target

The supplied script contains **two status queries**:

```powershell
$status = az resource list --name '${{ parameters.appServiceName }}/${{ parameters.stagingSlot }}' --query '[].provisioningState' -o tsv
$status = az resource list --name 'func-rt-psd-msf-np-rtapoc/staging' --query '[].provisioningState' -o tsv
```

The second assignment overwrites the first. Consequently, the loop evaluates the result for the hard-coded `func-rt-psd-msf-np-rtapoc/staging` target, regardless of the first query's result.

Before reuse, retain only one query and configure it for your environment.

### Local execution

Replace the two query lines with a single query containing your app and slot names:

```powershell
$status = az resource list --name 'my-app/staging' --query '[].provisioningState' -o tsv
```

The `${{ parameters.* }}` expressions are Azure Pipelines template syntax, not PowerShell parameters. They are not expanded when you run the uploaded `.ps1` file locally.

Sign in, select the subscription, then run the configured script:

```powershell
az login
az account set --subscription '<subscription-id>'
pwsh -File ./test-app-service-slot-status.ps1
```

The current script does not accept command-line parameters for the app name, slot name, resource group, interval, or attempt limit.

### Azure Pipelines

The template-based query is intended for use in an inline YAML script where `appServiceName` and `stagingSlot` are declared template parameters. Remove the hard-coded query before using that version.

For a checked-in `.ps1` file, replace the template expressions with explicit configuration, or update the script to accept PowerShell parameters or environment variables. Referencing the file from YAML does not turn its contents into a YAML template.

An Azure CLI task can run a locally configured copy using its service connection:

```yaml
steps:
  - task: AzureCLI@2
    displayName: Wait for App Service slot provisioning
    inputs:
      azureSubscription: '<azure-service-connection>'
      scriptType: pscore
      scriptLocation: scriptPath
      scriptPath: 'test-app-service-slot-status.ps1'
```

This example assumes the script is in the repository root, the agent has PowerShell Core, and the target query has already been configured. Adjust `scriptPath` for your repository layout.

## Confirm the status query

Before relying on the polling loop, inspect what Azure CLI actually returns for the target:

```powershell
az resource list --name 'my-app/staging' -o json
```

The script assumes each result contains a top-level `provisioningState` field. Resource list results may not include the detailed provider properties needed for this check. An empty result or an absent field leaves the loop without a success value.

Use the full resource ID to inspect the slot directly when diagnosing this:

```powershell
$slotId = '/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Web/sites/<app-name>/slots/<slot-name>'
az resource show --ids $slotId -o json
```

Check the actual response and the resource's supported API before selecting a status field. If the response exposes it under `properties.provisioningState`, the corresponding query is:

```powershell
az resource show --ids $slotId --query 'properties.provisioningState' -o tsv
```

Do not assume that every slot response exposes that property. A slot's runtime `state` (such as `Running`) is a different signal and should not be substituted without changing the purpose of the check.

## Output and exit behaviour

Typical output when a query returns the expected field:

```text
Waiting 10 sec for Provisioning status update...
Provisioning Status: Updating
Waiting 10 sec for Provisioning status update...
Provisioning Status: Succeeded
```

| Result | Current behaviour |
| --- | --- |
| `Succeeded` on attempts 1–19 | Leaves the loop and reaches the end of the script. There is no explicit `exit 0`. |
| Any result on attempt 20 | Prints the timeout message and executes `exit 1`, including if the result is `Succeeded`. |
| Empty status or resource not found | Continues polling until the attempt limit. |
| Failed provisioning state | Continues polling; there is no early failure check. |
| Azure CLI command error | No explicit `$LASTEXITCODE` handling; the script does not reliably distinguish a query error from a pending state. |

## Configuration values

| Setting | Current value | Where to change it |
| --- | --- | --- |
| Polling interval | 10 seconds | `sleep 10` and the associated log message. |
| Maximum attempts | 20 | `($counter ++) -ge 20`. |
| Success condition | `Succeeded` | The `while` comparison. |
| Resource target | Hard-coded app and staging slot | The second `az resource list` command. |
| Subscription | Active Azure CLI subscription | Azure CLI login/context or the pipeline service connection. |

## Recommended refinements

For a reusable toolkit version:

- Keep one resource query and accept the resource ID or app, resource group, and slot as parameters.
- Confirm that the selected API response exposes the status being tested.
- Test for success before checking the attempt limit so success on the last attempt is accepted.
- Check `$LASTEXITCODE` immediately after each Azure CLI call.
- Handle missing resources and failed provisioning states explicitly.
- Return explicit success and failure exit codes for pipeline use.
- Make the polling interval and attempt limit configurable.

These are suggested improvements; this documentation does not modify the supplied script.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Status is blank on every attempt | Resource name, subscription, permissions, returned JSON, and the query's property path. |
| Pipeline parameters seem to have no effect | Remove the hard-coded query that overwrites the template-based result. |
| Local execution queries a literal `${{ ... }}` string | Replace YAML template expressions with local values or PowerShell inputs. |
| The final check says `Succeeded`, but the task fails | The timeout check executes before the loop's success condition on attempt 20. |
| Slot exists, but provisioning status never appears | Inspect the full resource response and verify whether the provider exposes this field. |
| Script completes, but the application is unhealthy | Add a separate HTTP readiness or application health check. |

## References

- [Azure CLI resource commands](https://learn.microsoft.com/en-us/cli/azure/resource)
- [Azure Pipelines template expressions](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/template-expressions)
- [Azure CLI task for Azure Pipelines](https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/azure-cli-v2)

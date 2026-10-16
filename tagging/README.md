# Azure VM Tagging Examples

These PowerShell examples apply tags to virtual machines in an Azure subscription. Each script requires a subscription name and uses `Get-AzVM` to enumerate **all VMs** in that subscription; there is no VM-name or resource-group filter.

## Scripts

| Script | Operation |
| --- | --- |
| `addTag-desiredPowerStateON.ps1` | Merges `DesiredPowerState=on` onto every VM. |
| `addTag-desiredPowerStateOFF.ps1` | Merges `DesiredPowerState=off` onto every VM. |
| `addTag-schedule.ps1` | Merges `ScheduleStop=0 18 * * *` onto every VM. |
| `addTag-scheduleIgnore.ps1` | Merges `ScheduleIgnore=1` onto every VM. |
| `removeTag-scheduleIgnore.ps1` | Deletes the `ScheduleIgnore` tag from every VM. |

The add scripts use `Update-AzTag` with the `Merge` operation, preserving other existing tags. The removal script uses the `Delete` operation.

## Requirements and usage

Use PowerShell with the `Az.Accounts`, `Az.Compute`, and `Az.Resources` modules installed. Sign in to Azure before running a script, and have permission to read VMs and update resource tags.

```powershell
Connect-AzAccount
.\addTag-desiredPowerStateON.ps1 -Subscription "Example subscription name"
```

Replace the example with the intended subscription name. Review the target subscription before running a script: each operation affects every VM returned by `Get-AzVM` after `Select-AzSubscription` changes the active Azure context.


# Manage Azure App Service Settings from JSON

[`appsvc-settings.ps1`](appsvc-settings.ps1) applies application settings to an Azure Web App or Function App from a JSON file. It supports production and deployment slots, generates Key Vault references, and previews changes before applying them.

By default, the script **only previews changes** and **preserves settings not listed in the file**.

## Prerequisites

Use PowerShell with the `Az.Accounts` and `Az.Websites` modules installed:

```powershell
Install-Module -Name Az.Accounts, Az.Websites -Scope CurrentUser
Connect-AzAccount
Set-AzContext -Subscription '<subscription-id>'
```

The app or slot must already exist. Your Azure identity needs permission to read its configuration and, when applying changes, update application settings.

## Settings file

Create `appsettings.json` with a top-level `settings` object. Use string values, including for numbers and Boolean settings:

```json
{
  "settings": {
    "APP_ENVIRONMENT": "Development",
    "FEATURE_ENABLED": "true",
    "API_TIMEOUT_SECONDS": "30",
    "DATABASE_PASSWORD": "keyvault",
    "RELEASE_DATE": "date_2026-10-14"
  }
}
```

| Value | Behaviour |
| --- | --- |
| Ordinary string | Applied as the setting value. |
| `keyvault` | Replaced with a reference to a secret in the supplied Key Vault. The marker comparison is case-insensitive. |
| String beginning with `date_` | The first five characters are removed; for example, `date_2026-10-14` becomes `2026-10-14`. No date parsing or validation occurs. |

For Key Vault references, the **setting name stays unchanged**, but underscores become hyphens in the **secret name**. For example, `DATABASE_PASSWORD` becomes:

```text
@Microsoft.KeyVault(SecretUri=https://kv-example.vault.azure.net/secrets/DATABASE-PASSWORD/)
```

The script only creates the reference string. It does not create or validate the vault, secret, permissions, or network access. Configure the app/slot's managed identity to read the secret, using the appropriate Key Vault access policy or RBAC role, and allow connectivity to the vault. See [Microsoft's Key Vault reference guide](https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references).

## Usage

Run these examples in PowerShell, from the directory containing the script. Set common arguments once:

```powershell
$settingsArgs = @{
    ResourceGroupName = 'rg-example'
    appsvcFullName    = 'app-example'
    keyvaultFullName  = 'kv-example'
    AppSettingsFile  = './appsettings.json'
}
```

### 1. Preview changes

```powershell
./appsvc-settings.ps1 @settingsArgs
```

Reads the current configuration and reports settings that match, need adding or updating, or exist only in Azure. No settings are written.

### 2. Apply changes and preserve other settings

```powershell
./appsvc-settings.ps1 @settingsArgs -whatIf $false
```

Adds or updates settings from the file while keeping other existing settings. A write is performed only when changes are detected.

### 3. Apply changes and remove unlisted settings

```powershell
./appsvc-settings.ps1 @settingsArgs -whatIf $false -delete $true
```

Also removes existing application settings absent from the JSON file. Include every required platform and application setting in the file before using this mode, especially for Function Apps.

### 4. Target a deployment slot

```powershell
# Preview staging settings.
./appsvc-settings.ps1 @settingsArgs -swapSlot $true -slot 'staging'

# Apply to staging while preserving unlisted settings.
./appsvc-settings.ps1 @settingsArgs -swapSlot $true -slot 'staging' -whatIf $false
```

Pass **both** `-swapSlot $true` and `-slot` when targeting a slot. Despite its name, `swapSlot` selects a deployment slot; the script does not perform a slot swap.

## Parameters

| Parameter | Required / default | Description |
| --- | --- | --- |
| `ResourceGroupName` | Required | Resource group containing the app. |
| `appsvcFullName` | Required | Web App or Function App name. |
| `keyvaultFullName` | Required | Vault name used for generated references; required even if the file contains no `keyvault` markers. |
| `AppSettingsFile` | Required | Path to the JSON file. Relative paths resolve from the current working directory. |
| `swapSlot` | Optional | Set to `$true` to read the named slot instead of production. |
| `slot` | Optional | Slot name; required when `swapSlot` is true. |
| `whatIf` | `$true` | Preview only. Set to `$false` to apply changes. |
| `delete` | `$false` | With `whatIf` false, removes settings absent from the file. |

The control parameters are declared as **strings**, not PowerShell switches. Pass explicit values as shown; do not use a bare `-delete` or `-swapSlot`. The custom `whatIf` parameter is not PowerShell's built-in `ShouldProcess` mechanism.

## Output and verification

Console messages identify matching (`v`), added (`+`), updated (`!`), and unlisted/deleted (`-`) settings. After applying, verify the target app or slot's application settings in Azure and check that Key Vault references resolve successfully.

Explicit validation failures exit with code `1`; in Azure DevOps (`TF_BUILD=True`), the helper terminates the process with that code. Successful execution reaches the end of the script without an explicit `exit 0`. JSON and Azure cmdlet errors are not comprehensively caught, so also review errors and the resulting Azure configuration.

The script manages application settings only. It does not configure connection-string entries, slot-sticky flags, or Key Vault secrets. Avoid JSON null values: the deletion check treats them as missing settings. Keep secret values out of committed JSON files and use Key Vault references instead.

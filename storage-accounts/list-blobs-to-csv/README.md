# Export Azure Blob Metadata to CSV

**Author:** Alex Degtyarev  
**Repository:** [Azure Ops Toolkit](https://github.com/nzalex1/azure-ops-toolkit)

[`enumerate-blobs.ps1`](enumerate-blobs.ps1) lists blobs in an Azure Storage container, optionally filters their names, and exports metadata sorted by modification time. It includes available deleted blobs and versions without downloading or changing blob content.

## Setup

Install the required PowerShell modules, sign in, and select your subscription:

```powershell
Install-Module -Name Az.Accounts, Az.Storage -Scope CurrentUser
Connect-AzAccount
Set-AzContext -Subscription '<subscription-id>'
```

Your identity needs access to the storage account and container. The default context obtained through `Get-AzStorageAccount` may require permission to retrieve account keys. Storage network restrictions also apply.

## Usage

Run from the directory containing the script:

```powershell
.\enumerate-blobs.ps1 `
    -StorageAccountName '<account>' `
    -ResourceGroupName '<resource-group>' `
    -ContainerName '<container>' `
    -MaxCount 3000 `
    -OutputPath '.\blobs.csv'
```

To filter names, add `-NamePattern`. It accepts a regular expression; for example, this matches names ending in `.json`:

```powershell
.\enumerate-blobs.ps1 `
    -StorageAccountName '<account>' `
    -ResourceGroupName '<resource-group>' `
    -ContainerName '<container>' `
    -MaxCount 3000 `
    -NamePattern '\.json$' `
    -OutputPath '.\json-blobs.csv'
```

To use an explicit storage key instead, pass `-StorageAccountKey $env:AZURE_STORAGE_KEY` and omit `-ResourceGroupName`. Supply the environment variable externally; do not commit account keys to the repository. This mode does not require an Azure sign-in for account discovery.

## Parameters

| Parameter | Description |
| --- | --- |
| `StorageAccountName` | Required. Storage account name. |
| `ContainerName` | Required. Container to list. |
| `ResourceGroupName` | Required unless `StorageAccountKey` is supplied. |
| `StorageAccountKey` | Optional access key; overrides the default context method. |
| `MaxCount` | Required positive integer. Maximum entries retrieved before filtering. |
| `NamePattern` | Optional regex filter. Omit to include all retrieved entries. |
| `OutputPath` | Required CSV path. Parent directory must exist; an existing file is overwritten. |
| `ConcurrentTaskCount` | Optional concurrency limit; defaults to `100`. |

## Output and limits

The script prints the container name and exports these CSV columns:

- `Name` — blob name.
- `LastModified` — modification timestamp, sorted oldest first.
- `Length` — size in bytes.

`MaxCount` limits the listing **before** the name filter runs. A limit of 3000 does not guarantee 3000 matching rows or a complete container inventory; the script does not follow continuation tokens. Deleted entries and versions depend on retained data and account configuration. Multiple entries can have the same name, and the CSV does not include version IDs or deletion status.

For built-in help:

```powershell
Get-Help .\enumerate-blobs.ps1 -Full
```

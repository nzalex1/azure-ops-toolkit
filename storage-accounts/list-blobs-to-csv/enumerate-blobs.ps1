<#
.SYNOPSIS
    Lists Azure blobs and exports selected properties to CSV.

.DESCRIPTION
    Gets a storage context, lists the target container, and retrieves up to
    MaxCount blob entries, including deleted blobs and versions. Optionally
    filters names with a regular expression, sorts by LastModified, and
    exports Name, LastModified, and Length to CSV.

    Uses the storage account's context from Get-AzStorageAccount unless an
    explicit storage account key is supplied. Sign in with Connect-AzAccount
    and select the subscription with Set-AzContext before running.

.PARAMETER StorageAccountName
    Storage account name. Alias: azStorageAccountName.

.PARAMETER StorageAccountKey
    Optional storage account access key. When supplied, creates a key-based
    context with New-AzStorageContext. Alias: azStorageAccountKey.

.PARAMETER ContainerName
    Container to enumerate. Alias: azContainerName.

.PARAMETER ResourceGroupName
    Resource group containing the storage account. Required for the default
    Get-AzStorageAccount context; optional when a storage key is supplied.
    Alias: azResourceGroupName.

.PARAMETER MaxCount
    Maximum number of blob entries retrieved BEFORE name filtering. This is
    one bounded listing, not automatic pagination through the whole container.
    Versions and deleted entries can contribute to the returned results.

.PARAMETER NamePattern
    Optional PowerShell regular expression applied to blob names. Omit to
    export all entries returned by the bounded listing.

.PARAMETER OutputPath
    Destination CSV path. Its parent directory must exist. An existing file
    at this path is overwritten.

.PARAMETER ConcurrentTaskCount
    Maximum concurrent storage operations. Defaults to 100.

.EXAMPLE
    .\enumerate-blobs.ps1 -StorageAccountName '<account>' -ContainerName '<container>' -ResourceGroupName '<resource-group>' -MaxCount 3000 -OutputPath '.\blobs.csv'

    Exports the retrieved entries without a name filter.

.EXAMPLE
    .\enumerate-blobs.ps1 -StorageAccountName '<account>' -ContainerName '<container>' -StorageAccountKey $env:AZURE_STORAGE_KEY -MaxCount 500 -NamePattern '\.json$' -OutputPath '.\json-blobs.csv'

    Uses an externally supplied access key and filters for JSON blob names.

.INPUTS
    None. Does not accept pipeline input.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Container name information is written to the pipeline. Blob metadata is
    written to the specified CSV; blob content is not downloaded or modified.

.NOTES
    Author: Alex Degtyarev
    Repository: https://github.com/nzalex1/azure-ops-toolkit
    Requires the Az.Accounts and Az.Storage PowerShell modules and access to
    the storage account/container. The default context may require permission
    to retrieve storage account keys. Deleted/version entries depend on the
    account's configuration and available retained data.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [Alias('azStorageAccountName')]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountName,

    [Alias('azStorageAccountKey')]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountKey,

    [Parameter(Mandatory = $true)]
    [Alias('azContainerName')]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName,

    [Alias('azResourceGroupName')]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$MaxCount,

    [ValidateNotNullOrEmpty()]
    [string]$NamePattern,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$ConcurrentTaskCount = 100
)

if ($NamePattern) {
    # Validate before making Azure requests.
    $null = [regex]::new($NamePattern)
}

if ($StorageAccountKey) {
    $connectionContext = New-AzStorageContext -StorageAccountName $StorageAccountName `
        -StorageAccountKey $StorageAccountKey -ErrorAction Stop
} else {
    if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
        throw 'ResourceGroupName is required when StorageAccountKey is not supplied.'
    }
    $connectionContext = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName `
        -AccountName $StorageAccountName -ErrorAction Stop).Context
}

Get-AzStorageContainer -Name $ContainerName -Context $connectionContext `
    -ErrorAction Stop | Select-Object Name

Get-AzStorageBlob -Context $connectionContext -IncludeDeleted -IncludeVersion `
    -Container $ContainerName -ConcurrentTaskCount $ConcurrentTaskCount `
    -MaxCount $MaxCount -ErrorAction Stop |
    Where-Object { -not $NamePattern -or $_.Name -match $NamePattern } |
    Select-Object Name, LastModified, Length |
    Sort-Object LastModified |
    Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop

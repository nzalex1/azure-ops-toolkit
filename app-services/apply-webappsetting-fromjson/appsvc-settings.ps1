<#
.Synopsis
   Script to apply AppService settings for the Azure Webapps and functionapps - RT P&SD
.DESCRIPTION
   Applies variables, supports Keyvault references (doesn't check the keyvault, just adds reference)
   Gets the settings from json file
   Supports App services slots
   Can run in whatif and in non-delete mode. In non-delete mode it applies/edits the settings in webapp but doesn't delete the settings if they don't exist in json settings file
.EXAMPLE
   .\appsvc-settings.ps1 -ResourceGroupName rg-example -appsvcFullName func-example -keyvaultFullName akvexample -AppSettingsFile ..\settings\func_dev.json -whatIf $true -delete $false
.INPUTS
   See description of parameters below
.OUTPUTS
   exit 0 if succeded
.NOTES
  Version:        0.2
  Author:         Alex D.
  Creation Date:  Feb 2022
  Purpose/Change: Working version, used for deployments in BIT
#>

param (
    [Parameter(Mandatory = $true)] [string]$ResourceGroupName,   # Resource group containing the App Service
    [Parameter(Mandatory = $true)] [string]$appsvcFullName,      # Full name of the Web App or Function App
    [Parameter(Mandatory = $true)] [string]$keyvaultFullName,    # Full name of the Key Vault
    [Parameter(Mandatory = $true)] [string]$AppSettingsFile,     # File with App service settings (json)
    [Parameter(Mandatory = $false)] [string]$swapSlot,           # (Optional) Indicates that the slot will be swapped - true/false
    [Parameter(Mandatory = $false)] [string]$slot,               # (Optional) swapSlot paramter must be true. Provide slot name (usually 'staging)
    [Parameter(Mandatory = $false)] [string]$whatIf = $true,     # (Optional) By default only checking the settings; set to $false to deploy settings
    [Parameter(Mandatory = $false)] [string]$delete = $false     # (Optional) Delete App service settings which are not in the file
)
function exitWithError ([string]$message) {
    write-host $message -ForegroundColor DarkRed
    # If we are in Az Devops pipeline we exit from the shell with the error, otherwise just exiting the script
    if ($Env:TF_BUILD -eq "True") {[Environment]::Exit(1)} else { exit 1 }
}

$keyvaultPointer = "keyvault"   # If vlaue of the variable in json file is 'Keyvault' we will generate keyvault link for it
$kvTemplate = "@Microsoft.KeyVault(SecretUri=https://__kvname__.vault.azure.net/secrets/__varname__/)"
if ( $whatIf -eq $true) { write-host "(Running in what-if mode, not doing actual changes)" -foregroundcolor DarkYellow }
write-host "======================"
write-host "Will be updating setting for Web App or Function:" -foregroundcolor DarkGreen
write-host "AppService: ${appsvcFullName}"
write-host "RG: ${ResourceGroupName}"
write-host "KeyVault: ${keyvaultFullName}"

# Quering app service
if ($swapSlot -eq $true) {
    # We need to make sure $slot parameter is also passed, exiting with the error otherwise
    if ($slot -eq '') { exitWithError "slot parameter must be passed if swapSlot parameter is set to true, exiting" }
    write-host 'Slot name is provided, deploy to slot'
    write-host "Slot name: ${slot}"
    $webApp=Get-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $appsvcFullName -Slot $slot
} else {
    $webApp=Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $appsvcFullName
    Write-Output 'Deploying to production slot'
}
write-host "---------------------"

if (! $webApp.SiteConfig) { exitWithError "Could not get settings from App service, exiting with error" }
$appSettings = @{};
$currentWebSettings = $webapp.SiteConfig.AppSettings
$currentWebSettings | foreach { $appSettings[$_.Name] = $_.Value }
$appServiceChanged = $false

# Getting data from AppSettings file and and checking
$newSettings = get-content $AppSettingsFile | convertfrom-json
if (!$newSettings) { exitWithError "Could not get settings from App Setting file, exiting with error" }

# Config File --> App service
foreach($newVar in $newSettings.settings.PSObject.Properties) {
    # Checking if this is keyvault reference
    if ($newVar.Value -eq $keyvaultPointer) {
        # Buiding the string for Keyvault reference
        $kvMessage = "(KeyVault reference)"
        $kvVarName = $newVar.name -replace "_", "-"
        $newVar.Value = ($kvTemplate -replace "__kvname__", $keyvaultFullName) -replace "__varname__", $kvVarName
    } else {$kvMessage = ""}
    # Checking if 'date_' is the prefix - we need to drop it
    if ( ($newVar.Value.Length -ge 5) -and ($newVar.Value.Substring(0,5) -eq "date_" ) ) {
        $newVar.Value = $newVar.Value.Substring(5) # Deleting "date_" prefix and leaving only text value of the date
    }
    # $newVar.Value
    # $appSettings[$newVar.Name]
    if ($newVar.Value -eq $appSettings[$newVar.Name]) { write-host "v variable with correct value already exists:" $newVar.Name $kvMessage -ForegroundColor DarkGreen; continue}
    if (! $appSettings[$newVar.Name]) {write-host "+ no variable in AppService, adding:"  $newVar.Name $kvMessage -ForegroundColor DarkRed}
    else {
        if ($newVar.Value -ne $appSettings[$newVar.Name]) {write-host "! variable is in AppService but different value, changing:"  $newVar.Name $kvMessage -ForegroundColor DarkYellow}
    }
    if ($whatIf -eq $false) {
        # write-host " Setting the variable:" $newVar.Name -ForegroundColor DarkYellow
        $appSettings[$newVar.Name] = $newVar.Value
        $appServiceChanged = $true
    }
}

# App service --> Config File (checking for varibles which present in AppService but not in config file)
foreach($appVar in $currentWebSettings) {
    if ($null -eq $newSettings.settings.($appVar.name)) {
        if ($delete -eq $true -and $whatIf -eq $false) {
                write-host "- deleting:" $appVar.name -ForegroundColor DarkRed
                $appSettings.Remove($appVar.name)
                $appServiceChanged = $true

        } else {
            write-host "- variable in AppSettings but not in the json File; use -delete and -whatif switches to delete:" $appVar.name -ForegroundColor DarkYellow
        }
    }
}
if ( ($appServiceChanged -eq $true) -and ($whatIf -eq $false) ) {
    write-host "Changes found, writing back to App service" -ForegroundColor DarkYellow
    if ($slot) {
        Set-AzWebAppSlot $webApp.ResourceGroup $webApp.Name -AppSettings $appSettings -slot $slot
    } else {
        Set-AzWebApp $webApp.ResourceGroup $webApp.Name -AppSettings $appSettings
    }
}

<#
.SYNOPSIS
    Creates a root certificate and a web certificate signed by that root.

.DESCRIPTION
    Creates an exportable RSA 2048-bit root certificate valid for 10 years
    and a web certificate valid for 2 years, using SHA-256. Both certificates
    are stored in Cert:\CurrentUser\My.

    Exports the root public certificate as a CER file and both certificates
    with their private keys as password-protected PFX files to
    $env:USERPROFILE\Desktop. Prompts separately for each PFX password.
    The output directory must already exist.

.PARAMETER RootCertName
    Root certificate common name and friendly name. Supply the name without
    the CN= prefix. CertificateName is an alias for this parameter.

.PARAMETER Domain
    DNS name for the web certificate. Also used in its friendly name.

.EXAMPLE
    .\generate-cert.ps1 -RootCertName 'Example QA Root CA' -Domain 'qa.example.com'

    Creates the certificates and prompts for their PFX export passwords.

.EXAMPLE
    Get-Help .\generate-cert.ps1 -Full

    Displays full usage information without creating certificates.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    System.IO.FileInfo
    Certificate export commands write file objects to the pipeline.
    Creates RootCA_<thumbprint>.cer, RootCA_<thumbprint>.pfx, and
    WebCert_<thumbprint>.pfx in the output directory.

.NOTES
    Requires Windows and the PKI module cmdlets New-SelfSignedCertificate,
    Export-Certificate, and Export-PfxCertificate.
    Each execution creates new certificates. Certificates are not automatically
    installed in the Trusted Root Certification Authorities store.
    Intended for development/test use. Protect the exported private keys.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [Alias('CertificateName')]
    [ValidateNotNullOrEmpty()]
    [string]$RootCertName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Domain
)

$certStoreLocation = "Cert:\CurrentUser\My"

# 1. Create the Root Certificate (valid for 10 years)
$rootCert = New-SelfSignedCertificate `
    -Subject "CN=$rootCertName" `
    -KeyExportPolicy Exportable `
    -KeyLength 2048 `
    -KeyUsage CertSign, CRLSign, DigitalSignature `
    -KeyAlgorithm RSA `
    -HashAlgorithm sha256 `
    -CertStoreLocation $certStoreLocation `
    -NotAfter (Get-Date).AddYears(10) `
    -FriendlyName $rootCertName `
    -TextExtension @("2.5.29.19={critical}{text}")

# 2. Create the Web Certificate (valid for 2 years), signed by the root certificate
$webCert = New-SelfSignedCertificate `
    -DnsName $domain `
    -CertStoreLocation $certStoreLocation `
    -Signer $rootCert `
    -KeyExportPolicy Exportable `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm sha256 `
    -NotAfter (Get-Date).AddYears(2) `
    -FriendlyName "Web SSL Cert for $domain" `
    -TextExtension @("2.5.29.19={text}")

# 3. Export both certs to PFX and CER if needed
$rootCertPath = "$env:USERPROFILE\Desktop\RootCA_$($rootCert.Thumbprint)"
$webCertPath = "$env:USERPROFILE\Desktop\WebCert_$($webCert.Thumbprint)"

# Export root certificate to .cer (public)
Export-Certificate -Cert $rootCert -FilePath "$rootCertPath.cer"

# Export root cert to .pfx (private + public)
Export-PfxCertificate -Cert $rootCert -FilePath "$rootCertPath.pfx" -Password (Read-Host -AsSecureString "Enter password for Root PFX")

# Export web certificate to .pfx
Export-PfxCertificate -Cert $webCert -FilePath "$webCertPath.pfx" -Password (Read-Host -AsSecureString "Enter password for Web PFX")

Write-Host "Certificates created and exported to Desktop."


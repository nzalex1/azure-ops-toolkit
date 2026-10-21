# Generate Development Certificates

[`generate-cert.ps1`](generate-cert.ps1) creates a self-signed root certificate and a web certificate signed by that root, then exports them for development or test use.

## Requirements

- Windows PowerShell with the PKI cmdlets `New-SelfSignedCertificate`, `Export-Certificate`, and `Export-PfxCertificate` available.
- An existing, writable `$env:USERPROFILE\Desktop` directory. The script uses this literal path, which may differ from a Desktop redirected to OneDrive.

## Run the script

Open PowerShell in the directory containing the script and run:

```powershell
.\generate-cert.ps1 -RootCertName "Example QA Root CA" -Domain "qa.example.com"
```

| Parameter | Description |
| --- | --- |
| `RootCertName` | Required. Root certificate common name and friendly name, without the `CN=` prefix. Also accepts the alias `CertificateName`. |
| `Domain` | Required. DNS hostname for the web certificate, such as `qa.example.com`. |

Enter a password when prompted for **Root PFX**, then another for **Web PFX**. These passwords protect the exported private keys and are required when importing the PFX files.

## What it creates

Both certificates use RSA 2048-bit keys and SHA-256 and are stored in the current user's personal certificate store, `Cert:\CurrentUser\My`.

| Certificate | Validity |
| --- | --- |
| Root certificate | 10 years |
| Web certificate | 2 years |

The following files are exported to `$env:USERPROFILE\Desktop`:

| File | Contents / purpose |
| --- | --- |
| `RootCA_<thumbprint>.cer` | Public root certificate; contains no private key. |
| `RootCA_<thumbprint>.pfx` | Root certificate and private key; keep protected. |
| `WebCert_<thumbprint>.pfx` | Web certificate and private key for importing into the target web hosting environment. |

`<thumbprint>` is replaced with the corresponding certificate's thumbprint.

## Notes

- Each run creates a new root and web certificate; it does not reuse existing ones.
- The script does not configure a website binding, DNS, or client trust. Creating certificates alone does not make HTTPS trusted by browsers.
- Protect the PFX files and passwords, and keep private keys out of source control.
- To view the built-in script help, run:

```powershell
Get-Help .\generate-cert.ps1 -Full
```

param(
    [Parameter(Mandatory)]
    [string]$Name,

    [int]$NotAfterYears = 100
)

# Krever PowerShell 7+ (pwsh). Windows PowerShell 5.1 sin RSACng mangler ExportPkcs8PrivateKey()
# (den kom i .NET Core / .NET 5+), og da blir PrivateKey-PEM-en TOM uten feilmelding — sertifikatet
# fjernes fra store, så privatnøkkelen går tapt. Fail tidlig og tydelig i stedet.
if ($PSVersionTable.PSVersion.Major -lt 6) {
    Write-Error "Dette scriptet krever PowerShell 7+ (pwsh). Windows PowerShell $($PSVersionTable.PSVersion) gir TOM PEM. Kjør: pwsh -File `"$PSCommandPath`" -Name $Name"
    exit 1
}

$cert = New-SelfSignedCertificate `
    -Subject "CN=$Name" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -NotAfter (Get-Date).AddYears($NotAfterYears)
 
# Eksporter .cer (public key) til Downloads
$cerPath = "$env:USERPROFILE\Downloads\$Name.cer"
Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null
Write-Host "`nPublic key eksportert til: $cerPath" -ForegroundColor Green
 
# Print thumbprint (brukes som kid)
Write-Host "`nThumbprint (kid): $($cert.Thumbprint)" -ForegroundColor Cyan
 
# Print private key som PEM (PKCS8) med literal \n
$rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
$pkcs8Bytes = $rsa.ExportPkcs8PrivateKey()
$base64 = [Convert]::ToBase64String($pkcs8Bytes, [Base64FormattingOptions]::InsertLineBreaks)
$pem = "-----BEGIN PRIVATE KEY-----\n" + ($base64 -replace "`r?`n", "\n") + "\n-----END PRIVATE KEY-----"
Write-Host "`nPrivate key (PEM):`n$pem" -ForegroundColor Yellow
 
# Rydd opp fra cert store
Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
Write-Host "`nSertifikat fjernet fra cert store." -ForegroundColor Gray
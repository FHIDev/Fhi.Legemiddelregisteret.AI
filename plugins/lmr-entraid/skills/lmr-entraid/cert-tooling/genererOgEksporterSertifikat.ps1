param(
    [Parameter(Mandatory)]
    [string]$Name,

    [int]$NotAfterYears = 100,

    # Skriver PEM-en (med ekte linjeskift) til denne fila i stedet for til konsollet. Bruk den:
    # da havner privatnøkkelen aldri i terminalhistorikk eller logger.
    [string]$PemFil
)

$ErrorActionPreference = 'Stop'

# Krever PowerShell 7+ (pwsh). Windows PowerShell 5.1 sin RSACng mangler ExportPkcs8PrivateKey()
# (den kom i .NET Core / .NET 5+), og da blir PrivateKey-PEM-en TOM uten feilmelding — sertifikatet
# fjernes fra store, så privatnøkkelen går tapt. Fail tidlig og tydelig i stedet.
if ($PSVersionTable.PSVersion.Major -lt 6) {
    Write-Error "Dette scriptet krever PowerShell 7+ (pwsh). Windows PowerShell $($PSVersionTable.PSVersion) gir TOM PEM. Kjør: pwsh -File `"$PSCommandPath`" -Name $Name"
    exit 1
}

# Overskriv aldri en eksisterende nøkkelfil: den kan være siste kopi av en nøkkel som er i bruk.
# Sjekkes FØR sertifikatet lages, så ingenting blir liggende igjen i store.
if ($PemFil -and (Test-Path -LiteralPath $PemFil)) {
    Write-Error "PEM-fila '$PemFil' finnes allerede. Velg en ny sti — scriptet overskriver ikke en nøkkel."
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
if (-not $base64) {
    # Fjern ALDRI sertifikatet fra store hvis nøkkelen ikke ble eksportert — da er den tapt.
    Write-Error "Eksporten av privatnøkkelen ga tomt resultat. Sertifikatet ($($cert.Thumbprint)) er IKKE fjernet fra Cert:\CurrentUser\My."
    exit 1
}
if ($PemFil) {
    $pemEkte = "-----BEGIN PRIVATE KEY-----`n" + ($base64 -replace "`r?`n", "`n") + "`n-----END PRIVATE KEY-----`n"
    # CreateNew feiler hvis fila har dukket opp siden sjekken over, i stedet for å overskrive.
    $strom = [System.IO.File]::Open($PemFil, [System.IO.FileMode]::CreateNew)
    try {
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($pemEkte)
        $strom.Write($bytes, 0, $bytes.Length)
    } finally {
        $strom.Dispose()
    }
    Write-Host "`nPrivatnøkkel (PEM, ekte linjeskift) skrevet til: $PemFil" -ForegroundColor Yellow
    Write-Host "For miljøvariabler (Octopus/App Service) trengs literal \n i stedet - se SERTIFIKATER.md." -ForegroundColor Gray
} else {
    $pem = "-----BEGIN PRIVATE KEY-----\n" + ($base64 -replace "`r?`n", "\n") + "\n-----END PRIVATE KEY-----"
    Write-Host "`nPrivate key (PEM):`n$pem" -ForegroundColor Yellow
}
 
# Rydd opp fra cert store
Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
Write-Host "`nSertifikat fjernet fra cert store." -ForegroundColor Gray
# Sammenlign sertifikatet (public key) med private key
# Kjor dette scriptet fra mappen der filene ligger:
#   C:\Users\LURE\Documents\Authentication
#
# Forventet filstruktur:
#   - publicKeyAzure.cer  (sertifikatet lastet opp til Azure)
#   - privateKey.pem      (private key i PEM-format)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$certPath = Join-Path $scriptDir "publicKeyAzure.cer"
$pemPath = Join-Path $scriptDir "privateKey.pem"

Write-Host "=== Verifiserer at private key matcher sertifikat ===" -ForegroundColor Cyan
Write-Host ""

# Sjekk at filene eksisterer
if (-not (Test-Path $certPath)) {
    Write-Host "FEIL: Fant ikke sertifikatfil: $certPath" -ForegroundColor Red
    Read-Host "Trykk Enter for aa avslutte"
    exit 1
}

if (-not (Test-Path $pemPath)) {
    Write-Host "FEIL: Fant ikke private key fil: $pemPath" -ForegroundColor Red
    Read-Host "Trykk Enter for aa avslutte"
    exit 1
}

# Les sertifikatet
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)

Write-Host "=== Sertifikat (public key) ===" -ForegroundColor Green
Write-Host "Fil: $certPath"
Write-Host "Subject: $($cert.Subject)"
Write-Host "Thumbprint (hex): $($cert.Thumbprint)"

# Beregn x5t (base64url-kodet SHA-1 thumbprint) - dette er kid for EntraId
$thumbprintBytes = [byte[]]::new($cert.Thumbprint.Length / 2)
for ($i = 0; $i -lt $thumbprintBytes.Length; $i++) {
    $thumbprintBytes[$i] = [Convert]::ToByte($cert.Thumbprint.Substring($i * 2, 2), 16)
}
$x5t = [Convert]::ToBase64String($thumbprintBytes) -replace '\+', '-' -replace '/', '_' -replace '=', ''
Write-Host "kid (x5t/base64url): $x5t" -ForegroundColor Yellow
Write-Host ""

# Hent modulus fra sertifikatet
$rsaFromCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($cert)
$paramsFromCert = $rsaFromCert.ExportParameters($false)
$modulusFromCert = [Convert]::ToBase64String($paramsFromCert.Modulus)

Write-Host "Modulus (forste 80 tegn): $($modulusFromCert.Substring(0, 80))"
Write-Host ""

# Les private key fra PEM-fil
Write-Host "=== Private key ===" -ForegroundColor Green
Write-Host "Fil: $pemPath"

$pemContent = Get-Content $pemPath -Raw
$pemContent = $pemContent -replace '-----BEGIN PRIVATE KEY-----', '' -replace '-----END PRIVATE KEY-----', '' -replace '\s', ''
$privateKeyBytes = [Convert]::FromBase64String($pemContent)

$rsa = [System.Security.Cryptography.RSA]::Create()
$bytesRead = 0
$rsa.ImportPkcs8PrivateKey($privateKeyBytes, [ref]$bytesRead)
$paramsFromPem = $rsa.ExportParameters($false)
$modulusFromPem = [Convert]::ToBase64String($paramsFromPem.Modulus)

Write-Host "Modulus (forste 80 tegn): $($modulusFromPem.Substring(0, 80))"
Write-Host ""

# Sammenlign
if ($modulusFromCert -eq $modulusFromPem) {
    Write-Host "*** MATCH! Private key matcher sertifikatet ***" -ForegroundColor Green
    Write-Host ""
    Write-Host "Du kan bruke disse verdiene i appsettings.json:" -ForegroundColor Cyan
    Write-Host "  kid: $x5t"
} else {
    Write-Host "*** MISMATCH! Private key matcher IKKE sertifikatet ***" -ForegroundColor Red
    Write-Host ""
    Write-Host "Private key og sertifikat tilhorer forskjellige nokkkelpar."
}

Write-Host ""
Read-Host "Trykk Enter for aa avslutte"

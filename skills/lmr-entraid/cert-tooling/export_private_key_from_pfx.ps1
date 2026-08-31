# Eksporter private key fra PFX-fil til PEM-format
# PFX-filen maa ligge i samme mappe som dette scriptet.
#
# Output:
#   - privateKey.pem (lagres i samme mappe)
#   - Viser kid (x5t) og JSON-escaped private key for appsettings.json

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputPath = Join-Path $scriptDir "privateKey.pem"

$pfxFileName = Read-Host "Skriv inn filnavn paa PFX-filen (f.eks. certificate.pfx)"
$pfxPath = Join-Path $scriptDir $pfxFileName

if (-not (Test-Path $pfxPath)) {
    Write-Host "FEIL: Fant ikke PFX-fil: $pfxPath" -ForegroundColor Red
    Read-Host "Trykk Enter for aa avslutte"
    exit 1
}

$password = Read-Host "Skriv inn passord for PFX-filen" -AsSecureString

try {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
        $pfxPath,
        $password,
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    )

    Write-Host ""
    Write-Host "=== Sertifikat lastet ===" -ForegroundColor Green
    Write-Host "Subject: $($cert.Subject)"
    Write-Host "Thumbprint (hex): $($cert.Thumbprint)"

    # Beregn x5t (base64url-kodet thumbprint) for EntraId
    $thumbprintBytes = [byte[]]::new($cert.Thumbprint.Length / 2)
    for ($i = 0; $i -lt $thumbprintBytes.Length; $i++) {
        $thumbprintBytes[$i] = [Convert]::ToByte($cert.Thumbprint.Substring($i * 2, 2), 16)
    }
    $x5t = [Convert]::ToBase64String($thumbprintBytes) -replace '\+', '-' -replace '/', '_' -replace '=', ''
    Write-Host "kid (x5t/base64url): $x5t" -ForegroundColor Yellow
    Write-Host ""

    $privateKey = $cert.PrivateKey

    if ($privateKey) {
        $rsaParams = $privateKey.ExportParameters($true)

        function Get-DerLength($length) {
            if ($length -lt 128) { return [byte[]]@($length) }
            elseif ($length -lt 256) { return [byte[]]@(0x81, $length) }
            else { return [byte[]]@(0x82, ($length -shr 8), ($length -band 0xFF)) }
        }

        function Get-DerInteger($bytes) {
            if ($bytes[0] -ge 128) { $bytes = @([byte]0) + $bytes }
            $len = Get-DerLength $bytes.Length
            return @([byte]0x02) + $len + $bytes
        }

        $version = Get-DerInteger @(0)
        $n = Get-DerInteger $rsaParams.Modulus
        $e = Get-DerInteger $rsaParams.Exponent
        $d = Get-DerInteger $rsaParams.D
        $p = Get-DerInteger $rsaParams.P
        $q = Get-DerInteger $rsaParams.Q
        $dp = Get-DerInteger $rsaParams.DP
        $dq = Get-DerInteger $rsaParams.DQ
        $qi = Get-DerInteger $rsaParams.InverseQ

        $rsaPrivateKeyContent = $version + $n + $e + $d + $p + $q + $dp + $dq + $qi
        $rsaPrivateKeyLen = Get-DerLength $rsaPrivateKeyContent.Length
        $rsaPrivateKey = @([byte]0x30) + $rsaPrivateKeyLen + $rsaPrivateKeyContent

        $pkcs8Version = Get-DerInteger @(0)
        $rsaOid = [byte[]]@(0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01)
        $null_param = [byte[]]@(0x05, 0x00)
        $algIdContent = $rsaOid + $null_param
        $algIdLen = Get-DerLength $algIdContent.Length
        $algId = @([byte]0x30) + $algIdLen + $algIdContent

        $octetLen = Get-DerLength $rsaPrivateKey.Length
        $octetString = @([byte]0x04) + $octetLen + $rsaPrivateKey

        $pkcs8Content = $pkcs8Version + $algId + $octetString
        $pkcs8Len = Get-DerLength $pkcs8Content.Length
        $pkcs8 = [byte[]](@([byte]0x30) + $pkcs8Len + $pkcs8Content)

        $base64 = [Convert]::ToBase64String($pkcs8, [Base64FormattingOptions]::InsertLineBreaks)
        $pem = "-----BEGIN PRIVATE KEY-----`r`n$base64`r`n-----END PRIVATE KEY-----"

        $pem | Out-File -FilePath $outputPath -Encoding ascii

        Write-Host "=== Private key eksportert ===" -ForegroundColor Green
        Write-Host "Lagret til: $outputPath"
        Write-Host ""

        $jsonEscaped = $pem -replace "`r`n", "\n"

        Write-Host "=== For appsettings.json ===" -ForegroundColor Cyan
        Write-Host "kid: $x5t" -ForegroundColor Yellow
        Write-Host ""

        $jsonEscaped | Set-Clipboard
        Write-Host "(JSON-escaped private key er kopiert til utklippstavlen)" -ForegroundColor Green

    } else {
        Write-Host "Kunne ikke hente private key fra sertifikatet" -ForegroundColor Red
    }

} catch {
    Write-Host "Feil: $_" -ForegroundColor Red
}

Write-Host ""
Read-Host "Trykk Enter for aa avslutte"

# Sertifikater for EntraId-klienter

Klient-app-registreringene (`.Client.Machine` og `.Client.Web`) autentiserer seg med
**client assertion** (`private_key_jwt`) signert av et sertifikat. Rene ressurser (`.Api`)
trenger ikke sertifikat.

Scripts ligger i `../cert-tooling/`.

## ⚠️ Kjør med `pwsh` (PowerShell 7+), aldri Windows PowerShell 5.1

5.1 sin `RSACng` mangler `ExportPkcs8PrivateKey()` (den kom i .NET Core / .NET 5+). Resultatet
er at **PEM-en blir tom uten feilmelding**, samtidig som scriptet fjerner sertifikatet fra
cert store — så **privatnøkkelen går tapt**.

`genererOgEksporterSertifikat.ps1` har en versjonssjekk som feiler tydelig, men kjør uansett:

```bash
pwsh -File cert-tooling/genererOgEksporterSertifikat.ps1 -Name "MinTjeneste-Test"
```

## Utløpstid

| Miljø | Levetid | Hvorfor |
|---|---|---|
| Dev / Test / QA | **100 år** (scriptets default) | Slipper fornyelse i test |
| **Prod** | **2 år** — `-NotAfterYears 2` | Sikkerhetshygiene |

⚠️ **Prod-sertifikater må fornyes annethvert år.** Generer nytt i god tid før utløp, legg inn ny
base64 i `.bicepparam`, deploy, oppdater secret med ny PEM, og fjern det gamle sertifikatet fra
`keyCredentials` når alle instanser har fått den nye nøkkelen.

## Flyten

```bash
# 1. Generér (Test: 100 år er default; Prod: -NotAfterYears 2)
pwsh -File cert-tooling/genererOgEksporterSertifikat.ps1 -Name "MinTjeneste-Test"
#    → .cer i ~/Downloads, thumbprint og PEM til konsollet

# 2. base64 av det OFFENTLIGE sertifikatet, inn i .bicepparam
base64 -w0 ~/Downloads/MinTjeneste-Test.cer
```

Scriptet gir tre ting:

| Verdi | Hemmelig? | Hvor den skal |
|---|---|---|
| `.cer` (offentlig sertifikat) | Nei | base64 → `.bicepparam` → `keyCredentials` |
| **Thumbprint** (40 tegn hex) | Nei | `OidcClients:EntraIdClient:kid` i appsettings |
| **PEM** (privatnøkkel) | **JA** | Secret-mekanismen for miljøet. **Aldri i git.** |

`kid` er altså sertifikat-thumbprint i hex — ikke en base64-kodet verdi, og ikke noe Graph
tildeler.

## ⚠️ Scriptet skriver privatnøkkelen til konsollet

Kjør det gjennom en wrapper som fanger PEM-en rett til fil hvis output kan bli logget. Ellers
havner privatnøkkelen i terminalhistorikk eller CI-logger.

## ⚠️ PEM-formatfella: literal `\n` vs. ekte linjeskift

Scriptet skriver PEM-en på **én linje med literal `\n`** (backslash-n). Det er riktig format
for **miljøvariabler** (Azure App Service, Octopus, OS-env) — der er verdien en ren streng uten
JSON-lag.

Men `secrets.json` og `appsettings*.json` leses av **JSON-config-provideren**, som tolker `\n`
som linjeskift. Mater du literal-`\n`-PEM-en rått inn i `dotnet user-secrets set`, JSON-escaper
CLI-en backslashen → `\\n` i fila → verdien appen får er literal `\n`, som ikke er gyldig PEM.

**Regel:**

| Mål | Format |
|---|---|
| Miljøvariabel (App Service, Octopus) | literal `\n` — som scriptet skriver den |
| `secrets.json` / `appsettings*.json` | **ekte linjeskift** |

Konverter før `user-secrets set`:

```bash
# ⚠️ På Git Bash matcher ikke sed/perl/awk mønsteret \\n mot literal backslash-n.
#    Bruk hex i stedet.
perl -0777 -pe 's/\x5c\x6e/\n/g' key-literal.pem > key.pem
```

**Sjekk:** `secrets.json` skal vise `\n` (én backslash), ikke `\\n`.

Verifiser at nøkkelen er gyldig:

```bash
openssl pkey -in key.pem -check -noout     # → "Key is valid"
```

## Sertifikatet i Bicep

```bicep
keyCredentials: [
  {
    type: 'AsymmetricX509Cert'
    usage: 'Verify'
    key: sertifikatBase64        // base64 av .cer — offentlig, committes
  }
]
```

`customKeyIdentifier` kan utelates: Graph setter den til sertifikatets thumbprint selv.

⚠️ **`passwordCredentials` (client secrets) støttes ikke** av Graph Bicep-extensionen. Det er
uansett riktig for LMR — vi bruker sertifikat overalt.

## Sertifikatet hører hjemme i `.bicepparam`

Det offentlige sertifikatet er ikke en hemmelighet. Base64-en committes i parameterfila, og et
sertifikatbytte blir dermed en synlig `git diff` — ikke en fil noen må huske å ha liggende
lokalt.

Privatnøkkelen (PEM) går aldri i git. Den settes som secret i miljøet.

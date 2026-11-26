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
pwsh -File cert-tooling/genererOgEksporterSertifikat.ps1 -Name "MinTjeneste-Test" -PemFil ~/MinTjeneste-Test.pem
```

## Utløpstid

| Miljø | Levetid | Hvorfor |
|---|---|---|
| Dev / Test / QA | **100 år** (scriptets default) | Slipper fornyelse i test |
| **Prod** | **2 år** — `-NotAfterYears 2` | Sikkerhetshygiene |

⚠️ **Prod-sertifikater må fornyes annethvert år.** Se «Fornyelse» under — det gjøres aldri ved å
deploye malen på nytt.

## Flyten

```bash
# 1. Generér (Test: 100 år er default; Prod: -NotAfterYears 2)
pwsh -File cert-tooling/genererOgEksporterSertifikat.ps1 -Name "MinTjeneste-Test" -PemFil ~/MinTjeneste-Test.pem
#    → .cer i ~/Downloads, thumbprint til konsollet, PEM til fila

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

## ⚠️ Bruk `-PemFil` — ellers skrives privatnøkkelen til konsollet

Uten `-PemFil` skriver scriptet PEM-en til konsollet, og da havner den i terminalhistorikk, logger
og — med en agent — i samtaleloggen. Med `-PemFil <sti>` skrives den rett til fil med ekte
linjeskift. Kontroller den uten å skrive den ut: `openssl pkey -in <sti> -check -noout`.

## ⚠️ PEM-formatfella: literal `\n` vs. ekte linjeskift

Uten `-PemFil` skriver scriptet PEM-en på **én linje med literal `\n`** (backslash-n); med
`-PemFil` får fila ekte linjeskift. Literal `\n` er riktig format for **miljøvariabler** (Azure
App Service, Octopus, OS-env) — der er verdien en ren streng uten JSON-lag.

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

Det offentlige sertifikatet er ikke en hemmelighet, og base64-en committes i parameterfila. Den
brukes bare ved **opprettelsen**. Privatnøkkelen (PEM) går aldri i git; den settes som secret i
miljøet.

## Fornyelse

**LMR (`Fhi.Lmr.*.Client.*`): automatisk.** `Fhi.Lmr.SertifikatFornyelse` (Azure Function) roterer
sertifikatet når det er under fire uker til utløp, legger privatnøkkel og thumbprint i Key Vault og
Octopus, og laster opp det nye sertifikatet til Entra. Den virker bare for app-registreringer som
står i dens koblingstabell og som funksjonens managed identity eier — se README-en i det repoet
for hvordan en ny tjeneste legges til.

**Grossiststatistikken og andre uten automatikk: manuelt, og bare additivt.**

```bash
# .cer fra scriptet er binær DER, men --cert @fil leses som tekst. Konverter det OFFENTLIGE
# sertifikatet til PEM først (det er ikke privatnøkkelen, og fila er ikke hemmelig).
openssl x509 -inform der -in "$HOME/Downloads/<Navn>.cer" -out "$HOME/Downloads/<Navn>-offentlig.crt"

# Legg det nye sertifikatet TIL ved siden av det gamle (--append — uten den erstattes alle)
az ad app credential reset --id <appId> --cert "@$HOME/Downloads/<Navn>-offentlig.crt" --append
# ... oppdater secret (PEM) og kid i miljøet, rull ut, kontroller at innlogging/kall virker ...
# Fjern det gamle først når ingen instans bruker det lenger
az ad app credential list --id <appId> --cert --query "[].{keyId:keyId, slutt:endDateTime}" -o table
az ad app credential delete --id <appId> --key-id <keyId-til-det-gamle> --cert
```

⚠️ **Uten `--append` erstatter `az ad app credential reset` alle eksisterende nøkler**, og appen
slutter å virke til den nye PEM-en er rullet ut.

**Etter enhver fornyelse — automatisk eller manuell — viser `verifiser.sh` avvik i
`sertifikatThumbprints`.** Det er forventet. Skriv ny baseline for app-registreringen
(`entraid/baseline/<uniqueName>.json`), ellers stopper `entraid/scripts/legg-til-kant.sh` på
avviket neste gang noen skal legge til en kant.

# cert-tooling

PowerShell-scripts for sertifikater til EntraID **client credentials** (client
assertion) og til brukerinnloggings-klienter (`private_key_jwt`).

> ⚠️ **Kjør med `pwsh` (PowerShell 7+), ikke Windows PowerShell 5.1.** 5.1 sin `RSACng`
> mangler `ExportPkcs8PrivateKey()` → PEM-en blir **tom uten feilmelding**, og sertifikatet
> fjernes fra store (privatnøkkelen går tapt). `genererOgEksporterSertifikat.ps1` har nå en
> versjonssjekk som feiler tydelig, men kjør uansett: `pwsh -File genererOgEksporterSertifikat.ps1 ...`

Brukes for **klient**-app-regene (`Fhi.Lmr.<Tjeneste>.Client.Machine`) — altså
tjenester som gjør utgående EntraID-kall. Ressurs-app-reger (som Grunndata) trenger
ikke sertifikat.

## Scripts

| Script | Hva |
|---|---|
| `genererOgEksporterSertifikat.ps1` | Lager self-signed cert (RSA 2048, utløp styres av `-NotAfterYears`, default 100), eksporterer `.cer` (public) til Downloads, printer **thumbprint** (= `kid`) og **privatnøkkel som PEM** (PKCS8, med literal `\n` klar for env-var). Fjerner cert fra store etterpå. |
| `export_private_key_from_pfx.ps1` | Henter privatnøkkel (PEM) ut av en eksisterende `.pfx`. |
| `compare_keys.ps1` | Sammenligner nøkler (verifisering). |

## Utløpstid (policy)

- **Test-sertifikater: 100 år** (scriptets default — slipper fornyelse i test).
- **Prod-sertifikater: 2 år** — bedre sikkerhetshygiene. **Må fornyes annethvert år:** generer nytt
  cert i god tid før utløp, last opp ny `.cer` på app-regen, oppdater secret med ny PEM, fjern gammel `.cer`.

## Flyt per klient-app-reg

1. Generér cert:
   - **Test:** `./genererOgEksporterSertifikat.ps1 -Name "<Tjeneste>-Test"` (100 år, default)
   - **Prod:** `./genererOgEksporterSertifikat.ps1 -Name "<Tjeneste>-Prod" -NotAfterYears 2`
2. Last opp `.cer` (public) til `Client.Machine`-app-regen (`keyCredentials`).
3. `kid` = thumbprint → `OidcClients:EntraIdClient:kid` i appsettings (ikke hemmelig).
4. PEM (privatnøkkel) → secret-mekanisme per miljø (Azure App Service / Octopus / user secrets),
   nøkkel `OidcClients:EntraIdClient:PrivateKey`. **Aldri** inn i appsettings/git.

> **Med Bicep er steg 2 automatisert:** `.cer`-en base64-es inn i `.bicepparam`, og
> `keyCredentials` settes av malen. Utvikler trenger kun å sette PEM-en som secret.
>
> ```bash
> base64 -w0 ~/Downloads/<Tjeneste>-<Miljo>.cer
> ```

## ⚠️ Hemmeligheter

`.cer` er public (ufarlig), men **PEM/PFX/privatnøkler er hemmeligheter** og skal
ALDRI committes. Rot-`.gitignore` i dette repoet blokkerer `*.pem/*.pfx/*.key/*.p12/*.crt`.

⚠️ **`*.cer` er bevisst IKKE blokkert.** Bicep-malene tar sertifikatet som base64 i en
`.bicepparam`, og det offentlige sertifikatet skal kunne committes og reviewes.

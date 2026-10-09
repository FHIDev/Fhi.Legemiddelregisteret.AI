# Meldingsformidler — AzureFilestore-slot

Dette dokumentet beskriver mønsteret, ikke miljøet: navn på ressurser, adresser og tilgangsnøkler står i
driftsmiljøet og pipelines, ikke her. Kunnskapen gjelder bare Meldingsformidler (repo-skillen
`lmr-meldingsformidler`, `references/kildeintegrasjoner.md`).

## Hva det er

Et deployment-slot i Meldingsformidlers testmiljø som henter meldinger fra Azure File Shares i stedet for fra de
reelle kanalene. Slotten deployes sammen med testapplikasjonen (se `Meldingsformidler.AzureDev.Publish.yml` i
Meldingsformidler) og har egne app settings i driftsmiljøet.

## Formål

Bro mellom Azure File Shares og Meldingsmottak i testmiljøer. Lar deg legge inn Eik- og Farmapro-meldinger via Azure
Files i stedet for de reelle kanalene: WebDAV mot Eik FileDrop, som er standard i basekonfigurasjonen, og SonicMQ for
Farmapro (legacy).

Brukes bare i testmiljøer. Skal ikke kjøre i produksjon.

## Hvordan det fungerer

Bakgrunnstjenestene i Meldingsformidler er konfigurert med `HostedService`-oppføringer, og `isDisabled` styrer hver
enkelt per miljø:

- `HentEikMeldingerHostedService` henter Eik-meldinger (JSON). Den er aktiv i `appsettings.AzureDev.json`.
- `HentFarmaproReseptmeldingerHostedService` og `HentFarmaproLokalvaremeldingerHostedService` henter Farmapro-meldinger
  (XML). De er avslått i `appsettings.json` og i `appsettings.AzureDev.json`. Om sloten bruker Farmapro-kanalen,
  avhenger derfor av overstyringer i driftsmiljøet, og de kan ikke leses av repoet.

For hvert funnet fil: les innholdet, send til Meldingsmottak (test-instansen) og slett filen ved vellykket sending.

Konsesjonsnummeret leses fra meldingsinnholdet (XML-feltet `<Kilde>`) eller fra filnavnet (prefiks `<konsesjonsnr>_`).

## Konfigurasjon

Bruk konfigurasjonsnøklene som mønster. Verdiene settes per miljø.

### I appsettings.AzureDev.json (følger deployen)

| Nøkkel | Forklaring |
|--------|------------|
| `FarmaproMeldingskoKonfigurasjon:Meldingskotype` | `AzureFilestore` slår av SonicMQ og slår på Azure Files for Farmapro |
| `EikFileDropKonfigurasjon:FileStorage:Katalog` | Undermappe i file share for Eik-meldinger, én per miljø |
| `EikFileDropKonfigurasjon:FileStorage:Root` | Adressen til file share for Eik-meldinger |
| `FarmaproMeldingskoKonfigurasjon:AzureFilestoreKonfigurasjon:Reseptmeldingsko:Katalog` / `:Root` | Undermappe og file share for Farmapro-reseptmeldinger |
| `FarmaproMeldingskoKonfigurasjon:AzureFilestoreKonfigurasjon:Lokalvaremeldingsko:Katalog` / `:Root` | Undermappe og file share for lokalvaremeldinger |

### App settings i driftsmiljøet (ikke i appsettings-filene)

Disse skiller seg per slot/instans og settes utenfor repoet:

| Nøkkel | Formål |
|--------|--------|
| `EikFileDropKonfigurasjon:FileDropType` | Settes til `AzureFilestore` i stedet for `WebDav` |
| `EikFileDropKonfigurasjon:FileStorage:Signatur` | Tilgangstoken (SAS) til file share for Eik-meldinger |
| `FarmaproMeldingskoKonfigurasjon:AzureFilestoreKonfigurasjon:Reseptmeldingsko:Signatur` | Tilgangstoken til Farmapro-reseptmeldinger |
| `FarmaproMeldingskoKonfigurasjon:AzureFilestoreKonfigurasjon:Lokalvaremeldingsko:Signatur` | Tilgangstoken til lokalvaremeldinger |
| `ASPNETCORE_ENVIRONMENT` | `AzureDev` for denne instansen |

Tilgangstokenene er hemmeligheter. De skal aldri sjekkes inn, og de beskrives ikke i agentfiler.

## Hvorfor et deployment-slot?

Sloten bruker samme App Service Plan som testapplikasjonen, uten ekstra kostnad. Den deler infrastruktur og
deployment-pipeline med testapplikasjonen, men har egne app settings som skrur av normale integrasjoner og skrur på
Azure Files.

## Flere miljøer

Mønsteret støtter én instans per testmiljø. Katalognavnene skiller miljøene i de delte file sharene. Andre miljøers
instanser har tilsvarende `appsettings.<miljø>.json`-filer med egne katalognavn og egne tokens.

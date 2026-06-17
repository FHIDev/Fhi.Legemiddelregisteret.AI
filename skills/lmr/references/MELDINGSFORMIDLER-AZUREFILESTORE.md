# Meldingsformidler — AzureFilestore-slot

## Hva det er

Et deployment-slot (`azurefilestore`) på App Service `legemiddelregisteret-meldingsformidler-test` (FHI-LMR-Dev, resource group `rg-legemiddelregisteret-test`).

URL: `https://legemiddelregisteret-meldingsformidler-t-azurefilestore.azurewebsites.net`

## Formål

Bro mellom Azure File Shares og Meldingsmottak i testmiljøer. Lar deg injisere Farmapro- og Eik-meldinger via Azure Files i stedet for de reelle kanalene (SonicMQ og WebDAV) som brukes i produksjon.

Brukes eksklusivt i testmiljøer (AzureDev, Test, QA). Skal ikke kjøre i produksjon.

## Hvordan det fungerer

Tre bakgrunnstjenester poller Azure File Shares kontinuerlig:
- `HentFarmaproReseptmeldingerHostedService` — henter Farmapro reseptmeldinger (XML)
- `HentFarmaproLokalvaremeldingerHostedService` — henter Farmapro lokalvaremeldinger (XML)
- `HentEikMeldingerHostedService` — henter Eik-meldinger (JSON)

For hvert funnet fil: les innholdet → send til Meldingsmottak (test-instansen) → slett filen ved vellykket sending.

Konsesjonsnummeret leses fra meldingsinnholdet (XML-feltet `<Kilde>`) eller fra filnavn (prefiks `<konsesjonsnr>_`).

## Konfigurasjon

### Verdier i appsettings.AzureDev.json (bakt inn i deployen)

| Nøkkel | Verdi | Forklaring |
|--------|-------|------------|
| `FarmaproMeldingskoKonfigurasjon:Meldingskotype` | `AzureFilestore` | Skrur av SonicMQ, slår på Azure Files for Farmapro |
| `EikFileDropKonfigurasjon:FileStorage:Katalog` | `azure-dev` | Undermappe i eikmeldinger-share |
| `EikFileDropKonfigurasjon:FileStorage:Root` | `https://fhilegemiddelregisteret.file.core.windows.net/eikmeldinger` | File share for Eik-meldinger |
| `FarmaproMeldingskoKonfigurasjon:AzureFilestoreKonfigurasjon:Reseptmeldingsko:Katalog` | `azure-dev/reseptmeldinger` | Undermappe for Farmapro reseptmeldinger |
| `FarmaproMeldingskoKonfigurasjon:AzureFilestoreKonfigurasjon:Reseptmeldingsko:Root` | `https://fhilegemiddelregisteret.file.core.windows.net/farmapromeldinger` | File share for Farmapro |
| `FarmaproMeldingskoKonfigurasjon:AzureFilestoreKonfigurasjon:Lokalvaremeldingsko:Katalog` | `azure-dev/lokalvaremeldinger` | Undermappe for lokalvaremeldinger |
| `FarmaproMeldingskoKonfigurasjon:AzureFilestoreKonfigurasjon:Lokalvaremeldingsko:Root` | `https://fhilegemiddelregisteret.file.core.windows.net/farmapromeldinger` | Samme file share som resept |

### App settings i Azure Portal

Disse settes i Azure Portal (ikke i appsettings-filene) fordi de skiller seg per slot/instans:

| App setting-nøkkel | Formål |
|--------------------|--------|
| `EikFileDropKonfigurasjon:FileDropType` | Skal settes til `AzureFilestore` (i stedet for `webdav`) |
| `EikFileDropKonfigurasjon:FileStorage:Signatur` | SAS-token for tilgang til eikmeldinger-file share |
| `FarmaproMeldingskoKonfigurasjon:AzureFilestoreKonfigurasjon:Reseptmeldingsko:Signatur` | SAS-token for farmapromeldinger (resept) |
| `FarmaproMeldingskoKonfigurasjon:AzureFilestoreKonfigurasjon:Lokalvaremeldingsko:Signatur` | SAS-token for farmapromeldinger (lokalvare) |
| `ASPNETCORE_ENVIRONMENT` | `AzureDev` for denne instansen |

SAS-tokenene gis tilgang til hele storage-kontoen (`ss=fqt&srt=sco`) med lese-, skrive- og sletterettigheter (`sp=rwdlacup`). Tokenene er langtlevende og settes én gang i Azure Portal.

## Hvorfor et deployment-slot?

Sloten bruker samme App Service Plan som `legemiddelregisteret-meldingsformidler-test` uten ekstra kostnad. Den deler infrastruktur og deployment-pipeline med test-applikasjonen, men har egne app settings som skrur av normale integrasjoner og skrur på Azure Files.

## Flere miljøer

Mønsteret støtter én instans per testmiljø. Katalog-navnene (`azure-dev`, `test`, `qa`) skiller miljøene i de delte file shares. Andre miljøers instanser vil ha tilsvarende `appsettings.{Miljø}.json`-filer med tilpassede katalognavn og egne SAS-tokens.

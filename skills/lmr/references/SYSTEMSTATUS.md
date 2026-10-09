# SystemStatus

LMR-tjenestene eksponerer et anonymt `/health`-endepunkt etter et felles mønster, og Kontroll viser svarene i
systemstatus-oversikten. Dette dokumentet beskriver mønsteret på tjenestesiden og peker til der Kontroll-siden er
beskrevet.

## Mønsteret i tjenestene

- Pakken `Fhi.Lmr.Felles.Status` leverer helsesjekkene og svarformatet (`SystemStatus`, `HealthChecksResponse`).
  `SystemStatusCheck` rapporterer kjøremiljø, byggkonfigurasjon og kildekode-tag pluss de hvitelistede
  konfigurasjonsverdiene.
- `/health` er anonymt (`AllowAnonymous`). Statusen står i JSON-svaret, ikke i HTTP-statuskoden. Kontroll leser svaret
  både ved 200 og ved 503, og behandler andre statuskoder som `Unhealthy`. Hvilken statuskode en tjeneste svarer med,
  er derfor tjenestens eget valg; repo-skillen sier hva den gjør.
- Hviteliste: `WhiteListingServiceOption.WhiteListe` (`Fhi.Lmr.Felles.Configuration.WhiteListing`) styrer hvilke
  konfigurasjonsnøkler som vises i `/health`. Hver oppføring brukes som regex-prefiks mot nøkkelen, så å hviteliste en
  seksjon tar med alle nøklene under den. Siden endepunktet er anonymt, skal ingen hemmeligheter stå i listen. Det
  gjelder særlig `OidcClients`, `PrivateKey`, connection strings og alt annet som kan misbrukes. En hviteliste med
  `*` viser all konfigurasjon, og skal ikke brukes utenfor lokal kjøring.

## Koble en tjeneste til Kontroll

Hva som må gjøres i Kontroll for at en ny tjeneste skal vises i oversikten, er repo-spesifikt og står i skillen
`lmr-kontroll` (`references/integrasjoner.md`, avsnittet «Systemstatus»). Kort sagt:

- utgående kall konfigureres under `Apis:<Tjeneste>Service` i Kontrolls appsettings, med `BaseAddress`,
  `HttpClientName`, `OidcClientName` (`EntraIdClient` mot LMR-tjenestene) og `Scope` (`api://<api-id>/.default`),
- tjenesten må ha en tjenesteklasse og en `case` i `HealthService.GetStatusFromService` i Kontroll,
- tjenestenavnet må stå i `SystemStatusKonfigurasjon:Tjenester`, og listen er ulik per miljø,
- Kontrolls app-registrering må ha app-rolle mot tjenesten (se skillen `lmr-entraid`), og tjenesten må godta Kontrolls
  token (`DefaultScope` i `ApiTokenValidation`, se `LMR-AUTHENTICATION.md`).

Miljøfilene er `appsettings.<miljø>.json` i `Fhi.Lmr.Kontroll.Web/`.

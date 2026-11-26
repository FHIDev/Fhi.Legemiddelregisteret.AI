# Kall-graf — hvem kaller hvem

To kilder, med vilje:

| | Hva | Vedlikehold |
|---|---|---|
| [KALL-GRAF-ENTRAID.md](KALL-GRAF-ENTRAID.md) | Alle EntraID-kanter, med rolle/scope og om rolletildelingen er gitt | **Generert** fra `baseline/` med `scripts/lag-kall-graf.sh`. Kjør på nytt når en baseline endres. |
| Denne fila | Kantene som **ikke** går gjennom EntraID, og det baselinene ikke kan vise | For hånd |

Baselinene er fasiten for EntraID. Står en EntraID-kant her og ikke i den genererte fila, er det
denne fila som tar feil.

## Kanter utenfor EntraID

| Kaller | Callee | Mekanisme | Hvorfor ikke EntraID |
|---|---|---|---|
| **Helsenorge** (ekstern) | Innbyggertjenester | HelseID, DPoP | Ekstern part, kan ikke flyttes inn i FHI-tenanten. Innbyggertjenester har derfor ingen `.Api` app-registrering. |
| Kontroll.Web | Innbyggertjenester | HelseID (`fhi:lmr.innbyggertjenester/all`), client credentials | Følger av raden over. Kontroll har en egen HelseID-klient for akkurat denne kanten. |
| Institusjonsimulator, Kontroll.Web, Meldingsformidler | FhirMottak | Maskinporten (`fhi:lmr/fhirmottak.*`) | FhirMottak tar imot fra eksterne aktører via Maskinporten. |
| Grunndata | FHI Kodeverk (ekstern) | HelseID (`fhi:kodeverk.api/all`) | Ekstern FHI-tjeneste |
| Pasientregister, Apoteksimulator, Reservasjonsregister | personoppslagapi-grunndata (ekstern) | HelseID (`fhi:grunndata.personoppslagapi/*`) | Ekstern FHI-tjeneste |
| Rak.Web, Krl.Admin | Rak.Api | HelseID med brukerens token, DPoP | Rak-øya er for helsepersonell og beholder HelseID. Rak.Web og Krl.Admin **deler** HelseID-klient. |
| Alle tjenester | Logging (`POST /api/SerilogSink`) | **ingen** — endepunktet er åpent | Serilogs HTTP-sink sender ikke token. Lesing av logg (`/api/HentLogg`, `/api/Kilde`) krever EntraID. |

## Det baselinene ikke viser

- **Brukerinnlogging.** Kontroll og InternStatistikk har `.Client.Web` per miljø (Dev/Test/QA/Prod).
  Rollene kommer fra medlemskap i sikkerhetsgruppene `A-FHI-App-Lmr-<Miljø>-<Rolle>`, ikke fra en kant.
- **Delegerte rolletildelinger.** En delegert kant (type `Scope`) gis som `oauth2PermissionGrant`, som
  baselinen ikke tar med. Den genererte fila viser derfor «—» for dem. Delegerte kanter krever
  admin consent fra NHN.
- **Kanter som er erklært, men ikke brukt i koden.** Kontroll har app-rolle mot Pasientregister,
  Rekvirentregister og Administreringslager, men bruker dem bare til helsesjekk.

## Blindsoner — lest fra appsettings, ikke fra Entra

Grafen ble opprinnelig bygget ved å lese `Apis`- og `OidcClients`-seksjonene i alle repoene. Den
metoden har bommet tre ganger, og det er verdt å vite når du leter etter kallere:

- **Kall fra en UI-backend** (Kontroll.Web → Dataprodukter, Varseltjeneste, Individdatauttrekk,
  Logging) lå ikke i `Apis` med `OidcClientName`, og ble først oppdaget da tjenestene skulle migreres.
- **Krl.Admin** brukte `HelseIdWebKonfigurasjon:Apis` og var helt utenfor skannet.
- **Eksterne kallere** (Helsenorge) finnes ikke i noen appsettings hos oss.

Sjekk derfor alltid kallende kode (`IHttpClientFactory`, Refit-grensesnitt) og callee-ens egne
endepunkter når du trenger å vite hvem som kaller en tjeneste.

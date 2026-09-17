# Kodeverksynkronisering i LMR

## Faglig formål

LMR mottar utleveringsmeldinger fra apotek som inneholder kodede verdier: ATC-kode (legemiddelklassifikasjon), legemiddelform, doseringskode, hjemmelkode, refusjonskode, kommunenummer og mer. Disse kodene må valideres mot gyldige kodelister før meldingene kan prosesseres og lagres.

Kodelistene vedlikeholdes sentralt av FHI i et kodeverk-API. LMR synkroniserer disse lokalt slik at:
- Utleveringslager kan validere koder i innkommende meldinger uten å spørre FHI-APIet for hvert oppslag
- Valideringen er rask og robust mot midlertidige nettverksproblemer mot FHI
- Tjenesten alltid har en lokal kopi som er oppdatert innenfor konfigurerbart intervall

Dersom en kode mangler lokalt (klassifikasjonen er ikke synkronisert enda), returnerer valideringen `false` og meldingen kan bli avvist eller flagget.

## Oversikt

«Grunndata» betyr overalt tjenesten Fhi.Lmr.Grunndata. Konsumerende tjenester kaller aldri FHI-kodeverk
(Fhi.Kodeverk, kodeverk-api.fhi.no) direkte - det er Grunndata som synkroniserer derfra periodisk, og
konsumerende tjenester går kun mot Grunndatas REST-API.

To-stegs-flyt:

```
FHI-kodeverk-API
       │
       │ (periodisk bakgrunnsjobb, ~24t)
       ▼
Fhi.Lmr.Grunndata  ←── lagrer klassifikasjoner og koder i sin DB
       │
       │ (on-demand ved meldingsprosessering)
       ▼
Konsumerende tjeneste  ←── lagrer lokalt i egen DB, validerer koder
```

## Tjenester som bruker kodeverksynkronisering

| Tjeneste | Type | Registreringsfil | Merknad |
|---|---|---|---|
| Fhi.Lmr.Utleveringslager | Produksjon | `Fhi.Lmr.Utleveringslager.Api/Startup.cs` | Full DB-persistering, helsesjekk, OID-konfig |
| Fhi.Lmr.Apoteksimulator | Simulator | `Fhi.Lmr.Apoteksimulator/Startup.cs` | Bruker in-memory repository, ingen helsesjekk |
| Fhi.Lmr.Administreringslager | Produksjon | `Fhi.Lmr.Administreringslager.Api/Program.cs` | Periodisk bakgrunnsjobb (SynkroniserKodeverkBackgroundService); OID-er hentes fra tabellen GyldigSystemForFelt; helsesjekk uten Grunndata-kall |

De øvrige 16 LMR-mikrotjenestene bruker ikke pakken.

## Grunndata sin synkronisering fra FHI-kodeverk

`KodeverkOppdaterHostedService` kjøres periodisk (hvert 24. time ved suksess, hvert 60. minutt ved feil). Den leser en OID-liste fra konfigurasjon og itererer over hver:

- **OID ikke i lokal DB** → `PostKlassifikasjonCommand` — laster ned klassifikasjon og alle koder fra FHI-kodeverk
- **OID i lokal DB** → sjekker `SistOppdatert` fra FHI-kodeverk; ved endring kjøres `UpdateKlassifikasjonCommand`

Konfigurasjon i `appsettings.json`:

```json
"HostedService": {
  "KodeverkOppdaterHostedService": {
    "waitTimeSecondWork": "86400",
    "waitTimeSecondError": "3600",
    "OidListe": "3101 3402 7110 7170 7180 7402 7421 7427 7434 7435 7448 7452 7478 7484 7502 9051 9060 9090 99774 99775 99792 99793 99794 ..."
  }
}
```

## Pakken Fhi.Lmr.Felles.TilgangKodeverk

DI-registrering: `services.AddTilgangKodeverk(configuration)`

| Klasse / Interface | Livstid | Ansvar |
|---|---|---|
| `IGrunndataKodeverkKlient` / `GrunndataKodeverkKlient` | Singleton | Refit-klient mot Grunndata REST API (`GET /api/kodeverk/klassifikasjonInfo`) |
| `IKlassifikasjonService` / `KlassifikasjonService` | Scoped | Sync mot Grunndata, caching og persistering. `Synchronize` svelger alle feil (on-demand). `SynchronizeOrThrow` (fra 3.0.0) propagerer feil og returnerer `SynchronizeResult` (`Updated`/`Unchanged`/`NotFound`), for bakgrunnsjobber |
| `IValidKodeverkKodeCheckService` / `ValidKodeverkKodeCheckService` | Scoped | Validerer om en konkret kode (oid + verdi) er gyldig |
| `AktivGrunndataKodeverkKlient` | Singleton | Circuit-breaker: settes til `stoppedUntil = Now + 10 min` ved `GrunndataKodeverkKlientException`; leses kun i `ValidKodeverkKodeCheckService.IsValidCheck` |
| `KodeverkKodeMemoryCache` | Singleton | In-memory TTL-cache for kodeverk-koder |
| `IKodeverkRepository` | — | Interface tjenesten må implementere mot egen DB |

Utleveringslager bruker versjon 1.3.9, Administreringslager 3.0.0 (første versjon med `SynchronizeOrThrow`).
Versjonshoppet skyldes at Felles-repoet versjoneres med én felles GitVersion for alle pakkene, ikke breaking
endringer i denne pakken.

Konfigurasjonsseksjon (`GrunndataKodeverk`):

```json
"GrunndataKodeverk": {
  "AktivSynkronisering": true,
  "UpdateIntervalInMinuttes": "1440",
  "KodeverkKodeExpiration": "1440",
  "KlassifikasjonExpiration": "1440"
}
```

HTTP-klienten mot Grunndata konfigureres med `Fhi.Lmr.Authentication.ClientCredentials` (`ConfigureHttpClients`)
under `Apis:GrunndataKodeverkApi`, med `OidcClientName: EntraIdClient` - Entra ID client credentials, scope
`api://<grunndata-api-id>/.default`. Slik gjør både Utleveringslager og Administreringslager det. `HttpClientName`
må være nøyaktig `GrunndataKodeverkKlient`, fordi pakken henter klienten med `nameof(GrunndataKodeverkKlient)`.

## On-demand sync i konsumerende tjeneste

Synkronisering trigges på to måter:

```
1. Meldingsprosessering
   KodeverkKontrollTjeneste.HentKodeverk()
     → KlassifikasjonService.GetKoderByOid(oid)  ← for alle OIDer i GyldigKodeverkKoderPerFeltData
       → KlassifikasjonService.Synchronize(oid)

2. Kodeverk-validering
   ValidKodeverkKodeCheckService.IsValidCheck(oid, verdi)
     → KlassifikasjonService.Synchronize(oid)
```

### Detaljert logikk i Synchronize(oid)

Fra `KlassifikasjonService.cs` i `Fhi.Lmr.Felles.TilgangKodeverk`:

1. Sjekk in-memory cache (`KodeverkKodeMemoryCache`) — treff og `Gyldig=false` → avbryt
2. Cache-miss → hent `Klassifikasjon`-rad fra DB; sett i cache hvis funnet
3. Trigger Grunndata-kall hvis:
   - Ingen `Klassifikasjon`-rad finnes i DB (`Lastchecked == null`), **eller**
   - `DateTime.Now - Lastchecked > UpdateIntervalInMinuttes`
4. Kaller `SynchronizeWithGrunndata(oid, nedlastet)` der `nedlastet = DateTime.MinValue` hvis ingen rad finnes
5. Grunndata svarer:
   - `KlassifikasjonFunnet=true, KlassifikasjonEndret=true` → skriv til `Klassifikasjon` og `KodeverkKode`, tøm cache
   - `KlassifikasjonFunnet=true, KlassifikasjonEndret=false` → ingen endringer
   - `KlassifikasjonFunnet=false` → sett `Gyldig=false` i cache (null-objekt)
   - `GrunndataKodeverkKlientException` → `klassifikasjon=null`, circuit-breaker aktiveres i 10 min
   - Annen exception (typisk lagringsfeil i `SaveChanges`) → logges som Error, `klassifikasjon=null`, ingen circuit-breaker. I 1.3.9 ble klassifikasjonen i stedet cachet med `Lastchecked` satt, så `UpdateKodeverk` svarte `true` og neste forsøk ventet ut `UpdateIntervalInMinuttes`
6. Cachen holder alltid kopier, aldri instansen fra repository (fra 3.0.0). En feilet lagring endrer derfor ikke cachet `Nedlasted`, og neste forsøk sender det sist lagrede tidspunktet til Grunndata

**Viktig:** `Lastchecked` er ikke en DB-kolonne — den lever kun i MemoryCache. Ved omstart eller cache-utløp (etter `KlassifikasjonExpiration` minutter) vil Grunndata alltid bli kontaktet på nytt.

### To separate klokker — viktig å forstå

Det er et kritisk skille mellom to begreper som lett forveksles:

| Felt | Lagres i | Oppdateres når | Vises i helsesjekk |
|---|---|---|---|
| `Lastchecked` | MemoryCache (Singleton) | Hver gang Grunndata kalles, uansett resultat | Nei |
| `Nedlasted` | DB (`Klassifikasjon`-tabell) | Kun når Grunndata svarer `KlassifikasjonEndret=true` | Ja (`Klassifikasjon=<oid>: <dato>`) |

**Konsekvens:** Datoen i helsesjekken viser *sist gang FHI-kodeverk faktisk hadde endringer* — ikke sist gang Grunndata ble kontaktet. Selv om Grunndata kontaktes daglig, kan datoen stå stille i måneder hvis ingen koder har endret seg.

### Den 24-timers cache-syklusen

`KodeverkKodeMemoryCache` (Singleton) bruker absolutt TTL = `KlassifikasjonExpiration` minutter (standard 1440 min = 24t). Syklusen:

```
Tidspunkt T:  Cache-utløp → HentKodeverk() kaller Grunndata for ALLE OIDer
              ├── Grunndata: KlassifikasjonEndret=false → Lastchecked=T, Nedlasted uendret i DB
              └── Grunndata: KlassifikasjonEndret=true  → Lastchecked=T, Nedlasted=T i DB

Tidspunkt T+1440 min: Cache utløper igjen → ny runde
```

**Etter service-restart** (Kubernetes pod-kill): MemoryCache nullstilles. Første melding etter restart kaller Grunndata for alle OIDer. Hvis kodeverk ikke har endret seg siden forrige sync, forblir `Nedlasted` i DB uendret og helsesjekken viser fortsatt gammel dato — selv om synken faktisk kjørte.

### Tegn i loggene på at cache-utløp har trigget full sync

I Splunk/loggene vil en cache-utløp gi følgende mønster (alle OIDer synkes sekvensielt på ~10–20 sekunder):
- Et ~20 sekunders gap i meldingsprosessering der ingen meldinger ferdigstilles
- `WRN SynchronizeWithGrunndata Klassifikasjon Oid=37 ikke funnet` (OID 37 er EIK-lokal og fins ikke i Grunndata — alltid WRN)
- Helsesjekk etterpå viser alle OIDer med nesten identisk tidsstempel (sekunder fra hverandre)

### Første gang en ny OID brukes

Når ingen `Klassifikasjon`-rad finnes i DB:
- `Synchronize(oid)` kaller automatisk Grunndata med `nedlastet=DateTime.MinValue`
- Grunndata returnerer alltid `KlassifikasjonEndret=true` for `DateTime.MinValue`
- Både `Klassifikasjon`-rad og alle `KodeverkKode`-rader opprettes i samme operasjon

**En OID som mangler i `Klassifikasjon`-tabellen er derfor ikke nødvendigvis en feil** — det betyr bare at ingen melding med den OIDen har ankommet ennå. Første melding vil populere tabellen automatisk.

## Periodisk jobb i Administreringslager

Utleveringslager synkroniserer utelukkende on-demand, som beskrevet over: `Synchronize(oid)` kalles først
når en melding faktisk kontrolleres mot den OIDen. Administreringslager har i tillegg en egen periodisk
bakgrunnsjobb.

`SynkroniserKodeverkBackgroundService` i `Fhi.Lmr.Administreringslager.Api` styres av konfigurasjonsseksjonen
`SynkroniserKodeverk`:

```json
"SynkroniserKodeverk": {
  "SkalSynkroniseringstjenesteKjore": true,
  "AntallMinutterMellomKjoringer": 60
}
```

Jobben kjører ved oppstart og deretter periodisk med det konfigurerte intervallet. Hver kjøring henter
distinkte `KodeverkOid` fra tabellen `GyldigSystemForFelt` (kolonnene Feltsti, System, KodeverkOid - styrer
hvilke felt som skal valideres mot hvilket kodeverk) og kaller pakkens
`IKlassifikasjonService.SynchronizeOrThrow(oid)` (pakke 3.0.0) for hver OID, ikke `Synchronize`.
`Synchronize` svelger både feil mot Grunndata og lagringsfeil, så jobben kunne ikke rapportere om
synkroniseringen lyktes. `SynchronizeOrThrow` deler cache og throttling med `Synchronize`, men lar feil
propagere og returnerer `Updated`, `Unchanged` eller `NotFound`. Jobben teller unntak og `NotFound`
(OID-en er i bruk her, men ukjent i Grunndata) som feilet per OID; feil for én OID stopper ikke de andre.

Pakken avgjør fortsatt om Grunndata faktisk kontaktes for en gitt OID (`UpdateIntervalInMinuttes`,
`Lastchecked` i minnecache, se over), så et kort jobbintervall koster lite: de fleste kjøringene er bare
cache-oppslag.

Circuit-breakeren i pakken (`AktivGrunndataKodeverkKlient`) gjelder ikke jobben. `IsActive` leses kun i
`ValidKodeverkKodeCheckService.IsValidCheck`, altså on-demand-valideringen; verken `Synchronize` eller
`SynchronizeOrThrow` sjekker den eller `AktivSynkronisering`. `GrunndataKodeverk:AktivSynkronisering: false`
slår derfor ikke av jobben. Det gjør bare `SkalSynkroniseringstjenesteKjore: false`.

Helsesjekken `KodeverkSynkronisering` i Administreringslager leser lokal DB (`Klassifikasjon`-rader med
`Nedlasted`) og singletonen `KodeverkSynkroniseringStatus` (bakgrunnsjobben skriver `SistKjørt` og
`SisteResultat`, sjekken leser), og kaller aldri Grunndata selv. Den er Degraded hvis jobben er skrudd på
og minst ett av dette gjelder:

- en OID i `GyldigSystemForFelt` mangler tilhørende `Klassifikasjon`-rad
- `SisteResultat.AntallFeilet > 0`
- `SistKjørt` er null (jobben har aldri kjørt) eller eldre enn to ganger `AntallMinutterMellomKjoringer`

Manglende rad fanger ikke en ødelagt synkronisering, fordi radene blir liggende fra forrige vellykkede
kjøring; det er de to siste betingelsene som gjør det. `AntallFeilet` vises i sjekkens `data`.

Jobben er skrudd av i Development-miljøet, fordi endepunkttestene starter hele appen (`Program.cs`) og
ikke skal kalle Grunndata under kjøring.

## Legge til en ny OID

Følgende må gjøres for at en ny OID skal fungere i Utleveringslager:

| Steg | Hva | Hvor |
|---|---|---|
| 1 | Legg OIDen til `OidListe` i Grunndata-konfigurasjon | `Fhi.Lmr.Grunndata` `appsettings.json` |
| 2 | Legg OIDen til `GyldigKodeverkKoderPerFeltData.cs` | `Fhi.Lmr.Utleveringslager` |
| 3 | Lag EF-migrasjon som inserter i `Eik.GyldigOidForFelt` | `Fhi.Lmr.Utleveringslager` |

`Klassifikasjon`- og `KodeverkKode`-tabellene **skal ikke** populeres via migreringer — de fylles automatisk av synkmekanismen når første melding ankommer. Seed av `KodeverkKode` via migrasjon ble tidligere forsøkt (`KodeverkKodeConfiguration.cs`) og bevisst fjernet.

Tilsvarende for Administreringslager:

| Steg | Hva | Hvor |
|---|---|---|
| 1 | Legg OIDen til `OidListe` i Grunndata-konfigurasjon | `Fhi.Lmr.Grunndata` `appsettings.json` |
| 2 | Legg en ny seed-rad til (`HasData`) i `GyldigSystemForFeltConfiguration` | `Fhi.Lmr.Administreringslager.Infrastruktur` |
| 3 | Lag EF-migrasjon som inserter raden i `GyldigSystemForFelt` | `Fhi.Lmr.Administreringslager.Infrastruktur` |

Heller ikke her skal `Klassifikasjon`- og `KodeverkKode`-tabellene seedes via migrasjon - de fylles av
synkroniseringsjobben (eller on-demand-sync ved meldingsprosessering) etter at OIDen er lagt til.

## OID-konfigurasjon

OIDer konfigureres på to steder:

**1. Grunndata `appsettings.json` — `OidListe`**
Hvilke OIDer Grunndata holder oppdatert fra FHI-kodeverk. Alle OIDer som noen tjeneste trenger, må stå her.

**2. `GyldigKodeverkKoderPerFeltData.cs` i tjenesten**
Definerer hvilke OIDer tjenesten faktisk validerer mot, og til hvilke felt. Administreringslager har ingen
slik fil; der henter bakgrunnsjobben OID-ene fra tabellen `GyldigSystemForFelt` (Feltsti, System, KodeverkOid),
seedet via `HasData` i `GyldigSystemForFeltConfiguration`. I Utleveringslager er dette delt i tre grupper:

| Gruppe | Eksempel-OIDer | Beskrivelse |
|---|---|---|
| Kodeverk | 7180 (ATC), 7448 (Legemiddelform), 7478 (Dosering), 7427 (Hjemmelkode) | Direkte fra meldingsfelter |
| Andre kodeverk | 3101 (Kjønn), 3402 (Kommunenummer), 9060 (Profesjon), 9090 (Styrke) | Støtte-kodeverk |
| Lokale kodeverk | 99774 (DokumentStatus), 99775 (Dyreart), 99792 (GeneriskBytteReservasjon), 99794 (FarmasøytiskTjenesteType) | LMR-interne koder |

## Helsesjekken GrunndataSynkronisering

Registreres i `HealtCheckBuildExtenstions.AddSystemStatusEik()`. Kjøres ved `/health`-endepunktet og sjekker følgende i rekkefølge:

| Sjekk | Degraded hvis |
|---|---|
| Hent alle `Klassifikasjon`-rader fra lokal DB | — (kun diagnostikkdata) |
| `GetKlassifikasjonInfo(3101)` mot Grunndata API | Klassifikasjon 3101 ikke funnet, eller exception |
| `AktivGrunndataKodeverkKlient.IsActive` | `stoppedUntil` er i fremtiden (circuit-breaker aktiv) |
| `IsValidCheck(3101, "1")` | Koden finnes ikke i lokal DB |
| `GrunndataKodeverkOption.AktivSynkronisering` | `false` i konfigurasjon |

Output-feltet `Klassifikasjon=<oid>: <dato>` viser `Nedlasted` fra DB — tidspunktet da FHI-kodeverk **sist hadde endringer** for den OIDen. Datoen kan stå stille i måneder selv om sync kjøres daglig, fordi `Nedlasted` kun oppdateres ved `KlassifikasjonEndret=true`. **Manglende OID i listen betyr at synkronisering aldri er blitt trigget, eller at Grunndata returnerte "ikke funnet" da det ble forsøkt.**

## Feilsøking

Logg-strenger å søke etter (i Utleveringslager sine logger):

| Logg-streng | Betyr |
|---|---|
| `SynchronizeWithGrunndata Oid=<oid>` | Sync ble forsøkt |
| `SynchronizeWithGrunndata (ingen endringer) Oid=<oid>` | Grunndata hadde den, men ingen endringer |
| `Klassifikasjon Oid=<oid> ikke funnet` | Grunndata kjenner ikke til OIDen |
| `GrunndataKodeverkKlientException` | Nettverksfeil mot Grunndata (circuit-breaker aktiveres) |
| `OppdaterRepoistory  <oid>` | Sync lyktes — data skrevet til DB |

Ingen treff på `SynchronizeWithGrunndata Oid=<oid>` betyr at ingen melding har trigget oppslag mot den OIDen ennå — dette er normalt for nye OIDer og er ikke en feil.

Administreringslager logger i tillegg fra bakgrunnsjobben (pakkens strenger over gjelder også der):

| Logg-streng | Nivå | Betyr |
|---|---|---|
| `Kodeverksynkronisering fullført for <n> OID-er, <m> feilet` | Information | Én kjøring er ferdig; `m > 0` gir Degraded i helsesjekken |
| `Kodeverksynkronisering feilet for OID <oid>` | Warning | `SynchronizeOrThrow` kastet, unntaket ligger i loggen |
| `Kodeverk for OID <oid> finnes ikke i Grunndata` | Warning | Grunndata svarte «ikke funnet»; OIDen mangler i Grunndatas `OidListe` |

### Manuell trigger

**Utleveringslager** — eksponeres ikke eksternt; krever intern servertilgang:
```
GET /api/eik/ValidKodeverkKodeCheck/UpdateKodeKodeverk?oid=<oid>
```

**Kontroll** (`/grunndata/kodeverk`) har en Synkroniser-knapp, men den trigges kun Grunndatas bakgrunnsjobb mot FHI-kodeverk — ikke Utleveringslagers on-demand sync. Kontroll har ingen funksjonalitet for å trigge Utleveringslager direkte.

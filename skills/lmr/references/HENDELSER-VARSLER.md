# Hendelser, varsler og handlinger

Mekanisme for å varsle brukere (fag/utviklere) når noe skjer i LMR som krever manuell oppfølging. Kjeden går: **Hendelse** (kildetjeneste) → **Varsel** (Varseltjeneste) → visning og **Handling** (Kontroll-siden).

## Hendelser (i kildetjenestene)

Når noe går galt som brukerne må ta stilling til, lagrer kildetjenesten en `Hendelse`-rad i sin egen database. Kildetjenester med hendelser: Meldingsmottak, Pasientregister, Rekvirentregister, Utleveringslager (m.fl.).

Hendelse-entiteten (likt mønster i alle kildene, eksempel fra Rekvirentregister):

- `HendelseId` (Guid), `Hendelsetype` (string, f.eks. `"MeldingsprosesseringFeilet"`), `HendelseOppstattTidspunkt`, `Detaljer`, `Kilde` (hardkodet tjenestenavn, f.eks. `"Rekvirentregister"`), `TidspunktOverført` (null til Varseltjenesten har hentet den)
- I tillegg et kildespesifikt objekt med nøkkeldata, f.eks. `RekvirentregisterHendelse { MeldingsId }`

Hver kildetjeneste eksponerer en `HendelseController` med likt API:

- `GET api/Hendelse/{hendelsetype}` — returnerer uoverførte hendelser av typen (maks 100)
- `POST api/Hendelse/MerkSomOverfort` — merker hendelser som overført (`TidspunktOverført` settes)

### Hendelsetypen MeldingsprosesseringFeilet

Opprettes når en melding går til `Status.Stoppet`, dvs. når retry-forsøkene er brukt opp (styrt av `ProvIgjenIntervallerIMinutterListe`) eller meldingen stoppes eksplisitt. I Rekvirentregister gjelder dette både `Rekvirentmelding` (apotekflyt) og `RekvirentmeldingFraInstitusjonsmelding` (FHIR-/institusjonsflyt) — begge oppretter hendelse i `LagreProsesseringSomStoppet`, `LagreProsesseringSomFeilet` og `SettMeldingSomUnderProsseseringOgHentMelding` (når status allerede er/blir Stoppet).

Kjent svakhet: `Detaljer` settes til `"Feilmelding ikke tilgjengelig."` fordi feilmeldingen ikke er tilgjengelig der hendelsen opprettes (todo i koden, må leses fra logg).

## Varsler (Fhi.Lmr.Varseltjeneste)

Varseltjenesten poller kildetjenestene periodisk (hosted service per varseltype):

1. Henter hendelser via tjenestespesifikke klienter (`RekvirentregisterKlient`, `MeldingsmottakKlient`, `PasientregisterKlient`, `UtleveringslagerKlient`). Hvilke kilder som hentes styres av options-flagg i appsettings, f.eks. `HentFraRekvirentregister: true`.
2. Validerer hendelsen med FluentValidation-validator per varseltype (f.eks. `MeldingprosesseringFeiletHendelseValidator` krever riktig hendelsetype, kjent kilde og `MeldingsId` i det kildespesifikke objektet).
3. `VarselBehandler` grupperer hendelsen inn i et eksisterende åpent varsel (via en `IVarseltypeQuery`) eller oppretter nytt (via en `IVarselFactory`).
4. Merker hendelsen som overført i kilden.

For `MeldingprosesseringFeiletVarsel` grupperes hendelser per `Kilde` — dvs. ett åpent varsel per kildetjeneste, uavhengig av meldingstype. Feilede institusjonsmeldinger og apotekmeldinger i Rekvirentregisteret havner derfor i samme varsel.

Nye varseltyper krever: validator + factory + query + tjeneste i Varseltjenesten, samt en Angular-komponent i Kontroll.

## Visning og handlinger (Fhi.Lmr.Kontroll)

Varsler vises på Kontroll-siden i `ClientApp/src/app/varsel-feature/`. Hver varseltype har sin egen komponent som velges i `varsel.component.ts` basert på `varseltype`/`kilde`:

- `meldingprosesseringfeilet`, `ukjent-kodeverdi`, `ugyldig-melding`, `ukjent-apotek`, `dekrypteringsfeil`, m.fl.

Brukeren kan utføre en handling på et åpent varsel (med begrunnelse, via `app-varsel-modal`). Handlingen går Kontroll → `VarselController` → Varseltjenesten, som har en command handler per handling.

### Handlingen «Reprosesser meldinger»

For `MeldingprosesseringFeiletVarsel`: `ReprosesserFeiledeMeldingerCommandHandler` i Varseltjenesten

1. registrerer handlingen på varselet (`Handling.Reprosesser`),
2. kaller kildens API `POST Handlinger/reprosesserstoppedemeldinger` (switch på `varsel.Kilde`),
3. lukker varselet.

I kilden (f.eks. Rekvirentregister) finner handleren alle meldinger med `Status.Stoppet` og setter dem tilbake til `KlarForProsessering` (nullstiller `AntallGangerPrøvd`), slik at bakgrunnsprosesseringen plukker dem opp på nytt. I Rekvirentregister reprosesseres både `Rekvirentmelding` og `RekvirentmeldingFraInstitusjonsmelding`.

## Meldingsstatuser (retry-logikk i kildene)

Meldinger som prosesseres i bakgrunnen følger en felles statusmodell (`RekvirentmeldingBase` o.l.):

- `KlarForProsessering` → `UnderProsessering` → `FerdigBehandlet`
- Ved feil: `AvbruttProsessering` (prøves igjen etter intervall) til forsøkene er brukt opp → `Stoppet` (+ hendelse opprettes)
- «Reprosesser meldinger» setter `Stoppet` → `KlarForProsessering`

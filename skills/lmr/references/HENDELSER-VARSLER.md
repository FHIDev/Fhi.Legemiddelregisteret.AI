# Hendelser, varsler og handlinger

Mekanisme for å varsle brukere (fag/utviklere) når noe skjer i LMR som krever manuell oppfølging. Kjeden går: **Hendelse** (kildetjeneste) → **Varsel** (Varseltjeneste) → visning og **Handling** (Kontroll-siden).

## Hendelser (i kildetjenestene)

Når noe går galt som brukerne må ta stilling til, lagrer kildetjenesten en `Hendelse`-rad i sin egen database. Kildetjenester med hendelser: Meldingsmottak, Pasientregister, Rekvirentregister, Utleveringslager, Administreringslager (m.fl.).

Hendelse-entiteten (likt mønster i alle kildene, eksempel fra Rekvirentregister):

- `HendelseId` (Guid), `Hendelsetype` (string, f.eks. `"MeldingsprosesseringFeilet"`), `HendelseOppstattTidspunkt`, `Detaljer`, `Kilde` (hardkodet tjenestenavn, f.eks. `"Rekvirentregister"`), `TidspunktOverført` (null til Varseltjenesten har hentet den)
- I tillegg et kildespesifikt objekt med nøkkeldata, f.eks. `RekvirentregisterHendelse { MeldingsId }`

Hver kildetjeneste eksponerer endepunkter for å hente uoverførte hendelser av en type (maks 100, 204 når det ikke finnes noen) og for å merke dem som overført (`TidspunktOverført` settes). Rutene er ikke likt navngitt på tvers av kildene, og klienten i Varseltjenesten (`Klienter/<Kilde>Klient.cs`) er fasit:

| Kilde | Hent (`GET`) | Merk som overført (`POST`) | `BaseAddress` slutter på |
|---|---|---|---|
| Meldingsmottak, Utleveringslager | `Hendelser/{hendelsetype}` | `Hendelser/MerkSomOverfort` | `/api/` |
| Pasientregister, Rekvirentregister | `Hendelse/{hendelsetype}` | `Hendelse/MerkSomOverfort` | `/api/` |
| Vareregister (Grunndata) | `Vareregister/Hendelser/{hendelsetype}` | `Vareregister/Hendelser/MerkSomOverfort` | `/api/` |
| Administreringslager | `Hendelser/{hendelsetype}` | `Hendelser/MerkSomOverfort` | `/administreringslager/` (minimal API, rutene ligger på rot) |

Stiene er relative, så `BaseAddress` må ende på skråstrek. Uten den erstatter `Uri`-sammenslåingen siste segment i adressen.

### Hendelsetypen MeldingsprosesseringFeilet

Opprettes når en melding går til `Status.Stoppet`, dvs. når retry-forsøkene er brukt opp (styrt av `ProvIgjenIntervallerIMinutterListe`) eller meldingen stoppes eksplisitt. I Rekvirentregister gjelder dette både `Rekvirentmelding` (apotekflyt) og `RekvirentmeldingFraInstitusjonsmelding` (FHIR-/institusjonsflyt) — begge oppretter hendelse i `LagreProsesseringSomStoppet`, `LagreProsesseringSomFeilet` og `SettMeldingSomUnderProsseseringOgHentMelding` (når status allerede er/blir Stoppet).

`Detaljer` fylles ulikt i kildene: Utleveringslager setter `"Feilmelding ikke tilgjengelig."` (feilmeldingen må leses fra logg), Rekvirentregister tar med meldingstypen og feilmeldingen (så apotek- og institusjonsflyten kan skilles i varselet), og Meldingsmottak setter feilmeldingen (eller `Ukjent apotek: <konsesjonsnummer>`). Klienten og kilden er fasit.

Administreringslager fyller `Detaljer` med en sanert feiltekst fordi feltet lagres i Varseltjenesten og vises på kontrollsiden. Detaljer (hva saneringen gjør og ikke garanterer) står i repo-skillen `lmr-administreringslager` (`references/prosessering-drift.md`). Regelen for alle kilder: egne feilmeldinger skal ikke interpolere meldingsinnhold.

## Varsler (Fhi.Lmr.Varseltjeneste)

Varseltjenesten poller kildetjenestene periodisk (hosted service per varseltype):

1. Henter hendelser via tjenestespesifikke klienter (`RekvirentregisterKlient`, `MeldingsmottakKlient`, `PasientregisterKlient`, `UtleveringslagerKlient`, `AdministreringslagerKlient`). Hvilke kilder som hentes styres av options-flagg i appsettings, f.eks. `HentFraRekvirentregister: true`.
2. Validerer hendelsen med FluentValidation-validator per varseltype (f.eks. `MeldingprosesseringFeiletHendelseValidator` krever riktig hendelsetype, kjent kilde og `MeldingsId` i det kildespesifikke objektet).
3. `VarselBehandler` grupperer hendelsen inn i et eksisterende åpent varsel (via en `IVarseltypeQuery`) eller oppretter nytt (via en `IVarselFactory`).
4. Merker hendelsen som overført i kilden.

For `MeldingprosesseringFeiletVarsel` grupperes hendelser per `Kilde` — dvs. ett åpent varsel per kildetjeneste, uavhengig av meldingstype. Feilede institusjonsmeldinger og apotekmeldinger i Rekvirentregisteret havner derfor i samme varsel.

Nye varseltyper krever: validator + factory + query + tjeneste i Varseltjenesten, samt en Angular-komponent i Kontroll. En ny kilde på et eksisterende varsel krever derimot ingen ny varseltype eller komponent, men en klient, en konstant i `Kilder`, kilden i validatoren, en kopi av den kildespesifikke hendelsestypen (med migrasjon), et options-flagg og en `case` i Kontroll (se under).

## Visning og handlinger (Fhi.Lmr.Kontroll)

Varsler vises på Kontroll-siden i `ClientApp/src/app/varsel-feature/`. Hver varseltype har sin egen komponent som velges i `varsel.component.html` (`@switch` på varseltype) basert på `varseltype`/`kilde`:

- `meldingprosesseringfeilet`, `ukjent-kodeverdi`, `ugyldig-melding`, `ukjent-apotek`, `dekrypteringsfeil`, m.fl.

`meldingprosesseringfeilet`-komponenten deles av alle kildene til `MeldingprosesseringFeiletVarsel`. `hentMeldingsId` (i `meldingprosesseringfeilet.component.ts`) har én `case` per kilde og kaster på ukjent kilde, så en ny kilde krever en ny `case` der og et nytt felt på `IHendelse` i `varsel.interface.ts`. Ellers krasjer detaljvisningen i det første varselet fra kilden dukker opp.

Brukeren kan utføre en handling på et åpent varsel (med begrunnelse, via `app-varsel-modal`). Handlingen går Kontroll → `VarselController` → Varseltjenesten, som har en command handler per handling.

### Handlingen «Reprosesser meldinger»

For `MeldingprosesseringFeiletVarsel`: `ReprosesserFeiledeMeldingerCommandHandler` i Varseltjenesten

1. registrerer handlingen på varselet (`Handling.Reprosesser`),
2. kaller kildens API `POST Handlinger/reprosesserstoppedemeldinger` (switch på `varsel.Kilde`),
3. lukker varselet.

I kilden (f.eks. Rekvirentregister) finner handleren alle meldinger med `Status.Stoppet` og setter dem tilbake til `KlarForProsessering` (nullstiller `AntallGangerPrøvd`), slik at bakgrunnsprosesseringen plukker dem opp på nytt. I Rekvirentregister reprosesseres både `Rekvirentmelding` og `RekvirentmeldingFraInstitusjonsmelding`. Administreringslager gjør det samme for sine stoppede meldinger (se repo-skillen `lmr-administreringslager`).

## Meldingsstatuser (retry-logikk i kildene)

Meldinger som prosesseres i bakgrunnen følger en felles statusmodell (`RekvirentmeldingBase` o.l.):

- `KlarForProsessering` → `UnderProsessering` → `FerdigBehandlet`
- Ved feil: `AvbruttProsessering` (prøves igjen etter intervall) til forsøkene er brukt opp → `Stoppet` (+ hendelse opprettes)
- «Reprosesser meldinger» setter `Stoppet` → `KlarForProsessering`

Administreringslager har en egen statusmodell (uten `AvbruttProsessering`), som er beskrevet i repo-skillen `lmr-administreringslager`.

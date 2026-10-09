# Meldingskontrakter — institusjonsflyt

Dokumenterer alle meldingstyper i pipelinen fra FhirMottak til Administreringslager, inkludert kontraktene fra Pasientregister og Rekvirentregister tilbake til Administreringslager.

Se `MELDINGSSPLITTING-INSTITUSJON-FHIR.md` og `MELDINGSSPLITTING-BAERUM.md` for detaljer om hvordan splittingen produserer disse meldingene. Hvordan Administreringslager lagrer og prosesserer dem, står i repo-skillen lmr-administreringslager.

## Innhold

- Fra Meldingsmottak til registre og lager
- Fra registre til Administreringslager
- Transport — KryptertMelding-wrapper
- Hva Administreringslager venter på (kontrakt)
- Databasetabeller i Pasientregister og Rekvirentregister
- Nøkkelfilstier

---

## Fra Meldingsmottak til registre og lager

### `PasientmeldingFraInstitusjonsmelding`

Sendes fra Meldingsmottak til Pasientregister.

```
PasientmeldingFraInstitusjonsmelding
├── MeldingsId: Guid
├── Pasientadministreringer: List<Pasientadministrering>
└── Kildeformat: string               ← "FhirBundle" eller "BærumCsv" (konstantene KildeformatFhirBundle og KildeformatBærumCsv)

Pasientadministrering
├── NorskIdentitetsnummer: string    ← FNR eller DNR
├── Administeringsdato: DateTime?
├── Administreringsreferanse: string ← kobling til én bestemt administrering i bundlen/CSV-en
└── Identitetsnummertype: string?    ← "FNR" eller "DNR"; null for Bærum CSV
```

**Administreringsreferanse-format:**
- FHIR: `entry.FullUrl` fra `MedicationAdministration`-entry, f.eks. `"urn:uuid:abc123"`. Fallback til `"MedicationAdministration/{medAdmin.Id}"` hvis FullUrl mangler.
- Bærum CSV: radnummer som streng, f.eks. `"1"`, `"2"`, `"3"`

Referansen kobler pasientmeldingen til den tilhørende administreringen — Administreringslager bruker den for å slå opp PasientId.

### `RekvirentmeldingFraInstitusjonsmelding`

Sendes fra Meldingsmottak til Rekvirentregister. Finnes **ikke** for Bærum CSV (CSV-formatet har ingen HPR-nummer).

```
RekvirentmeldingFraInstitusjonsmelding
├── MeldingsId: Guid
└── Rekvirenter: List<RekvirentFraInstitusjonsmelding>

RekvirentFraInstitusjonsmelding
├── HprNummer: int
└── Administreringsreferanse: string ← entry.FullUrl fra MedicationAdministration-entry
```

FHIR-splitteren lager alltid en rekvirentmelding, også når bundlen ikke har noen `Practitioner` med gyldig HPR-nummer. Da er `Rekvirenter` en tom liste (`FhirBundleInstitusjonsmeldingSplitter.cs` i Meldingsmottak).

### `AdministreringsmeldingFhirBundle`

Sendes fra Meldingsmottak til Administreringslager (via Meldingsformidler). Inneholder **ingen** ekte identiteter — `Identifier.Value` for pasienter og rekvirenter er maskert til nuller.

```
AdministreringsmeldingFhirBundle
├── MeldingsId: Guid
├── GenerertHosAvsender: DateTime
├── MottattFhirMottak: DateTime
├── AvsenderOrgnr: string
├── Meldingsversjonsnummer: string
└── Bundelen: string                 ← serialisert FHIR Bundle (JSON eller XML) med maskerte identiteter
```

### `AdministreringsmeldingBærumCsv`

Sendes fra Meldingsmottak til Administreringslager for Bærum-meldinger.

```
AdministreringsmeldingBærumCsv
├── MeldingsId: Guid
├── GenerertHosAvsender: DateTime
├── MottattFhirMottak: DateTime
├── AvsenderOrgnr: string
├── Meldingsversjonsnummer: string
└── Administreringer: List<Administrering>

Administrering  (DTO — ikke forveksle med Administrering-entiteten i Administreringslager)
├── Administreringsreferanse: string ← radnummer som streng, f.eks. "1", "2", "3"
└── CsvElement: string               ← semikolonseparert CSV-rad med personnummer maskert
```

---

## Fra registre til Administreringslager

Etter at Pasientregister og Rekvirentregister har prosessert sine meldinger og tildelt interne ID-er, sender de lister tilbake via Meldingsformidler.

### `PasientlisteFhir`

Returneres fra Pasientregister til Administreringslager.

```
PasientlisteFhir
├── MeldingsId: Guid
└── ReferanserTilPasientIder: List<ReferanseTilPasientId>

ReferanseTilPasientId
├── Administreringsreferanse: string ← samme referanse som i Pasientmeldingen
│                                      FHIR: entry.FullUrl | Bærum: radnummer
└── PasientId: int                   ← tildelt av Pasientregister
```

### `RekvirentlisteFhir`

Returneres fra Rekvirentregister til Administreringslager. Sendes **ikke** for Bærum CSV.

```
RekvirentlisteFhir
├── MeldingsId: Guid
└── ReferanserTilRekvirentIder: List<ReferanseTilRekvirentId>

ReferanseTilRekvirentId
├── Administreringsreferanse: string ← entry.FullUrl fra MedicationAdministration-entry
└── RekvirentId: int                 ← tildelt av Rekvirentregister
```

---

## Transport — `KryptertMelding`-wrapper

Alle meldinger pakkes i `KryptertMelding` av Meldingsformidler før transport. `Meldingstype`-feltet brukes av mottakerne for å velge riktig deserialiseringslogikk.

Relevante konstanter for institusjonsflyten (definert i `Fhi.Lmr.Felles.Meldinger/KryptertMelding/KryptertMelding.cs`):

| Konstant | Verdi |
|---|---|
| `KryptertMelding.MeldingstypePasientmeldingFraInstitusjonsmelding` | `"PasientmeldingFraInstitusjonsmelding"` |
| `KryptertMelding.MeldingstypeRekvirentmeldingFraInstitusjonsmelding` | `"RekvirentmeldingFraInstitusjonsmelding"` |
| `KryptertMelding.MeldingstypeAdministeringsmeldingFhirBundle` | `"AdministeringsmeldingFhirBundle"` |
| `KryptertMelding.MeldingstypeAdministeringsmeldingBærumCsv` | `"AdministeringsmeldingBærumCsv"` |

Verdiene er en del av transportformatet mellom tjenestene. Å endre dem krever koordinert endring i alle tjenestene og tilsvarende håndtering av meldinger som allerede ligger i kø.

---

## Hva Administreringslager venter på (kontrakt)

Administreringslager prosesserer ikke før alle delene er mottatt: for FHIR administreringsmeldingen, pasientlisten og
rekvirentlisten, for Bærum administreringsmeldingen og pasientlisten (ingen rekvirentliste). Koblingen mellom delene går
bare via `Administreringsreferanse`: listene slår opp `PasientId` og `RekvirentId` per referanse, og
`Subject.Reference` i bundlen brukes ikke som oppslagsnøkkel. Administreringslager lagrer referansen på
administreringen (`Administrering`-entiteten, tabellen `dbo.Administreringer`).

Mellomlagring, assembly, statusmodell, feilhåndtering og feilteksten som sendes som hendelse til Varseltjenesten, er
beskrevet i repo-skillen `lmr-administreringslager` (`references/prosessering-drift.md`).

---
## Databasetabeller i Pasientregister og Rekvirentregister

| Tabell | PK | Beskrivelse |
|---|---|---|
| `dbo.PasientmeldingerFraInstitusjonsmelding` | `MeldingsId` | Mottatte pasientmeldinger (staging) |
| `Kryptert.PasientadministreringTilBehandling` | `(MeldingsId, Administreringsreferanse)` | Én rad per administrering fra meldingen |
| `dbo.RekvirentmeldingerFraInstitusjonsmelding` | `MeldingsId` | Mottatte rekvirentmeldinger (staging) |
| `Kryptert.RekvirentadministreringTilBehandling` | `(MeldingsId, Administreringsreferanse)` | Én rad per administrering fra meldingen |

---

## Nøkkelfilstier

```
Felles meldingstyper (Fhi.Lmr.Felles.Meldinger/):
  PasientmeldingFraInstitusjonsmelding/PasientmeldingFraInstitusjonsmelding.cs
  PasientmeldingFraInstitusjonsmelding/Pasientadministrering.cs
  PasientmeldingFraInstitusjonsmelding/PasientlisteFhir.cs
  PasientmeldingFraInstitusjonsmelding/ReferanseTilPasientId.cs
  RekvirentmeldingFraInstitusjonsmelding/RekvirentmeldingFraInstitusjonsmelding.cs
  RekvirentmeldingFraInstitusjonsmelding/RekvirentFraInstitusjonsmelding.cs
  RekvirentmeldingFraInstitusjonsmelding/RekvirentlisteFhir.cs
  RekvirentmeldingFraInstitusjonsmelding/ReferanseTilRekvirentId.cs
  Administreringsmelding/AdministreringsmeldingFhirBundle.cs
  Administreringsmelding/AdministreringsmeldingBærumCsv.cs
  Administreringsmelding/Administrering.cs
  KryptertMelding/KryptertMelding.cs

Pasientregister:
  Fhi.Lmr.Pasientregister.Api/Queries/FhirPasientliste/FhirPasientlisteQuery.cs
  Fhi.Lmr.Pasientregister.Api/Aggregates/Pasientadministrering/Pasientadministrering.cs

Rekvirentregister:
  Fhi.Lmr.Rekvirentregister.Api/Queries/HentFhirRekvirentlisteQueryHandler.cs
  Fhi.Lmr.Rekvirentregister.Api/Domene/Rekvirentadministrering.cs

Administreringslager:
  Fhi.Lmr.Administreringslager.Applikasjon/Prosessering/ProsesserAdministreringsmeldingHandler.cs
  Fhi.Lmr.Administreringslager.Applikasjon/FhirBundle/FhirBundleLagringsTjeneste.cs
  Fhi.Lmr.Administreringslager.Applikasjon/Bærum/BærumCsvLagringsTjeneste.cs
  Fhi.Lmr.Administreringslager.Domene/Administrering.cs
  Fhi.Lmr.Administreringslager.Domene/Fhir/AdministreringFhir.cs
  Fhi.Lmr.Administreringslager.Domene/PasientlisteTilBehandling.cs
  Fhi.Lmr.Administreringslager.Domene/RekvirentlisteTilBehandling.cs
```

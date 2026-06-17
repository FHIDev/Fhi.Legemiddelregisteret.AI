# Meldingskontrakter — institusjonsflyt

Dokumenterer alle meldingstyper i pipelinen fra FhirMottak til Administreringslager, inkludert kontraktene fra Pasientregister og Rekvirentregister tilbake til Administreringslager.

Se [MELDINGSSPLITTING-INSTITUSJON-FHIR.md](./MELDINGSSPLITTING-INSTITUSJON-FHIR.md) og [MELDINGSSPLITTING-BAERUM.md](./MELDINGSSPLITTING-BAERUM.md) for detaljer om hvordan splittingen produserer disse meldingene.

---

## Fra Meldingsmottak til registre og lager

### `PasientmeldingFraInstitusjonsmelding`

Sendes fra Meldingsmottak til Pasientregister.

```
PasientmeldingFraInstitusjonsmelding
├── MeldingsId: Guid
└── Pasientadministreringer: List<Pasientadministrering>

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

Produseres kun hvis FHIR-bundlen inneholder `Practitioner`-ressurser med gyldig HPR-nummer.

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

Relevante konstanter for institusjonsflyten:

| Konstant | Verdi |
|---|---|
| `KryptertMelding.MeldingstypePasientmeldingFraFhirMottak` | `"PasientmeldingFraFhirMottak"` |
| `KryptertMelding.MeldingstypeRekvirentmeldingFraFhirMottak` | `"RekvirentmeldingFraFhirMottak"` |
| `KryptertMelding.AdministeringsmeldingFhirBundle` | `"AdministeringsmeldingFhirBundle"` |
| `KryptertMelding.AdministeringsmeldingBærumCsv` | `"AdministeringsmeldingBærumCsv"` |

Merk: konstantverdiene (strengene) er ikke endret — de er del av det persisterte transportformatet og kan ikke endres uten migrering av meldinger i kø.

---

## Mellomlagring i Administreringslager

Administreringslager mellomlagrer alle deler til prosesseringen kan starte. TilBehandling-radene fjernes atomisk når meldingen er ferdigbehandlet.

| Tabell | PK | Innhold | Gjelder |
|---|---|---|---|
| `PasientlisteTilBehandling` | `MeldingsId` | JSON: `List<ReferanseTilPasientId>` | FHIR + Bærum |
| `RekvirentlisteTilBehandling` | `MeldingsId` | JSON: `List<ReferanseTilRekvirentId>` | Kun FHIR |
| `Kryptert.AdministreringsmeldingFhirBundleTilBehandling` | `MeldingsId` | Bundle-JSON, komprimert+kryptert | Kun FHIR |
| `Kryptert.AdministreringsmeldingBærumCsvTilBehandling` | `MeldingsId` | CSV-JSON, komprimert+kryptert | Kun Bærum |

**Forutsetninger for prosessering:**
- FHIR: alle tre TilBehandling-rader mottatt
- Bærum: to TilBehandling-rader (ingen rekvirentliste)

---

## Assembly i Administreringslager

`ProsesserAdministreringsmeldingHandler` (bakgrunnstjeneste) kobler de tre delene.

**1. Bygg oppslagsdicts fra listene:**
```csharp
// FHIR-eksempel — nøkkel er MedAdmin-referansen (entry.FullUrl)
pasientDict["urn:uuid:abc123"] = 12345   // PasientId
rekvirentDict["urn:uuid:def456"] = 54321 // RekvirentId

// Bærum-eksempel — nøkkel er radnummer (loop-teller)
pasientDict["1"] = 12345
// (ingen rekvirentDict for Bærum)
```

**2. Kobling per MedicationAdministration (FHIR):**
- Administreringsreferansen (`entry.FullUrl`) → oppslag i `pasientDict` → `PasientIdFraPasientregisteret`
- Administreringsreferansen → oppslag i `rekvirentDict` → `RekvirentIdFraRekvirentregisteret`

Merk: I motsetning til tidligere brukes ikke `MedicationAdministration.Subject.Reference` (Patient-referansen) som oppslagsnøkkel — alle oppslag går via `Administreringsreferanse`.

**3. Lagrede felt i `Administrering`-entiteten (`dbo.Administreringer`):**

| Felt | Verdi | Formål |
|---|---|---|
| `PasientIdFraPasientregisteret` | `12345` | Anonym ID for videre bruk |
| `RekvirentIdFraRekvirentregisteret` | `54321` | Anonym ID (null for Bærum) |

**4. Lagrede felt i `AdministreringFhir`-entiteten (`fhir.AdministreringerFhir`):**

| Felt | Verdi | Formål |
|---|---|---|
| `Administreringsreferanse` | `"urn:uuid:abc123"` | Sporbarhet — kobling til original MedAdmin-entry |

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

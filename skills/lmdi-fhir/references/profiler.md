# LMDI-profiler — detaljert oppslag

Kilde: `LMDI/input/fsh/profiles/*.fsh`. Canonical-mønster: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/<id>`.

Profilene som har `^status` i FSH er markert `#draft`; IG-en som helhet er `active`.

## Oversikt

| FSH-navn (Title) | Id | Parent | Fil |
|---|---|---|---|
| `Pasient` | `lmdi-patient` | `NoBasisPatient` | `profiles/lmdi-Patient.fsh` |
| `Helsepersonell` | `lmdi-practitioner` | `NoBasisPractitioner` | `profiles/lmdi-Practitioner.fsh` |
| `Organisasjon` | `lmdi-organization` | `NoBasisOrganization` | `profiles/lmdi-Organization.fsh` |
| `Episode` | `lmdi-encounter` | `Encounter` | `profiles/lmdi-Encounter.fsh` |
| `Diagnose` | `lmdi-condition` | `Condition` | `profiles/lmdi-Condition.fsh` |
| `Legemiddel` | `lmdi-medication` | `Medication` | `profiles/lmdi-Medication.fsh` |
| `Virkestoff` | `lmdi-substance` | `NoBasisSubstance` | `profiles/lmdi-Substance.fsh` |
| `Legemiddelrekvirering` | `lmdi-medicationrequest` | `MedicationRequest` | `profiles/lmdi-MedicationRequest.fsh` |
| `Legemiddeladministrering` | `lmdi-medicationadministration` | `MedicationAdministration` | `profiles/lmdi-MedicationAdministration.fsh` |
| `LegemiddelregisterBundle` | `lmdi-bundle` | `Bundle` | `profiles/LegemiddelregisterBundle.fsh` |

> `NoBasisPractitioner` brukes som parent i `lmdi-Practitioner.fsh` uten eksplisitt `Alias:`-oppslag i `aliases.fsh`. Verifisert mot generert artefakt: `StructureDefinition-lmdi-practitioner.json` har `baseDefinition = http://hl7.no/fhir/StructureDefinition/no-basis-Practitioner` — SUSHI resolver via no-basis-pakken.

## Designprinsipper på tvers av profilene

- Strenge `only Reference(...)`-bindinger gjør LMDI-ressursene tett koblet; andre Patient-/Organization-profiler kan **ikke** brukes i stedet uten valideringsfeil.
- Mange `0..0`-deaktiveringer reduserer PII-eksponering (f.eks. `Patient.name`, `telecom`, `photo`, `address.line`, `address.postalCode`).
- Kommunenummer (OID 3402) og bydel (OID 3403) erstatter adresselinje/postnummer som geografisk presisjonsnivå.

---

## Pasient (`lmdi-patient`)
**Parent**: `NoBasisPatient` (`http://hl7.no/fhir/StructureDefinition/no-basis-Patient`) — no-basis 2.2.0
**Fil**: `profiles/lmdi-Patient.fsh`
**Beskrivelse**: Pasienten som har fått rekvirert eller administrert legemiddel.

### MustSupport og kjerne
- `identifier` MS
- `identifier[FNR]` 0..1 MS — Fødselsnummer (system `urn:oid:2.16.578.1.12.4.1.4.1`)
- `identifier[DNR]` 0..1 MS — D-nummer (system `urn:oid:2.16.578.1.12.4.1.4.2`)
- `birthDate` MS
- `gender` MS
- `address` MS, `only NoBasisAddress`

### Address-regler
- `address.type = #physical` (fixed + `from LmdiAddressType (required)`)
- `address.use from LmdiAddressUse (required)` — bare `home`, `temp`, `old`
- `address.district` = Kommunenavn
  - `address.district.extension[municipalitycode]` = kodet kommune (OID 3402)
- `address.extension[urbanDistrict]` = bydel (OID 3403)
- `address.state` = fylkesnavn

### Deaktiverte felter (0..0)
`active`, `communication`, `contact`, `deceased[x]`, `generalPractitioner`, `link`, `managingOrganization`, `maritalStatus`, `multipleBirth[x]`, `name`, `photo`, `telecom`, `text`, `extension[citizenship]`, `identifier[FHN]`, `identifier[HNR]`, `address.city`, `address.text`, `address.line`, `address.country`, `address.postalCode`, `address.extension[official]`, `address.extension[propertyInformation]`

### Bruksregel
Pasient skal helst ha FNR eller DNR hvis tilgjengelig. Kan være helt uten identifier (gyldig, men uvanlig; eksempel: `Pasient-Uten-Personidentifikator`).

---

## Helsepersonell (`lmdi-practitioner`)
**Parent**: `NoBasisPractitioner` (`http://hl7.no/fhir/StructureDefinition/no-basis-Practitioner`)
**Fil**: `profiles/lmdi-Practitioner.fsh`
**Beskrivelse**: Helsepersonell som har rekvirert legemidlet.

### Kjerne
- `identifier` med `^slicing.rules = #closed` — **kun HPR tillatt**
- `identifier[HPR]` 0..1 MS — HPR-nummer (system `urn:oid:2.16.578.1.12.4.1.4.4`)

### Deaktiverte
`text`, `name`, `telecom`, `address`, `gender`, `birthDate`, `photo`, `qualification`, `communication`, `active`, `identifier[FNR]`, `identifier[DNR]`

### Merknad
Helsepersonell uten HPR-nummer er gyldig (`identifier` er 0..*, men closed). Eksempel `Helsepersonell-Uten-HPR`.

---

## Organisasjon (`lmdi-organization`)
**Parent**: `NoBasisOrganization` (`http://hl7.no/fhir/StructureDefinition/no-basis-Organization`)
**Fil**: `profiles/lmdi-Organization.fsh`
**Beskrivelse**: Helseinstitusjon på lavest mulig nivå (post, avdeling, klinikk, sykehus, sykehjem). Hierarki via `partOf`.

### MustSupport
- `identifier` MS
- `name` 1..1 MS
- `partOf` MS, `only Reference(Organisasjon)`
- `address` MS

### Identifikatorer (fra no-basis, slicing arvet)
- `identifier[ENH]` — Organisasjonsnummer (`urn:oid:2.16.578.1.12.4.1.4.101`)
- `identifier[RSH]` — RESH-ID (`urn:oid:2.16.578.1.12.4.1.4.102`)

### Type
- `type 0..*`
- `type[organisatoriskNiva] 0..0` (kodeverket OID 8628 utgått)
- `type[organisatoriskBetegnelse]` — OID 8624 (sykehus, avdeling, post, m.fl.)

### Invariant
- `lmdi-org-identifier` (error): **Minst én av ENH eller RSH** må finnes.

### Adresse
Som Pasient: `type = #physical` (required binding `LmdiAddressType`), `district` + `municipalitycode`, `urbanDistrict`. Deaktivert: `address.text/line/city/postalCode/country`.
**Unntak**: Organisasjon har ingen binding på `address.use` — `LmdiAddressUse`-bindingen (`home|temp|old`) gjelder bare Pasient.

### Deaktiverte
`text`, `active`, `telecom`, `contact`, `endpoint`

---

## Episode (`lmdi-encounter`)
**Parent**: `Encounter`
**Fil**: `profiles/lmdi-Encounter.fsh`
**Beskrivelse**: Behandlingsepisode — organisatorisk tilhørighet (innleggelse, sykehjemsopphold, konsultasjon).

### Kjerne
- `serviceProvider only Reference(Organisasjon)` — sted for episoden
- `extension[nprEpisodeIdentifier]` 0..* MS — NPR-id (string og/eller uuid)

### Deaktiverte (mange)
`statusHistory`, `classHistory`, `type`, `serviceType`, `priority`, `subject`, `episodeOfCare`, `basedOn`, `participant`, `appointment`, `period`, `length`, `reasonCode`, `reasonReference`, `diagnosis`, `account`, `hospitalization`, `location`, `partOf`, `text`

### Vanlige klasser (fra eksempler, `http://terminology.hl7.org/CodeSystem/v3-ActCode`)
- `IMP` — inpatient encounter (sykehus)
- `SS` — short stay (sykehjem)

### Kommentar
Pasienten referes **ikke** fra Episode (`subject` er 0..0). Tilknytningen går via `MedicationAdministration.context` → Episode og `MedicationAdministration.subject` → Pasient.

---

## Diagnose (`lmdi-condition`)
**Parent**: `Condition`
**Fil**: `profiles/lmdi-Condition.fsh`
**Beskrivelse**: Indikasjon for rekvirering / administrering.

### Kjerne
- `subject 1..1 only Reference(Pasient)`
- `code 1..1`
- `code.coding` closed slicing på system. Slices (alle 0..1):
  - `SCT` — system `http://snomed.info/sct`
  - `ICD10` — system `urn:oid:2.16.578.1.12.4.1.1.7110`
  - `ICD11` — system `http://id.who.int/icd/release/11/mms`
  - `ICPC2` — system `urn:oid:2.16.578.1.12.4.1.1.7170`
- `stage.summary 1..1` (hvis `stage` brukes i det hele tatt)
- `stage.assessment 0..0`

### Deaktiverte
`encounter`, `text`, `category`, `severity`, `bodySite`, `abatement[x]`, `onset[x]`, `recorder`, `recordedDate`, `asserter`, `evidence`, `note`

### Merknad
Minst én `code.coding[...]`-slice bør være utfylt. Dette er ikke en formell invariant, men `code 1..1` tvinger at `code`-objektet finnes, og tomt `code` gir ingen mening.

---

## Legemiddel (`lmdi-medication`)
**Parent**: `Medication`
**Fil**: `profiles/lmdi-Medication.fsh`
**Beskrivelse**: Legemiddelproduktet eller virkestoffet som ble rekvirert/administrert.

### Invariant
- `lmdi-medication-code-or-ingredient` (error): `code.coding.exists() or ingredient.exists()`

### `code`
- `from LegemiddelKoder (extensible)`
- `code.text 0..0`
- `code.coding` open slicing på system. Slices (alle 0..1, med fast system og `code 1..1`):

| Slice | System |
|---|---|
| `FestLegemiddeldose` | `http://dmp.no/fhir/NamingSystem/festLegemiddelDose` |
| `FestLmrLopenr` | `http://dmp.no/fhir/NamingSystem/lmrLopenummer` |
| `FestLegemiddelMerkevare` | `http://dmp.no/fhir/NamingSystem/festLegemiddelMerkevare` |
| `FestLegemiddelpakning` | `http://dmp.no/fhir/NamingSystem/festLegemiddelPakning` |
| `Varenummer` | `http://dmp.no/fhir/NamingSystem/fest-varenummer` |
| `FestLegemiddelVirkestoff` | `http://dmp.no/fhir/NamingSystem/festLegemiddelVirkestoff` |
| `LokaltLegemiddel` | `http://fhi.no/fhir/NamingSystem/lokaltLegemiddel` — `display 1..1` |
| `SCT` | `http://snomed.info/sct` — kode skal være underbegrep av 763158003 eller 105590001 |

### `extension`
- Closed slicing. Inneholder `classification` (0..*) — `LegemiddelClassification`-extension for ATC-kode.

### `form`
- `form.text 0..0`
- `form.coding 1..*`, closed slicing
- Slices (0..1): `OID7448` (Legemiddelform, OID 7448), `SCT`

### `ingredient`
- `ingredient.item[x] only Reference or CodeableConcept`
- `ingredient.itemReference only Reference($LMDISubstance or $LMDIMedication)`
- `ingredient.itemCodeableConcept from LegemiddelKoder (preferred)`
- Skal brukes hvis `code` mangler. Bør brukes i tillegg når `code.coding[LokaltLegemiddel]` er satt (bedre sporbarhet).

#### `ingredient.strength` — styrke vs. mengde (fra 1.1.4)
- `strength` (Ratio, 0..1, uendret kardinalitet) = **styrken** av ingrediensen i legemidlet.
- `strength.extension` inneholder slicen `mengde` (0..1) — `IngrediensStyrke`-extension for **mengde**
  (volum eller mengde virkestoff), som `Quantity` eller kodet (`qs`, `trace`). Se `extensions.md`.
- R4 har ikke `strength[x]`; i R5/R6 er dette étt element med tre typer. Extension-en dekker de to
  typene R4 mangler.
- Når bare mengde oppgis, skrives `strength` **uten** `numerator`/`denominator`. Det er gyldig R4:
  invarianten `rat-1` krever teller+nevner **eller** minst én extension.
- Ved volum bør `Medication.amount` settes på det sammensatte legemidlet, ellers kan ikke
  ingrediensens styrke i blandingen utledes.

### `batch` MS
- `manufacturer 0..0`, `text 0..0`

### Merknad 1.1.0
`extension[classification]` endret fra 0..1 til 0..* — et legemiddel kan nå ha flere ATC-koder.

---

## Virkestoff (`lmdi-substance`)
**Parent**: `NoBasisSubstance`
**Fil**: `profiles/lmdi-Substance.fsh`

- `category 1..1` (gjør kategori påkrevd)
- Deaktivert: `text`, `description`, `ingredient`

Typisk brukt for rene virkestoff der man vil referere dem fra `Legemiddel.ingredient.itemReference`.

---

## Legemiddelrekvirering (`lmdi-medicationrequest`)
**Parent**: `MedicationRequest`
**Fil**: `profiles/lmdi-MedicationRequest.fsh`

### Kjerne (MS)
- `identifier` 0..* MS
- `status 1..1 MS from http://hl7.org/fhir/ValueSet/medicationrequest-status`
- `intent 1..1 MS`
- `medication[x] 1..1 MS only Reference(Legemiddel)`
- `subject 1..1 MS only Reference(Pasient)`
- `requester 0..1 MS only Reference(Helsepersonell)` — oppgis når rekvirenten er kjent; mottakere kan ikke forutsette at feltet finnes

### Valgfrie referanser
- `encounter only Reference(Episode)`
- `reasonReference only Reference(Diagnose)`
- `priorPrescription only Reference(Legemiddelrekvirering)`
- `reported[x] only boolean`

### Extensions (alle 0..1)
- `prosentvisDoseendring` — `ProsentvisDoseendring` (Quantity i %)
- `delAvBehandlingsregime` — `DelAvBehandlingsregime` (string)
- `kliniskStudie` — `KliniskStudie` (boolean)

### Deaktiverte
`text`, `recorder`, `insurance`, `supportingInformation`, `performer`, `performerType`, `basedOn`, `note`, `dispenseRequest`, `detectedIssue`, `eventHistory`, `dosageInstruction.text`, `dosageInstruction.patientInstruction`

### Status-koder (gyldige, fra FHIR)
`active | on-hold | cancelled | completed | entered-in-error | stopped | draft | unknown`

### Intent-koder
`proposal | plan | order | original-order | reflex-order | filler-order | instance-order | option`

---

## Legemiddeladministrering (`lmdi-medicationadministration`) — kjerneressurs
**Parent**: `MedicationAdministration`
**Fil**: `profiles/lmdi-MedicationAdministration.fsh`

### Kjerne
- `subject only Reference(Pasient)`
- `medication[x] only Reference(Legemiddel)`
- `status from LegemiddeladministreringStatus` — **kun** `completed` og `entered-in-error`
- `effective[x] only Period or dateTime`, 1..1
- `effectiveDateTime obeys time-required`
- `effectivePeriod.start 1..1 obeys time-required`
- `effectivePeriod.end 1..1 obeys time-required`

### MS
- `context only Reference(Episode)` — episode det ble administrert under
- `request only Reference(Legemiddelrekvirering)` — rekvireringen dette er basert på
- `dosage.route` — med slicing (se under)
- `dosage.rateRatio` — infusjonshastighet

### `category`
- `from http://hl7.org/fhir/ValueSet/medication-admin-category (preferred)`
- `community` = selvadministrering (pasient tar selv, utdelt av institusjon)

### `reasonReference`
- `only Reference(Diagnose)`

### `dosage`
- `dosage.dose 1..1` — administrert mengde
- `dosage.text 0..0`, `dosage.route.text 0..0`
- `dosage.route.coding 1..*`, closed slicing på system:
  - `SCT` 0..1 — system `http://snomed.info/sct`, kode `from http://hl7.org/fhir/ValueSet/route-codes (required)`
  - `OID7477` 0..1 — system `urn:oid:2.16.578.1.12.4.1.1.7477` (Administrasjonsvei)

### Invariant
- `time-required` — dato/tid må ha presisjon ned til minutt (regex `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}.*$`).

### Deaktiverte
`device`, `note`, `partOf`, `performer`, `supportingInformation`, `text`, `eventHistory`

### Innebygd valueset
`LegemiddeladministreringStatus` (`lmdi-medicationadministrationstatus`) definert i samme FSH-fil.

---

## LegemiddelregisterBundle (`lmdi-bundle`)
**Parent**: `Bundle`
**Fil**: `profiles/LegemiddelregisterBundle.fsh`
**Beskrivelse**: Transport-bundle; **transaction** med kun **POST** på ni LMDI-ressurstyper.

### Påkrevde felter
- `identifier 1..1 MS`
- `timestamp 1..1 MS`
- `type 1..1 MS = #transaction` (exactly)
- `entry 1..* MS`

### Entry-regler
- `entry.request 1..1 MS`
- `entry.request.method 1..1 MS = #POST` (exactly)
- `entry.request.url 1..1` — påkrevd av FHIR-spec, men verdien har ingen funksjonell betydning
- `entry.resource 1..1 MS`

### Deaktiverte
- `total 0..0`, `link 0..0`

### Invariant `lr-allowed-resources` (error)
Hver `entry.resource.meta.profile` må peke på én av:
- `lmdi-condition`, `lmdi-practitioner`, `lmdi-encounter`, `lmdi-medication`, `lmdi-medicationadministration`, `lmdi-medicationrequest`, `lmdi-organization`, `lmdi-patient`, `lmdi-substance`

(Canonical-prefiks: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/`.)

# Struktur — generert fra StructureDefinition

**Generert av `scripts/generer-struktur.py`. Ikke rediger for hånd.** IG-versjon: 1.1.10.

Fila viser det LMDI endrer i forhold til parent (differential): kardinalitet, MustSupport,
typer og referansemål, bindinger, faste verdier, slicing og invarianter. Elementer som ikke
står her, arves uendret fra parent. Ved motstrid med de håndskrevne referansefilene gjelder
denne fila. Forklaring, praksis og bruksregler står i `profiler.md` og `extensions.md`.

Elementnavn med kolon er slices (`code.coding:ICD10`). «·» betyr at grensen ikke er endret
i profilen og at snapshot manglet da fila ble generert.

# Profiler

## LegemiddelregisterBundle (`lmdi-bundle`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-bundle`
- Type: `Bundle`, parent: `http://hl7.org/fhir/StructureDefinition/Bundle`
- Påkrevd inkl. FHIR-basis (toppnivå): `identifier` 1..1, `type` 1..1, `timestamp` 1..1, `entry` 1..*
- Deaktivert (0..0): `total`, `link`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `Bundle` |  |  |  |  |  | `lr-allowed-resources` |
| `identifier` | 1..1 | MS |  |  |  |  |
| `type` | 1..1 | MS |  |  | `transaction` |  |
| `timestamp` | 1..1 | MS |  |  |  |  |
| `entry` | 1..* | MS |  |  |  |  |
| `entry.resource` | 1..1 | MS |  |  |  |  |
| `entry.request` | 1..1 | MS |  |  |  |  |
| `entry.request.method` | 1..1 | MS |  |  | `POST` |  |

Invarianter:

- `lr-allowed-resources` (error): Bundle kan bare inneholde følgende profilerte ressurstyper: Diagnose, Helsepersonell, Episode, Legemiddel, LegemiddelAdministrasjon, Legemiddelrekvirering, Organisasjon, Pasient, Virkestoff. FHIRPath: `entry.all( resource.meta.profile.where($this = 'http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-condition').exists() or resource.meta.profile.where($this = 'http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-practitioner').exists() or resource.meta.profile.where($this = 'http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-encounter').exists() or resource.meta.profile.where($this = 'http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medication').exists() or resource.meta.profile.where($this = 'http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medicationadministration').exists() or resource.meta.profile.where($this = 'http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medicationrequest').exists() or resource.meta.profile.where($this = 'http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-organization').exists() or resource.meta.profile.where($this = 'http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-patient').exists() or resource.meta.profile.where($this = 'http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-substance').exists() )`

## Diagnose (`lmdi-condition`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-condition`
- Type: `Condition`, parent: `http://hl7.org/fhir/StructureDefinition/Condition`
- Påkrevd inkl. FHIR-basis (toppnivå): `code` 1..1, `subject` 1..1
- Deaktivert (0..0): `text`, `category`, `severity`, `bodySite`, `encounter`, `onset[x]`, `abatement[x]`, `recordedDate`, `recorder`, `asserter`, `stage.assessment`, `evidence`, `note`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `code` | 1..1 |  |  |  |  |  |
| `code.coding` | 0..* |  |  |  |  | slicing closed (pattern:system) |
| `code.coding:SCT` | 0..1 |  |  |  |  |  |
| `code.coding:SCT.system` | 1..1 |  |  |  | `http://snomed.info/sct` |  |
| `code.coding:SCT.code` | 1..1 |  |  |  |  |  |
| `code.coding:ICD10` | 0..* |  |  |  |  |  |
| `code.coding:ICD10.system` | 1..1 |  |  |  | `urn:oid:2.16.578.1.12.4.1.1.7110` |  |
| `code.coding:ICD10.code` | 1..1 |  |  |  |  |  |
| `code.coding:ICD11` | 0..1 |  |  |  |  |  |
| `code.coding:ICD11.system` | 1..1 |  |  |  | `http://id.who.int/icd/release/11/mms` |  |
| `code.coding:ICD11.code` | 1..1 |  |  |  |  |  |
| `code.coding:ICPC2` | 0..1 |  |  |  |  |  |
| `code.coding:ICPC2.system` | 1..1 |  |  |  | `urn:oid:2.16.578.1.12.4.1.1.7170` |  |
| `code.coding:ICPC2.code` | 1..1 |  |  |  |  |  |
| `subject` | 1..1 |  | Reference(lmdi-patient) |  |  |  |
| `stage.summary` | 1..1 |  |  |  |  |  |

## Episode (`lmdi-encounter`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-encounter`
- Type: `Encounter`, parent: `http://hl7.org/fhir/StructureDefinition/Encounter`
- Påkrevd inkl. FHIR-basis (toppnivå): `status` 1..1, `class` 1..1
- Deaktivert (0..0): `text`, `statusHistory`, `classHistory`, `type`, `serviceType`, `priority`, `subject`, `episodeOfCare`, `basedOn`, `participant`, `appointment`, `period`, `length`, `reasonCode`, `reasonReference`, `diagnosis`, `account`, `hospitalization`, `location`, `partOf`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `extension` | 0..* |  |  |  |  | slicing open (value:url) |
| `extension:nprEpisodeIdentifier` | 0..* | MS | Extension: npr-episode-identifier |  |  |  |
| `serviceProvider` | 0..1 |  | Reference(lmdi-organization) |  |  |  |

## Legemiddel (`lmdi-medication`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medication`
- Type: `Medication`, parent: `http://hl7.org/fhir/StructureDefinition/Medication`
- Påkrevd inkl. FHIR-basis (toppnivå): ingen
- Deaktivert (0..0): `text`, `code.text`, `manufacturer`, `form.text`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `Medication` |  |  |  |  |  | `lmdi-medication-code-or-ingredient` |
| `extension` | 0..* |  |  |  |  | slicing closed (value:url) |
| `extension:classification` | 0..* |  | Extension: legemiddel-classification |  |  |  |
| `extension:assosiertLegemiddel` | 0..* |  | Extension: lmdi-assosiert-legemiddel |  |  |  |
| `code` | 0..1 |  |  | extensible: `http://hl7.no/fhir/ig/lmdi/ValueSet/legemiddel-koder` |  |  |
| `code.coding` | 0..* |  |  |  |  | slicing open (value:system) |
| `code.coding:FestLegemiddeldose` | 0..1 |  |  |  |  |  |
| `code.coding:FestLegemiddeldose.system` | 1..1 |  |  |  | `http://dmp.no/fhir/NamingSystem/festLegemiddelDose` |  |
| `code.coding:FestLegemiddeldose.code` | 1..1 |  |  |  |  |  |
| `code.coding:FestLmrLopenr` | 0..1 |  |  |  |  |  |
| `code.coding:FestLmrLopenr.system` | 1..1 |  |  |  | `http://dmp.no/fhir/NamingSystem/lmrLopenummer` |  |
| `code.coding:FestLmrLopenr.code` | 1..1 |  |  |  |  |  |
| `code.coding:FestLegemiddelMerkevare` | 0..1 |  |  |  |  |  |
| `code.coding:FestLegemiddelMerkevare.system` | 1..1 |  |  |  | `http://dmp.no/fhir/NamingSystem/festLegemiddelMerkevare` |  |
| `code.coding:FestLegemiddelMerkevare.code` | 1..1 |  |  |  |  |  |
| `code.coding:FestLegemiddelpakning` | 0..1 |  |  |  |  |  |
| `code.coding:FestLegemiddelpakning.system` | 1..1 |  |  |  | `http://dmp.no/fhir/NamingSystem/festLegemiddelPakning` |  |
| `code.coding:FestLegemiddelpakning.code` | 1..1 |  |  |  |  |  |
| `code.coding:Varenummer` | 0..1 |  |  |  |  |  |
| `code.coding:Varenummer.system` | 1..1 |  |  |  | `http://dmp.no/fhir/NamingSystem/fest-varenummer` |  |
| `code.coding:Varenummer.code` | 1..1 |  |  |  |  |  |
| `code.coding:FestLegemiddelVirkestoff` | 0..1 |  |  |  |  |  |
| `code.coding:FestLegemiddelVirkestoff.system` | 1..1 |  |  |  | `http://dmp.no/fhir/NamingSystem/festLegemiddelVirkestoff` |  |
| `code.coding:FestLegemiddelVirkestoff.code` | 1..1 |  |  |  |  |  |
| `code.coding:LokaltLegemiddel` | 0..1 |  |  |  |  |  |
| `code.coding:LokaltLegemiddel.system` | 1..1 |  |  |  | `http://fhi.no/fhir/NamingSystem/lokaltLegemiddel` |  |
| `code.coding:LokaltLegemiddel.code` | 1..1 |  |  |  |  |  |
| `code.coding:LokaltLegemiddel.display` | 1..1 |  |  |  |  |  |
| `code.coding:SCT` | 0..1 |  |  |  |  |  |
| `code.coding:SCT.system` | 1..1 |  |  |  | `http://snomed.info/sct` |  |
| `code.coding:SCT.code` | 1..1 |  |  |  |  |  |
| `form.coding` | 1..* |  |  |  |  | slicing open (value:system) |
| `form.coding.system` | 1..1 |  |  |  |  |  |
| `form.coding.code` | 1..1 |  |  |  |  |  |
| `form.coding.display` | 0..1 | MS |  |  |  |  |
| `form.coding:OID7448` | 0..1 |  |  |  |  |  |
| `form.coding:OID7448.system` | 1..1 |  |  |  | `urn:oid:2.16.578.1.12.4.1.1.7448` |  |
| `form.coding:SCT` | 0..1 |  |  |  |  |  |
| `form.coding:SCT.system` | 1..1 |  |  |  | `http://snomed.info/sct` |  |
| `ingredient.item[x]` | 1..1 |  |  |  |  | slicing open (type:$this) |
| `ingredient.item[x]:itemReference` | 0..1 |  | Reference(lmdi-substance \| lmdi-medication) |  |  |  |
| `ingredient.item[x]:itemCodeableConcept` | 0..1 |  | CodeableConcept | preferred: `http://hl7.no/fhir/ig/lmdi/ValueSet/legemiddel-koder` |  |  |
| `ingredient.strength.extension:mengde` | 0..1 |  | Extension: lmdi-ingredient-strength |  |  |  |
| `batch` | 0..1 | MS |  |  |  |  |

Invarianter:

- `lmdi-medication-code-or-ingredient` (error): Medication skal ha code.coding eller ingredient. FHIRPath: `code.coding.exists() or ingredient.exists()`

## Legemiddeladministrering (`lmdi-medicationadministration`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medicationadministration`
- Type: `MedicationAdministration`, parent: `http://hl7.org/fhir/StructureDefinition/MedicationAdministration`
- Påkrevd inkl. FHIR-basis (toppnivå): `status` 1..1, `medication[x]` 1..1, `subject` 1..1, `effective[x]` 1..1
- Deaktivert (0..0): `text`, `partOf`, `supportingInformation`, `performer`, `device`, `note`, `dosage.text`, `dosage.route.text`, `eventHistory`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `extension` | 0..* |  |  |  |  | slicing open (value:url) |
| `extension:administrertVed` | 0..1 | MS | Extension: lmdi-administrert-ved |  |  |  |
| `status` | 1..1 |  |  | required: `http://hl7.no/fhir/ig/lmdi/ValueSet/lmdi-medicationadministrationstatus` |  |  |
| `category` | 0..1 |  |  | preferred: `http://hl7.org/fhir/ValueSet/medication-admin-category` |  |  |
| `medication[x]` | 1..1 |  | Reference(lmdi-medication) |  |  |  |
| `subject` | 1..1 |  | Reference(lmdi-patient) |  |  |  |
| `context` | 0..1 | MS | Reference(lmdi-encounter) |  |  |  |
| `effective[x]` | 1..1 |  |  |  |  | slicing open (type:$this) |
| `effective[x]:effectiveDateTime` | 0..1 |  | dateTime |  |  | `time-required` |
| `effective[x]:effectivePeriod` | 0..1 |  | Period |  |  |  |
| `effective[x]:effectivePeriod.start` | 1..1 |  |  |  |  | `time-required` |
| `effective[x]:effectivePeriod.end` | 1..1 |  |  |  |  | `time-required` |
| `reasonReference` | 0..* |  | Reference(lmdi-condition) |  |  |  |
| `request` | 0..1 | MS | Reference(lmdi-medicationrequest) |  |  |  |
| `dosage.route` | 0..1 | MS |  |  |  |  |
| `dosage.route.coding` | 1..* |  |  |  |  | slicing closed (pattern:system) |
| `dosage.route.coding:SCT` | 0..1 |  |  |  |  |  |
| `dosage.route.coding:SCT.system` | 1..1 |  |  |  | `http://snomed.info/sct` |  |
| `dosage.route.coding:SCT.code` | 1..1 |  |  | required: `http://hl7.org/fhir/ValueSet/route-codes` |  |  |
| `dosage.route.coding:OID7477` | 0..1 |  |  |  |  |  |
| `dosage.route.coding:OID7477.system` | 1..1 |  |  |  | `urn:oid:2.16.578.1.12.4.1.1.7477` |  |
| `dosage.route.coding:OID7477.code` | 1..1 |  |  |  |  |  |
| `dosage.dose` | 1..1 |  |  |  |  |  |
| `dosage.rate[x]` | 0..1 |  |  |  |  | slicing open (type:$this) |
| `dosage.rate[x]:rateRatio` | 0..1 | MS | Ratio |  |  |  |

Invarianter:

- `time-required` (error): Må inneholde tidspunkt for administrering. FHIRPath: `$this.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}.*$')`

## Legemiddelrekvirering (`lmdi-medicationrequest`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medicationrequest`
- Type: `MedicationRequest`, parent: `http://hl7.org/fhir/StructureDefinition/MedicationRequest`
- Påkrevd inkl. FHIR-basis (toppnivå): `status` 1..1, `intent` 1..1, `medication[x]` 1..1, `subject` 1..1
- Deaktivert (0..0): `text`, `supportingInformation`, `performer`, `performerType`, `recorder`, `basedOn`, `insurance`, `note`, `dosageInstruction.text`, `dosageInstruction.patientInstruction`, `dispenseRequest`, `detectedIssue`, `eventHistory`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `extension` | 0..* |  |  |  |  | slicing open (value:url) |
| `extension:prosentvisDoseendring` | 0..1 |  | Extension: lmdi-prosentvis-doseendring |  |  |  |
| `extension:delAvBehandlingsregime` | 0..1 |  | Extension: lmdi-del-av-behandlingsregime |  |  |  |
| `extension:kliniskStudie` | 0..1 |  | Extension: lmdi-klinisk-studie |  |  |  |
| `extension:rekvirertVed` | 0..1 | MS | Extension: lmdi-rekvirert-ved |  |  |  |
| `identifier` | 0..* | MS |  |  |  |  |
| `status` | 1..1 | MS |  | required: `http://hl7.org/fhir/ValueSet/medicationrequest-status` |  |  |
| `intent` | 1..1 | MS |  |  |  |  |
| `reported[x]` | 0..1 |  | boolean |  |  |  |
| `medication[x]` | 1..1 | MS | Reference(lmdi-medication) |  |  |  |
| `subject` | 1..1 | MS | Reference(lmdi-patient) |  |  |  |
| `encounter` | 0..1 |  | Reference(lmdi-encounter) |  |  |  |
| `requester` | 0..1 | MS | Reference(lmdi-practitioner) |  |  |  |
| `reasonReference` | 0..* |  | Reference(lmdi-condition) |  |  |  |
| `priorPrescription` | 0..1 |  | Reference(lmdi-medicationrequest) |  |  |  |

## Organisasjon (`lmdi-organization`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-organization`
- Type: `Organization`, parent: `http://hl7.no/fhir/StructureDefinition/no-basis-Organization`
- Påkrevd inkl. FHIR-basis (toppnivå): `name` 1..1
- Deaktivert (0..0): `text`, `active`, `type:organisatoriskNiva`, `telecom`, `address.extension:official`, `address.extension:propertyInformation`, `address.text`, `address.line`, `address.city`, `address.postalCode`, `address.country`, `contact`, `endpoint`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `identifier` | 0..* | MS |  |  |  |  |
| `name` | 1..1 | MS |  |  |  |  |
| `address` | 0..* | MS |  |  |  |  |
| `address.type` | 0..1 |  |  | required: `http://hl7.no/fhir/ig/lmdi/ValueSet/lmdi-address-type` | `physical` |  |
| `partOf` | 0..1 | MS | Reference(lmdi-organization) |  |  |  |

## Pasient (`lmdi-patient`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-patient`
- Type: `Patient`, parent: `http://hl7.no/fhir/StructureDefinition/no-basis-Patient`
- Påkrevd inkl. FHIR-basis (toppnivå): ingen
- Deaktivert (0..0): `text`, `extension:citizenship`, `identifier:FHN`, `identifier:HNR`, `active`, `name`, `telecom`, `deceased[x]`, `address.extension:official`, `address.extension:propertyInformation`, `address.text`, `address.line`, `address.city`, `address.postalCode`, `address.country`, `maritalStatus`, `multipleBirth[x]`, `photo`, `contact`, `communication`, `generalPractitioner`, `managingOrganization`, `link`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `identifier` | 0..* | MS |  |  |  |  |
| `identifier:FNR` | 0..1 | MS |  |  |  |  |
| `identifier:DNR` | 0..1 | MS |  |  |  |  |
| `gender` | 0..1 | MS |  |  |  |  |
| `birthDate` | 0..1 | MS |  |  |  |  |
| `address` | 0..* | MS |  |  |  |  |
| `address.use` | 0..1 |  |  | required: `http://hl7.no/fhir/ig/lmdi/ValueSet/lmdi-address-use` |  |  |
| `address.type` | 0..1 |  |  | required: `http://hl7.no/fhir/ig/lmdi/ValueSet/lmdi-address-type` | `physical` |  |

## Helsepersonell (`lmdi-practitioner`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-practitioner`
- Type: `Practitioner`, parent: `http://hl7.no/fhir/StructureDefinition/no-basis-Practitioner`
- Påkrevd inkl. FHIR-basis (toppnivå): ingen
- Deaktivert (0..0): `text`, `identifier:FNR`, `identifier:DNR`, `active`, `name`, `telecom`, `address`, `gender`, `birthDate`, `photo`, `qualification`, `communication`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `identifier` | 0..* |  |  |  |  | slicing closed (value:system) |
| `identifier:HPR` | 0..1 | MS |  |  |  |  |

## Virkestoff (`lmdi-substance`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-substance`
- Type: `Substance`, parent: `http://hl7.no/fhir/StructureDefinition/no-basis-Substance`
- Påkrevd inkl. FHIR-basis (toppnivå): `category` 1..1, `code` 1..1
- Deaktivert (0..0): `text`, `description`, `ingredient`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `category` | 1..1 |  |  |  |  |  |

# Extensions

## Legemiddel Classification (`legemiddel-classification`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/legemiddel-classification`
- Type: `Extension`, parent: `http://hl7.org/fhir/StructureDefinition/Extension`
- Context: `Medication`
- Deaktivert (0..0): `extension`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `url` | 1..1 |  |  |  | `http://hl7.no/fhir/ig/lmdi/StructureDefinition/legemiddel-classification` |  |
| `value[x]` | 1..1 | MS | CodeableConcept | preferred: `http://fhir.no/ValueSet/atc-valueset` |  |  |

## Administrert ved (`lmdi-administrert-ved`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-administrert-ved`
- Type: `Extension`, parent: `http://hl7.org/fhir/StructureDefinition/Extension`
- Context: `MedicationAdministration`
- Deaktivert (0..0): `extension`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `url` | 1..1 |  |  |  | `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-administrert-ved` |  |
| `value[x]` | 0..1 |  | Reference(lmdi-organization) |  |  |  |

## Assosiert legemiddel (`lmdi-assosiert-legemiddel`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-assosiert-legemiddel`
- Type: `Extension`, parent: `http://hl7.org/fhir/StructureDefinition/Extension`
- Context: `Medication`
- Deaktivert (0..0): `extension`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `Extension` |  |  |  |  |  | `lmdi-assosiert-legemiddel-system` |
| `url` | 1..1 |  |  |  | `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-assosiert-legemiddel` |  |
| `value[x]` | 0..1 |  | Coding |  |  |  |
| `value[x].system` | 1..1 |  |  |  |  |  |
| `value[x].code` | 1..1 |  |  |  |  |  |

Invarianter:

- `lmdi-assosiert-legemiddel-system` (error): Assosiert legemiddel skal være angitt med FEST-id (legemiddeldose, merkevare eller pakning), LMR-løpenummer, varenummer eller SNOMED CT-kode. FHIRPath: `value.ofType(Coding).all(system in ('http://dmp.no/fhir/NamingSystem/festLegemiddelDose' | 'http://dmp.no/fhir/NamingSystem/lmrLopenummer' | 'http://dmp.no/fhir/NamingSystem/festLegemiddelMerkevare' | 'http://dmp.no/fhir/NamingSystem/festLegemiddelPakning' | 'http://dmp.no/fhir/NamingSystem/fest-varenummer' | 'http://snomed.info/sct'))`

## Del av behandlingsregime (`lmdi-del-av-behandlingsregime`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-del-av-behandlingsregime`
- Type: `Extension`, parent: `http://hl7.org/fhir/StructureDefinition/Extension`
- Context: `MedicationRequest`
- Deaktivert (0..0): `extension`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `url` | 1..1 |  |  |  | `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-del-av-behandlingsregime` |  |
| `value[x]` | 0..1 |  | string |  |  |  |

## Mengde ingrediens (`lmdi-ingredient-strength`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-ingredient-strength`
- Type: `Extension`, parent: `http://hl7.org/fhir/StructureDefinition/Extension`
- Context: `Medication.ingredient.strength`
- Deaktivert (0..0): `extension`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `url` | 1..1 |  |  |  | `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-ingredient-strength` |  |
| `value[x]` | 0..1 |  | CodeableConcept, Quantity |  |  |  |

## Klinisk studie (`lmdi-klinisk-studie`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-klinisk-studie`
- Type: `Extension`, parent: `http://hl7.org/fhir/StructureDefinition/Extension`
- Context: `MedicationRequest`
- Deaktivert (0..0): `extension`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `url` | 1..1 |  |  |  | `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-klinisk-studie` |  |
| `value[x]` | 0..1 |  | boolean |  |  |  |

## Prosentvis doseendring (`lmdi-prosentvis-doseendring`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-prosentvis-doseendring`
- Type: `Extension`, parent: `http://hl7.org/fhir/StructureDefinition/Extension`
- Context: `MedicationRequest`
- Deaktivert (0..0): `extension`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `url` | 1..1 |  |  |  | `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-prosentvis-doseendring` |  |
| `value[x]` | 0..1 |  | Quantity |  |  |  |
| `value[x].unit` | 0..1 |  |  |  | `%` |  |
| `value[x].system` | 0..1 |  |  |  | `http://unitsofmeasure.org` |  |
| `value[x].code` | 0..1 |  |  |  | `%` |  |

## Rekvirert ved (`lmdi-rekvirert-ved`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-rekvirert-ved`
- Type: `Extension`, parent: `http://hl7.org/fhir/StructureDefinition/Extension`
- Context: `MedicationRequest`
- Deaktivert (0..0): `extension`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `url` | 1..1 |  |  |  | `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-rekvirert-ved` |  |
| `value[x]` | 0..1 |  | Reference(lmdi-organization) |  |  |  |

## NPR Episode Identifier (`npr-episode-identifier`)

- Canonical: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/npr-episode-identifier`
- Type: `Extension`, parent: `http://hl7.org/fhir/StructureDefinition/Extension`
- Context: `Encounter`
- Deaktivert (0..0): `extension:stringIdentifier.extension`, `extension:uuidIdentifier.extension`, `value[x]`

| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |
|---|---|---|---|---|---|---|
| `Extension` |  |  |  |  |  | `npr-episode-at-least-one` |
| `extension:stringIdentifier` | 0..1 | MS |  |  |  |  |
| `extension:stringIdentifier.url` | 1..1 |  |  |  | `stringIdentifier` |  |
| `extension:stringIdentifier.value[x]` | 1..1 |  | string |  |  |  |
| `extension:uuidIdentifier` | 0..1 | MS |  |  |  |  |
| `extension:uuidIdentifier.url` | 1..1 |  |  |  | `uuidIdentifier` |  |
| `extension:uuidIdentifier.value[x]` | 1..1 |  | uuid |  |  |  |
| `url` | 1..1 |  |  |  | `http://hl7.no/fhir/ig/lmdi/StructureDefinition/npr-episode-identifier` |  |

Invarianter:

- `npr-episode-at-least-one` (error): Minst én NPR episode identifikator (string eller UUID) må oppgis. FHIRPath: `extension('stringIdentifier').exists() or extension('uuidIdentifier').exists()`

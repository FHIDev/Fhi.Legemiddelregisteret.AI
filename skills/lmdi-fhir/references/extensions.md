# LMDI Extensions

Kilde: `LMDI/input/fsh/extensions/*.fsh`. Canonical-mønster: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/<id>`.

## Oversikt

| Title | Id | Context | value[x] | Filnavn |
|---|---|---|---|---|
| Legemiddel Classification | `legemiddel-classification` | `Medication` | `CodeableConcept` | `lmdi-LegemiddelClassification.fsh` |
| Prosentvis doseendring | `lmdi-prosentvis-doseendring` | `MedicationRequest` | `Quantity` | `lmdi-ext-prosentvis-doseendring.fsh` |
| Del av behandlingsregime | `lmdi-del-av-behandlingsregime` | `MedicationRequest` | `string` | `lmdi-ext-del-av-behandlingsregime.fsh` |
| Klinisk studie | `lmdi-klinisk-studie` | `MedicationRequest` | `boolean` | `lmdi-ext-klinisk-studie.fsh` |
| NPR Episode Identifier | `npr-episode-identifier` | `Encounter` | (kompleks) | `lmdi-ext-npr-episode-identifier.fsh` |

---

## LegemiddelClassification (`legemiddel-classification`)

Status: `active`. Context: `Medication`.

- `value[x] only CodeableConcept`
- `valueCodeableConcept 1..1 MS`
- Binding preferred: `http://fhir.no/ValueSet/atc-valueset` (ATC)

### Bruk i Legemiddel
```
extension[classification].valueCodeableConcept = $ATC#N02AA05 "Oksykodon"
```
`extension` er 0..* i `Legemiddel` fra 1.1.0 — flere ATC-koder er tillatt per legemiddel.

---

## ProsentvisDoseendring (`lmdi-prosentvis-doseendring`)

Context: `MedicationRequest`.

- `value[x] only Quantity`
- `valueQuantity.system = "http://unitsofmeasure.org"` (fast)
- `valueQuantity.code = #%` (fast)
- `valueQuantity.unit = "%"` (fast)

### Bruk
```
extension[prosentvisDoseendring].valueQuantity.value = 80
extension[prosentvisDoseendring].valueQuantity.system = "http://unitsofmeasure.org"
extension[prosentvisDoseendring].valueQuantity.code = #%
extension[prosentvisDoseendring].valueQuantity.unit = "%"
```

100 % = umodifisert dose. Lavere = redusert, høyere = økt. Spesielt aktuelt ved kjemoterapi.

---

## DelAvBehandlingsregime (`lmdi-del-av-behandlingsregime`)

Context: `MedicationRequest`.

- `value[x] only string`

### Bruk
```
extension[delAvBehandlingsregime].valueString = "FOLFOX6"
```

Navn på kur, protokoll eller behandlingsregime.

---

## KliniskStudie (`lmdi-klinisk-studie`)

Context: `MedicationRequest`.

- `value[x] only boolean`

### Bruk
```
extension[kliniskStudie].valueBoolean = true
```

`true` = legemidlet gis som del av klinisk studie.

---

## NprEpisodeIdentifier (`npr-episode-identifier`)

Status: `active`. Context: `Encounter`.

Kompleks extension med to sub-extensions:

| Sub | Kardinalitet | Type |
|---|---|---|
| `stringIdentifier` | 0..1 MS | `valueString 1..1` |
| `uuidIdentifier` | 0..1 MS | `valueUuid 1..1` |

### Invariant `npr-episode-at-least-one` (error)
Minst én av `stringIdentifier` eller `uuidIdentifier` må være satt.

### Bruk (fra eksempel `Episode-Sykehus` — to NPR-identifikatorer på samme episode)
```
extension[nprEpisodeIdentifier][0].extension[stringIdentifier].valueString = "NPR987654321"
extension[nprEpisodeIdentifier][0].extension[uuidIdentifier].valueUuid = "urn:uuid:550e8400-e29b-41d4-a716-446655440000"
extension[nprEpisodeIdentifier][1].extension[stringIdentifier].valueString = "NPR123456789"
```

### Praksisregel (fra `^definition`)
Extensionen kan gjentas (0..* på Episode fra 1.1.2), slik at flere NPR-ID-er kan oppgis for samme episode. Innen hver forekomst: oppgi både string- og uuid-representasjonen hvis begge finnes.

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
| Mengde ingrediens | `lmdi-ingredient-strength` | `Medication.ingredient.strength` | `CodeableConcept` \| `Quantity` | `lmdi-ext-ingredient-strength.fsh` |

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

---

## IngrediensStyrke (`lmdi-ingredient-strength`)

Status: `draft`. Context: **`Medication.ingredient.strength`** — den eneste extensionen i IG-en med
context dypere enn ressursrot.

- `value[x] only CodeableConcept or Quantity`
- **Ingen binding.** Anbefalt kodeverk står i `^comment` på `value[x]`: det norske kodeverket
  med OID `2.16.578.1.12.4.1.1.7502`, eller R5-kodeverket
  `http://hl7.org/fhir/CodeSystem/medication-ingredientstrength` (kodene `qs` og `trace`)

Bindingen ble fjernet i 1.1.4. To grunner: R5-valuesettet lot seg ikke resolve i en R4-IG, så
IG Publisher rendret `medication-ingredientstrength (??)` uten lenke. Og bindingen lå på
`value[x]` — med to tillatte typer finnes det ikke noe eget `valueCodeableConcept`-element å
binde, så den ville også ha gjeldt enhetskoden i `Quantity`-grenen. IG-en anbefaler nå kodeverk
i `comment`, slik den allerede gjør for Volven-kodeverk (jf. `form.coding[OID7448]`).

### Hvorfor extension
FHIR R5/R6 har `Medication.ingredient.strength[x]` med tre typer: `Ratio`, `CodeableConcept`,
`Quantity`. I R4 er `strength` en ren `Ratio`, og valgtyper kan ikke slices. Extensionen tilfører
de to typene R4 mangler, mens `strength` selv fortsatt bærer Ratio-varianten.

`strength` uten `numerator`/`denominator` er gyldig fordi R4-invarianten `rat-1` sier:
«Numerator and denominator SHALL both be present, or both are absent. If both are absent, there
SHALL be some extension present.»

### Bruk — mengde som volum
```
ingredient[1].itemReference = Reference(Legemiddel-MorfinKonsentrat)
ingredient[1].strength.extension[mengde].valueQuantity.value = 12.5
ingredient[1].strength.extension[mengde].valueQuantity.unit = "milliliter"
ingredient[1].strength.extension[mengde].valueQuantity.system = "http://unitsofmeasure.org"
ingredient[1].strength.extension[mengde].valueQuantity.code = #mL
```

### Bruk — kodet mengde
```
ingredient[2].itemReference = Reference(Legemiddel-NatriumkloridBBraun)
ingredient[2].strength.extension[mengde].valueCodeableConcept = $IngrediensStyrkeKoder#qs "QS"
```

### Praksisregel (fra `^description`)
Angir enten mengden virkestoff i det rekvirerte/administrerte legemidlet (f.eks. 100 mg), eller
hvilket volum av ingrediensen som er brukt for å produsere det (f.eks. 10 mL). **Når volum
benyttes** skal `ingredient.item` peke på «utgangslegemidlet» på en slik måte at dets styrke kan
utledes — ellers kan ikke mengde virkestoff og styrke i sluttproduktet beregnes. Sett også
`Medication.amount` (totalvolum) på det sammensatte legemidlet.

### Kjent QA-støy
R4-verktøy kan ikke slå opp R5-kanonikalen. Bygget gir 3 feil som er akseptert og delvis
undertrykt i `input/ignoreWarnings.txt`:
- 2 × «A definition could not be found for Canonical URL .../ValueSet/medication-ingredientstrength»
  på selve extensionen
- 1 × «No definition could be found for URL value .../CodeSystem/medication-ingredientstrength»
  på `qs`-koden i eksempelet

Bindingen er `preferred`, så dette blokkerer ikke validering av instanser. `Quantity`-varianten gir
ingen meldinger i det hele tatt.

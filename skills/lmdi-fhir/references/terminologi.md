# Terminologi — ValueSets, CodeSystems, NamingSystems

Kilder: `LMDI/input/fsh/valuesets/*.fsh`, `LMDI/input/fsh/namingsystems/*.fsh`, og innebygde valuesets i profilefiler.

## IG-metadata

Kilde: `LMDI/sushi-config.yaml`

| Felt | Verdi |
|------|-------|
| `id` | `hl7.fhir.no.lmdi` |
| `canonical` | `http://hl7.no/fhir/ig/lmdi` |
| `title` | `Legemiddeldata fra institusjon til Legemiddelregisteret` |
| `status` / `version` | `active` / `1.1.5` |
| `fhirVersion` | `4.0.1` |
| `language` | `no` (engelsk som oversettelseslag, se `oversettelser.md`) |
| `license` / `publisher` | `CC-BY-4.0` / Folkehelseinstituttet |
| `dependencies` | `hl7.fhir.uv.extensions.r4@5.2.0`, `hl7.fhir.no.basis@2.2.0` |

## ValueSets

| Id | URL / systemer inkludert | Bruk |
|---|---|---|
| `atc-valueset` | `http://fhir.no/ValueSet/atc-valueset`, inkluderer `http://www.whocc.no/atc` | Binding preferred i `LegemiddelClassification`-extension |
| `legemiddel-koder` | SCT + FEST (Merkevare, Virkestoff, Pakning, Dose) + `lmrLopenummer` + `fest-varenummer` + `lokaltLegemiddel` | Binding extensible på `Medication.code`, preferred på `Medication.ingredient.itemCodeableConcept` |
| `LokalLegemiddelkatalogValues` | `LokalLegemiddelkatalogCodeSystem` | Ikke formelt bundet — støtter lokal-katalog-identifikasjon |
| `lmdi-address-use` | `home`, `temp`, `old` fra `http://hl7.org/fhir/address-use` | Binding required på `Patient.address.use` |
| `lmdi-address-type` | `physical` fra `http://hl7.org/fhir/address-type` | Binding required på `Patient.address.type` og `Organisasjon.address.type` |
| `kommunenummer-alle` | `KommunenummerCodeSystem` (OID 3402) | Tilgjengelig for kommune-kodinger |
| `lmdi-medicationadministrationstatus` | `completed`, `entered-in-error` fra `http://terminology.hl7.org/CodeSystem/medication-admin-status` | Binding på `Legemiddeladministrering.status` (definert i `lmdi-MedicationAdministration.fsh`) |

## CodeSystems (definert lokalt)

| Id | URL | Innhold |
|---|---|---|
| `LokalLegemiddelkatalogCodeSystem` | `http://hl7.no/fhir/ig/lmdi/CodeSystem/LokalLegemiddelkatalogCodeSystem` | `metavisionkatalogFraHso`, `metavisionkatalogFraHN` |
| `kommunenummer-codesystem` | `urn:oid:2.16.578.1.12.4.1.1.3402` | `^content = #not-present` (kun definisjonsskall, faktiske koder fra Volven) |

ValueSet-URLen `LokalLegemiddelkatalogValues` er `http://hl7.no/fhir/ig/lmdi/ValueSet/LokalLegemiddelkatalogValues` (verifisert i `LMDI/fsh-generated/resources/ValueSet-LokalLegemiddelkatalogValues.json`).

## NamingSystems (definert som `Instance: ... InstanceOf: NamingSystem Usage: #definition`)

| `name` | URI | Formål |
|---|---|---|
| `festLegemiddelDose` | `http://dmp.no/fhir/NamingSystem/festLegemiddelDose` | FEST-id for dose (minste plukkbare enhet) |
| `festLegemiddelMerkevare` | `http://dmp.no/fhir/NamingSystem/festLegemiddelMerkevare` | FEST-id for merkevare (styrke + form) |
| `festLegemiddelPakning` | `http://dmp.no/fhir/NamingSystem/festLegemiddelPakning` | FEST-id for pakning (varenummer-nivå) |
| `festLegemiddelVirkestoff` | `http://dmp.no/fhir/NamingSystem/festLegemiddelVirkestoff` | FEST-id for virkestoff |
| `lmdiLokaltLegemiddel` | `http://fhi.no/fhir/NamingSystem/lokaltLegemiddel` | Lokal legemiddelkatalog (endret URL i 1.1.0) |

### NamingSystems brukt i FSH men ikke lokalt definert som `Instance`

- `http://dmp.no/fhir/NamingSystem/lmrLopenummer` — LMR-løpenummer, 7-sifret.
- `http://dmp.no/fhir/NamingSystem/fest-varenummer` — Varenummer.

Disse brukes i `code.coding`-slicing på `Legemiddel`, men har ingen egen FSH-`Instance`-definisjon i denne IG-en.

## Eksterne kodesystemer og OID-er brukt

| System / OID | Bruk |
|---|---|
| `http://snomed.info/sct` | Diagnose, Legemiddel.code, Legemiddel.form, dosage.route, Substance.code |
| `http://www.whocc.no/atc` | ATC-klassifisering på Medication |
| `urn:oid:2.16.578.1.12.4.1.1.7110` | ICD-10 |
| `http://id.who.int/icd/release/11/mms` | ICD-11 MMS |
| `urn:oid:2.16.578.1.12.4.1.1.7170` | ICPC-2 |
| `urn:oid:2.16.578.1.12.4.1.1.7448` | Legemiddelform (FEST) |
| `urn:oid:2.16.578.1.12.4.1.1.7477` | Administrasjonsvei |
| `urn:oid:2.16.578.1.12.4.1.1.3402` | Kommunenummer |
| `urn:oid:2.16.578.1.12.4.1.1.3403` | Bydelsnummer |
| `urn:oid:2.16.578.1.12.4.1.1.8624` | Organisatorisk betegnelse |
| `urn:oid:2.16.578.1.12.4.1.4.1` | Fødselsnummer |
| `urn:oid:2.16.578.1.12.4.1.4.2` | D-nummer |
| `urn:oid:2.16.578.1.12.4.1.4.4` | HPR-nummer |
| `urn:oid:2.16.578.1.12.4.1.4.101` | Organisasjonsnummer (Enhetsregisteret, ENH) |
| `urn:oid:2.16.578.1.12.4.1.4.102` | RESH-ID (RSH) |
| `http://terminology.hl7.org/CodeSystem/v3-ActCode` | Encounter.class (IMP, SS, m.fl.) |
| `http://terminology.hl7.org/CodeSystem/medication-admin-category` | MedicationAdministration.category (f.eks. `community`) |
| `http://terminology.hl7.org/CodeSystem/medicationrequest-status-reason` | MedicationRequest.statusReason (f.eks. `sdupther`) |
| `http://terminology.hl7.org/CodeSystem/medicationrequest-course-of-therapy` | MedicationRequest.courseOfTherapyType |
| `http://terminology.hl7.org/CodeSystem/medication-admin-status` | MedicationAdministration.status |
| `http://terminology.hl7.org/CodeSystem/substance-category` | Substance.category |
| `http://terminology.hl7.org/CodeSystem/condition-clinical` | Condition.clinicalStatus |
| `http://hl7.org/fhir/CodeSystem/medication-ingredientstrength` | Kodet mengde ingrediens (`qs`, `trace`) — R5-kodeverk, **anbefalt** for `lmdi-ingredient-strength` (ingen binding fra 1.1.4). Kan ikke slås opp av R4-verktøy, se `extensions.md` |
| `urn:oid:2.16.578.1.12.4.1.1.7502` | Bestanddel i legemiddelblanding uten eksakt mengde — norsk alternativ for kodet mengde, anbefalt i `^comment` på `lmdi-ingredient-strength` |

## Aliases (fra `LMDI/input/fsh/aliases.fsh`)

- `NoBasisPatient`, `NoBasisAddress`, `NoBasisOrganization`, `NoBasisSubstance` — no-basis 2.2.0-canonicals (`http://hl7.no/fhir/StructureDefinition/no-basis-*`)
- `$ATC` = `http://www.whocc.no/atc`
- `$organisatoriskBetegnelse` = `urn:oid:2.16.578.1.12.4.1.1.8624`
- `$VsLmdiUrbanDistrict` = `urn:oid:2.16.578.1.12.4.1.1.3403`
- `$kommunenummer-alle` = `urn:oid:2.16.578.1.12.4.1.1.3402`
- `$organization-type` = `http://terminology.hl7.org/CodeSystem/organization-type`
- `$LMDISubstance` = `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-substance`
- `$LMDIMedication` = `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medication`
- `$IngrediensStyrkeKoder` = `http://hl7.org/fhir/CodeSystem/medication-ingredientstrength`

## no-basis-extensions brukt i adresser (verifisert mot no-basis 2.2.0)

- `municipalitycode`: `http://hl7.no/fhir/StructureDefinition/no-basis-municipalitycode` (på `address.district`)
- `urbanDistrict`: `http://hl7.no/fhir/StructureDefinition/no-basis-urban-district` (på `address`)

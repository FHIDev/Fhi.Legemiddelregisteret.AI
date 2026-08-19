# Eksempelmønstre

Alle eksempler nedenfor er hentet fra `LMDI/input/fsh/` og kan brukes som mal. Når du genererer nye eksempler, bruk disse som utgangspunkt — det sikrer at slicing-navn, system-URI-er og invariant-krav er korrekte.

## Oversikt over `Instance`-navn per profil

| Profil | FSH-fil | Eksempelnavn |
|---|---|---|
| Pasient | `lmdi-Patient.fsh` | `Pasient-Uten-Personidentifikator`, `Pasient-Med-FNR`, `Pasient-Med-DNR` |
| Helsepersonell | `lmdi-Practitioner.fsh` | `Helsepersonell-Med-HPR`, `Helsepersonell-Uten-HPR` |
| Organisasjon | `lmdi-Organization.fsh` | `Organisasjon-Kommune`, `Organisasjon-Sykehjem`, `Organisasjon-HF`, `Organisasjon-Sykehus`, `Organisasjon-Sykehusavdeling`, `Organisasjon-HF-2`, `Organisasjon-Sykehus-2`, `Organisasjon-Seksjon`, `Organisasjon-Post` |
| Episode | `lmdi-Encounter.fsh` | `Episode-Sykehus`, `Episode-Sykehjem`, `Episode-Sykehus-2` |
| Diagnose | `lmdi-Condition.fsh` | `Diagnose-ICD10`, `Diagnose-SNOMED-SCT`, `Diagnose-ICD10-Allergi` |
| Legemiddel | `lmdi-Medication.fsh` | `Legemiddel-FestLegemiddelVirkestoff`, `Legemiddel-FestLegemiddelMerkevare`, `Legemiddel-FestLegemiddelpakning`, `Legemiddel-Varenummer`, `Legemiddel-FestLegemiddeldose`, `Legemiddel-FestLmrLopenr`, `Legemiddel-SCT`, `Legemiddel-LokaltLegemiddel-FlereIngredienser`, `Legemiddel-FestLegemiddelVirkestoff-2`, `Legemiddel-Legemiddeldose-SmofKabiven`, `Legemiddel-UtenCoding`, `Lokalt-legemiddel-cellegift`, `Legemiddel-MorfinKonsentrat`, `Legemiddel-Smerteblanding` |
| Virkestoff | `lmdi-Substance.fsh` | `Virkestoff-Oksykodon`, `Virkestoff-Natriumklorid` |
| Legemiddelrekvirering | `lmdi-MedicationRequest.fsh` | `Rekvirering-Paracetamol`, `Rekvirering-Kjemoterapi`, `Rekvirering-Infusjon`, `Rekvirering-MedDiagnoseICD10`, `Rekvirering-EnteredInError`, `Rekvirering-Cellegift` |
| Legemiddeladministrering | `lmdi-MedicationAdministration.fsh` | `Administrering-Oral`, `Administrering-Infusjon`, `Administrering-MedDiagnoseSCT`, `Administrering-MedDiagnoseICD10`, `Administrering-EnteredInError`, `Administrering-Selvadministrert`, `Administrering-Cellegift` |
| Bundle | `LegemiddelregisterBundle.fsh` | `Bundle-Scenario-Sykehjem-Oksykodon` + 8 inline-ressurser (`Scenario-Sykehjem-Oksykodon-{Pasient, Helsepersonell, Kommune, Sykehjem, Episode, Legemiddel, Rekvirering, Administrering}`, alle `Usage: #inline`) |

## Scenarier dekket av eksemplene

| Scenario | Hovedeksempel | Spesielle trekk |
|---|---|---|
| Sykehjem, oral oksykodon | `Bundle-Scenario-Sykehjem-Oksykodon` | Komplett transaction-bundle, urn:uuid-referanser |
| Selvadministrering | `Administrering-Selvadministrert` | `category = community` |
| Feilregistrering | `Administrering-EnteredInError`, `Rekvirering-EnteredInError` | `status = entered-in-error` + `statusReason` |
| Infusjon | `Administrering-Infusjon`, `Rekvirering-Infusjon` | `effectivePeriod`, `dosage.rateRatio` |
| Kjemoterapi | `Rekvirering-Kjemoterapi`, `Administrering-Cellegift` | Alle tre MedicationRequest-extensions (prosentvisDoseendring, delAvBehandlingsregime, kliniskStudie) |
| Lokalt legemiddel m/flere ingredienser | `Legemiddel-LokaltLegemiddel-FlereIngredienser` | `code.coding[LokaltLegemiddel]` + fire `ingredient`-oppføringer |
| Legemiddel uten code | `Legemiddel-UtenCoding` | Kun `ingredient` — oppfyller `lmdi-medication-code-or-ingredient` |
| Sammensatt smerteblanding | `Legemiddel-Smerteblanding` | 100 mL med morfin 5 mg/ml og midazolam 1 mg/ml. Viser alle tre måtene å angi ingrediens (`itemCodeableConcept` med FEST-varenummer, `itemReference` til Legemiddel, `itemReference` til Virkestoff) og både styrke (Ratio) og mengde (`strength.extension[mengde]`). `amount` = 100 mL/pose gjør utledningen mulig: 12,5 mL × 40 mg/ml = 500 mg → 5 mg/ml |
| Diagnose ICD-10 | `Diagnose-ICD10`, `Diagnose-ICD10-Allergi` | System `urn:oid:2.16.578.1.12.4.1.1.7110` |
| Diagnose SNOMED CT | `Diagnose-SNOMED-SCT` | |
| Organisasjonshierarki | `Organisasjon-Post` → Seksjon → Sykehus → HF | `partOf`-kjede |
| Flere NPR-identifikatorer per episode | `Episode-Sykehus` | To `nprEpisodeIdentifier`-forekomster: én med string + uuid, én med kun string (0..* fra 1.1.2) |

## Mønster 1 — Minimal Pasient

```json
{
  "resourceType": "Patient",
  "meta": { "profile": ["http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-patient"] },
  "gender": "male",
  "birthDate": "1958-05-12"
}
```

## Mønster 2 — Pasient med FNR + adresse

```json
{
  "resourceType": "Patient",
  "meta": { "profile": ["http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-patient"] },
  "identifier": [{
    "system": "urn:oid:2.16.578.1.12.4.1.4.1",
    "value": "12705825562"
  }],
  "gender": "male",
  "birthDate": "1958-05-12",
  "address": [{
    "use": "home",
    "type": "physical",
    "district": "Oslo",
    "_district": {
      "extension": [{
        "url": "http://hl7.no/fhir/StructureDefinition/no-basis-municipalitycode",
        "valueCoding": {
          "system": "urn:oid:2.16.578.1.12.4.1.1.3402",
          "code": "0301",
          "display": "Oslo"
        }
      }]
    },
    "extension": [{
      "url": "http://hl7.no/fhir/StructureDefinition/no-basis-urban-district",
      "valueCoding": {
        "system": "urn:oid:2.16.578.1.12.4.1.1.3403",
        "code": "030102",
        "display": "Grünerløkka"
      }
    }]
  }]
}
```

> Canonical-URLene er verifisert mot no-basis 2.2.0 (`node_modules/hl7.fhir.no.basis/no-basis-Address.structuredefinition-profile.json`):
> - `municipalitycode`: `http://hl7.no/fhir/StructureDefinition/no-basis-municipalitycode`
> - `urbanDistrict` (sliceName), canonical: `http://hl7.no/fhir/StructureDefinition/no-basis-urban-district`
>
> FSH-bruken er `address.district.extension[municipalitycode]` og `address.extension[urbanDistrict]` (slicename, ikke URL).

## Mønster 3 — Legemiddel med FEST-virkestoff + ATC

```json
{
  "resourceType": "Medication",
  "meta": { "profile": ["http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medication"] },
  "extension": [{
    "url": "http://hl7.no/fhir/ig/lmdi/StructureDefinition/legemiddel-classification",
    "valueCodeableConcept": {
      "coding": [{
        "system": "http://www.whocc.no/atc",
        "code": "N02AA05",
        "display": "Oksykodon"
      }]
    }
  }],
  "code": {
    "coding": [{
      "system": "http://dmp.no/fhir/NamingSystem/festLegemiddelVirkestoff",
      "code": "ID_128B21F2-34CE-4FEF-81CA-AD3BD9A5690E",
      "display": "Oksykodon mikst oppl 1 mg/ml"
    }]
  },
  "form": {
    "coding": [{
      "system": "urn:oid:2.16.578.1.12.4.1.1.7448",
      "code": "842",
      "display": "Mikstur, oppløsning"
    }]
  }
}
```

## Mønster 4 — MedicationAdministration i bundle (inline)

```json
{
  "resourceType": "MedicationAdministration",
  "meta": { "profile": ["http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medicationadministration"] },
  "status": "completed",
  "medicationReference": { "reference": "urn:uuid:66666666-6666-4666-8666-666666666666" },
  "subject":             { "reference": "urn:uuid:11111111-1111-4111-8111-111111111111" },
  "context":             { "reference": "urn:uuid:55555555-5555-4555-8555-555555555555" },
  "request":             { "reference": "urn:uuid:77777777-7777-4777-8777-777777777777" },
  "effectiveDateTime": "2024-05-28T09:30:00+02:00",
  "dosage": {
    "route": {
      "coding": [{
        "system": "http://snomed.info/sct",
        "code": "421521009",
        "display": "Swallow"
      }]
    },
    "dose": {
      "value": 10.0,
      "unit": "mg",
      "system": "http://unitsofmeasure.org",
      "code": "mg"
    }
  }
}
```

## Mønster 5 — MedicationRequest m/kjemo-extensions

```json
{
  "resourceType": "MedicationRequest",
  "meta": { "profile": ["http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medicationrequest"] },
  "extension": [
    {
      "url": "http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-prosentvis-doseendring",
      "valueQuantity": { "value": 80, "system": "http://unitsofmeasure.org", "code": "%", "unit": "%" }
    },
    {
      "url": "http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-del-av-behandlingsregime",
      "valueString": "FOLFOX6"
    },
    {
      "url": "http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-klinisk-studie",
      "valueBoolean": true
    }
  ],
  "status": "active",
  "intent": "order",
  "medicationReference": { "reference": "urn:uuid:..." },
  "subject":             { "reference": "urn:uuid:..." },
  "requester":           { "reference": "urn:uuid:..." },
  "authoredOn": "2025-03-10"
}
```

## Generer nytt eksempel — oppskrift

1. Velg eksisterende FSH-eksempel som er nærmest scenarioet.
2. Kopier strukturen; bytt ut verdier.
3. Sett `meta.profile` eksplisitt hvis eksempelet skal være standalone JSON.
4. For bundle-eksempler: bruk `urn:uuid:<v4>`-mønster konsekvent.
5. Merk utdata med: `"Manuelt utledet basert på profil — ikke maskinelt validert."` hvis SUSHI / endepunkt ikke er kjørt.

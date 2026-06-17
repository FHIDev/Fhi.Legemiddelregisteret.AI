# Validering og invariants

Kilde: alle `Invariant:`-blokker i `LMDI/input/fsh/profiles/*.fsh` og `LMDI/input/fsh/extensions/*.fsh`.

## Invariants (alle `Severity: #error`)

### `lr-allowed-resources`
**Sted**: `LegemiddelregisterBundle` (applied på rot).
**Formål**: Begrense bundle til ni LMDI-profiler.
**FHIRPath**: `entry.all(resource.meta.profile.where(...).exists() or ...)` — én OR-klausul per tillatt canonical-URL.
**Feilsøking**: Hver entry må ha `meta.profile` som nøyaktig matcher en av:
```
http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-condition
http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-practitioner
http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-encounter
http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medication
http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medicationadministration
http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medicationrequest
http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-organization
http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-patient
http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-substance
```

### `lmdi-org-identifier`
**Sted**: `Organisasjon`.
**FHIRPath**: `identifier.where(system='urn:oid:2.16.578.1.12.4.1.4.101' or system='urn:oid:2.16.578.1.12.4.1.4.102').exists()`.
**Regel**: Organisasjonen må ha minst ett organisasjonsnummer (ENH) eller RESH-ID (RSH).

### `lmdi-medication-code-or-ingredient`
**Sted**: `Legemiddel`.
**FHIRPath**: `code.coding.exists() or ingredient.exists()`.
**Regel**: Enten `code.coding` eller `ingredient` må ha verdi. Begge er tillatt samtidig.

### `time-required`
**Sted**: `Legemiddeladministrering.effectiveDateTime`, `effectivePeriod.start`, `effectivePeriod.end`.
**FHIRPath**: `$this.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}.*$')`.
**Regel**: Tidsangivelse må ha presisjon **ned til minutt**. `"2024-05-28"` alene er ikke godtatt.

### `npr-episode-at-least-one`
**Sted**: `NprEpisodeIdentifier`-extension (brukt på Episode).
**FHIRPath**: `extension('stringIdentifier').exists() or extension('uuidIdentifier').exists()`.
**Regel**: Må ha minst én av sub-extensions.

---

## Profilbaserte "implisitte" regler

Disse er ikke invariants, men tvinges gjennom kardinalitet, `only`-klausuler og `0..0`-deaktiveringer.

### Referansemål (`only Reference(...)`)

| Fra | Felt | Må peke på |
|---|---|---|
| Legemiddeladministrering | `subject` | Pasient |
| Legemiddeladministrering | `medication[x]` | Legemiddel |
| Legemiddeladministrering | `context` | Episode |
| Legemiddeladministrering | `request` | Legemiddelrekvirering |
| Legemiddeladministrering | `reasonReference` | Diagnose |
| Legemiddelrekvirering | `subject` | Pasient |
| Legemiddelrekvirering | `requester` | Helsepersonell |
| Legemiddelrekvirering | `medication[x]` | Legemiddel |
| Legemiddelrekvirering | `encounter` | Episode |
| Legemiddelrekvirering | `reasonReference` | Diagnose |
| Legemiddelrekvirering | `priorPrescription` | Legemiddelrekvirering |
| Episode | `serviceProvider` | Organisasjon |
| Diagnose | `subject` | Pasient |
| Organisasjon | `partOf` | Organisasjon |
| Legemiddel | `ingredient.itemReference` | Virkestoff \| Legemiddel |

### Absolutte `0..0`-deaktiveringer (utdrag; se `profiler.md` for komplett liste)

- Ingen `Patient.name`, `Patient.telecom`, `Patient.photo`, `Patient.address.line`, `Patient.address.postalCode`, `Patient.address.city`.
- Ingen `Practitioner.name`, `Practitioner.address`, `Practitioner.qualification`.
- Ingen `Encounter.subject`, `Encounter.participant`, `Encounter.period`, `Encounter.location` m.fl.
- Ingen `Condition.encounter`, `Condition.category`, `Condition.note`.
- Ingen `MedicationRequest.note`, `dispenseRequest`, `performer`, `dosageInstruction.text`, `dosageInstruction.patientInstruction`.
- Ingen `MedicationAdministration.note`, `performer`, `device`.
- Ingen `Organization.telecom`, `Organization.contact`, `Organization.address.line/city/postalCode/country`.

### Fikse verdier

- `LegemiddelregisterBundle.type = #transaction`
- `LegemiddelregisterBundle.entry.request.method = #POST`
- `Pasient.address.type = #physical`
- `Organisasjon.address.type = #physical`

### Required-bindinger

- `Pasient.address.use` fra `LmdiAddressUse` (home|temp|old)
- `Pasient.address.type` og `Organisasjon.address.type` fra `LmdiAddressType` (physical)
- `Legemiddeladministrering.status` fra `LegemiddeladministreringStatus` (completed|entered-in-error)
- `Legemiddeladministrering.dosage.route.coding[SCT].code` fra `http://hl7.org/fhir/ValueSet/route-codes`
- `Legemiddelrekvirering.status` fra `http://hl7.org/fhir/ValueSet/medicationrequest-status`

---

## Manuell valideringssjekkliste

### Per ressurs
1. `resourceType` = profilens base (`MedicationAdministration`, `Patient`, ...).
2. `meta.profile`:
   - **I bundle**: påkrevd i praksis — invariant `lr-allowed-resources` krever at hver `entry.resource.meta.profile` matcher en LMDI-canonical.
   - **Standalone JSON**: sterkt anbefalt (gjør profiltilhørighet eksplisitt), men ikke håndhevet av en LMDI-invariant. En validator som får profilen som argument kan fortsatt validere, men praksis er å sette `meta.profile`.
3. Alle påkrevde felter satt (1..1, 1..*).
4. Ingen felter med `0..0` er inkludert.
5. Codings har riktig `system` for sin slice (lukket slicing betyr: ingen andre systems tillatt).
6. Bindinger respektert (required → valueset; extensible → ellers begrunnet; preferred → kan avvike).
7. Invariants som gjelder er oppfylt.
8. Hver extension bruker LMDI-canonical på `url`.

### Per bundle
1. `type = "transaction"`.
2. `identifier`, `timestamp`, `type` finnes; `total` og `link` finnes ikke.
3. Alle entries har `request.method = "POST"` og `request.url` (verdi fri).
4. `entry.fullUrl` unik og brukt konsistent i referanser.
5. Alle interne referanser (urn:uuid) matcher en `entry.fullUrl`.
6. Alle `entry.resource.meta.profile` matcher en av de ni LMDI-canonicals.
7. Ingen dangling / ubrukte ressurser (ressurser som ikke refereres til av noen andre — vanligvis en feil).

---

## Maskinell validering

Ikke primærmetode, men:

1. **SUSHI** — bruk repo-relativ sti:
   ```bash
   ROOT="$(git rev-parse --show-toplevel)"
   cd "$ROOT/LMDI" && sushi .
   ```
   Gir build-feil hvis FSH-eksempler er ugyldige, men ikke runtime-validering av fremmed JSON.

2. **IG Publisher** — full QA-rapport:
   ```bash
   ROOT="$(git rev-parse --show-toplevel)"
   java -jar "$ROOT/publisher/publisher.jar" -ig "$ROOT/LMDI/ig.ini" -generate
   ```
   Genererer `LMDI/output/qa.html` med alle feil og advarsler.

3. **FHI test-endepunkt (ukryptert)**:
   ```
   POST https://test-fhirmottak.lmr.fhi.no/fhirmottak/v1/validateLegemiddelregisterBundle
   Content-Type: application/json
   ```
   Returnerer 200 + `OperationOutcome` eller 400. Ikke autentisert, lagrer ingen data.

4. **FHI test-endepunkt (signert/kryptert)**:
   ```
   POST https://test-fhirmottak.lmr.fhi.no/fhirmottak/v1/validate
   ```
   Krever Maskinporten (scope `fhi:lmr/fhirmottak.api`). Validerer også krypto + signatur.

Når du foreslår at brukeren kjører validering, inkluder URL og forventet respons.

---

## Feilsøking (vanlige feil)

| Symptom | Sannsynlig årsak | Rettelse |
|---|---|---|
| `lr-allowed-resources` feiler | Mangler `meta.profile` på `entry.resource` | Legg til riktig LMDI-canonical |
| `lmdi-org-identifier` feiler | Organisasjon har bare f.eks. `HER-ID` | Legg til ENH (org.nr) eller RSH |
| `lmdi-medication-code-or-ingredient` feiler | Tomt `code` + tomt `ingredient` | Legg til enten `code.coding` eller `ingredient` (eller begge) |
| `time-required` feiler | `effectiveDateTime = "2024-05-28"` | Bruk minst `"2024-05-28T09:30:00+02:00"` |
| `npr-episode-at-least-one` feiler | Tom `nprEpisodeIdentifier`-forekomst | Sett `stringIdentifier` og/eller `uuidIdentifier` i hver forekomst |
| Referanse finnes ikke | `urn:uuid:...` i Reference matcher ikke noen `fullUrl` | Sjekk konsistens mellom `entry[n].fullUrl` og `Reference.reference` |
| Dangling `request` fra administrering | Glemt rekvirering i bundle | Enten legg til `Legemiddelrekvirering`-entry, eller fjern `request`-feltet |
| `status` avvises på Legemiddeladministrering | Brukt f.eks. `in-progress` | Kun `completed` og `entered-in-error` er tillatt (`LegemiddeladministreringStatus`) |
| `address.use` avvises på Pasient | Brukt `work`, `billing`, `mobile` | Kun `home`, `temp`, `old` er tillatt (`LmdiAddressUse`) |
| `address.type` avvises | Brukt `postal` eller `both` | Må være `physical` (`LmdiAddressType`) |
| `dosage.route.coding[X].code` mangler | Glemt å sette kode når slice brukes | `code 1..1` er påkrevd per slice (SCT, OID7477) |
| Ukjent URL for lokaltLegemiddel | Bruker gammel URL `fh.no/lokaltVirkemiddel` | Oppdater til `http://fhi.no/fhir/NamingSystem/lokaltLegemiddel` (breaking change i 1.1.0) |
| `organisatoriskNiva` avvises | Deaktivert i 1.1.0 (`0..0`, kodeverket OID 8628 utgått) | Bruk `organisatoriskBetegnelse` i stedet |
| `stage` uten `summary` | `stage.summary 1..1` i Diagnose | Enten sett `stage.summary`, eller la være å bruke `stage` |
| `code[ATC]` virker ikke på Medication | ATC settes ikke på `code`, men på extension | Bruk `extension[classification].valueCodeableConcept = $ATC#...` |

# Validering og invariants

Kilde: alle `Invariant:`-blokker i `LMDI/input/fsh/profiles/*.fsh` og `LMDI/input/fsh/extensions/*.fsh`.
FHIRPath-uttrykkene står ordrett i den genererte `struktur.md`.

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

## Base-invariant som er lett å trå feil på: `rat-1`

**Sted**: R4-datatypen `Ratio` — gjelder blant annet `Medication.ingredient.strength` og
`Medication.amount`. Ikke definert i LMDI, men avgjørende når mengde uttrykkes med
`strength.extension[mengde]` (se `extensions.md`).

**FHIRPath**: `(numerator.empty() xor denominator.exists()) and (numerator.exists() or extension.exists())`

**Regel**: Teller og nevner skal enten begge finnes eller begge mangle. Mangler begge, **skal** det
finnes minst én extension. Det er derfor gyldig å skrive `strength` med bare
`extension[mengde].valueQuantity` og uten `numerator`/`denominator` — men **ikke** å oppgi bare
`numerator` uten `denominator`.

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
| Legemiddeladministrering | `extension[administrertVed].valueReference` | Organisasjon |
| Legemiddelrekvirering | `subject` | Pasient |
| Legemiddelrekvirering | `requester` | Helsepersonell |
| Legemiddelrekvirering | `medication[x]` | Legemiddel |
| Legemiddelrekvirering | `encounter` | Episode |
| Legemiddelrekvirering | `reasonReference` | Diagnose |
| Legemiddelrekvirering | `priorPrescription` | Legemiddelrekvirering |
| Legemiddelrekvirering | `extension[rekvirertVed].valueReference` | Organisasjon |
| Episode | `serviceProvider` | Organisasjon |
| Diagnose | `subject` | Pasient |
| Organisasjon | `partOf` | Organisasjon |
| Legemiddel | `ingredient.itemReference` | Virkestoff \| Legemiddel |

Målet for `administrertVed`/`rekvirertVed` (fra 1.1.8) håndheves gjennom extension-definisjonen (`value[x] only Reference(Organisasjon)`), ikke profilen. Firely-validatoren uten 1.1.8-extensionene lastet (observert i FhirMottak med 1.1.7-profiler) gir bare advarselen «Unable to resolve reference to extension» og sjekker ikke målet. En bundle som bruker extensionene, passerer altså også mot 1.1.7.

`Legemiddelrekvirering.requester` er 0..1 MS fra IG 1.1.3. Referansemålet Helsepersonell valideres når feltet finnes; feltet kan utelates når rekvirenten ikke er kjent.

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
7. Ingen ubrukte støtteressurser. En Pasient, Episode, Organisasjon, Diagnose, Helsepersonell, Virkestoff eller et Legemiddel som ingen andre ressurser peker på, er vanligvis en feil. Legemiddeladministrering er roten og refereres aldri av andre. En Legemiddelrekvirering kan stå alene når legemidlet er rekvirert, men ikke administrert.

---

## Maskinell validering

### For avsendere: FHI sine testendepunkter

1. **Ukryptert bundle**. Krever ikke autentisering, avsender trenger ikke være registrert, og ingenting lagres:
   ```bash
   curl -sS -X POST "https://test-fhirmottak.lmr.fhi.no/fhirmottak/v1/validateLegemiddelregisterBundle" \
     -H "Content-Type: application/json" --data-binary @bundle.json
   ```
   400 = feil funnet. Valideringsfeil kommer som `OperationOutcome`. Lar ikke bundelen seg
   deserialisere (ugyldig JSON, eller en verdi utenfor FHIR sitt eget kodesett i et `code`-felt, f.eks.
   `status = "tull"`), er svaret en tekststreng.
   200 = ingen feil funnet i det endepunktet kontrollerer, med en tom `OperationOutcome`. Det er
   **ikke** det samme som at bundelen er gyldig, se under.
   Prøv først med `assets/Bundle-Scenario-Sykehjem-Oksykodon.json` for å se at kallet virker (se forbeholdet om `dosage.route` i `eksempler.md`).

   **Hva endepunktet kontrollerer** (observert 2026-11-10 med eksempelbundelen og innlagte feil):

   | Feil lagt inn | Svar |
   |---|---|
   | `note` satt på Legemiddeladministrering (`0..0`) | 400, kardinalitet |
   | `effectiveDateTime = "2024-05-28"` | 400, invariant `time-required` |
   | `Pasient.address.type = "postal"` | 400, fast verdi |
   | Ukjent `system` i `dosage.route.coding` | 400, lukket slicing |
   | Oppdiktet SNOMED CT-kode i `dosage.route.coding[SCT]` (required, `route-codes`) | **200** |
   | `status = "in-progress"` (required, `LegemiddeladministreringStatus`) | **200** |
   | `Pasient.address.use = "work"` (required, `LmdiAddressUse`) | **200** |

   Endepunktet validerer altså struktur, kardinalitet, faste verdier, slicing og invarianter, men
   ikke terminologi: koder sjekkes ikke mot valuesettene, verken eksterne kodeverk eller LMDI sine
   egne. Bindingene må kontrolleres separat, manuelt mot «Required-bindinger» over og
   `terminologi.md`, eller med en validator som har terminologitjener (IG Publisher eller
   HL7-validatoren for den som har LMDI-repoet). Radene om `status` og `address.use` i
   feilsøkingstabellen under gjelder slik validering. Testendepunktet rapporterer dem ikke. Om
   mottaket i produksjon håndhever bindingene, er ikke undersøkt.

   **Bare syntetiske data.** Endepunktet lagrer ikke, men en bundle med ekte pasientopplysninger skal
   likevel ikke sendes ukryptert til et testmiljø.

2. **Signert og kryptert konvolutt**:
   ```
   POST https://test-fhirmottak.lmr.fhi.no/fhirmottak/v1/validate
   ```
   Krever Maskinporten (scope `fhi:lmr/fhirmottak.api`) og at avsender er registrert og aktiv. Validerer
   krypto, signatur og innholdet. 200 = ingen feil funnet, 400 = feil. Lagrer ikke. Ikke undersøkt om
   terminologi kontrolleres her. Gå ut fra samme begrensning som for den ukrypterte varianten.

Når du foreslår at brukeren kjører validering, inkluder kommandoen og forventet respons.

### Hvilken IG-versjon validerer mottaket mot?

IG-en sier ikke hvilken versjon av profilene FhirMottak har lastet i test og produksjon, og skillen vet
det ikke. Mottaket kan ligge bak siste IG-versjon: da skillen ble oppdatert til 1.1.8 (oktober 2026), ble
FhirMottak observert med 1.1.7-profilene.

Konsekvenser for avsender:
- Bruk av noe som er **nytt** i en IG-versjon, kan gi advarsel i stedet for validering (se
  `administrertVed`/`rekvirertVed` over).
- Noe som er **lempet på** i en nyere IG-versjon (f.eks. Organisasjon uten ENH/RSH fra 1.1.9, flere
  ICD-10-koder fra 1.1.7), kan fortsatt bli avvist av et mottak på eldre versjon.

Er svaret versjonsavhengig, si det, og anbefal å validere mot testendepunktet eller å spørre FHI
hvilken versjon som gjelder i miljøet.

### For den som vedlikeholder IG-en (krever LMDI-repoet)

- **SUSHI**: `cd LMDI && sushi .` gir byggefeil hvis FSH-eksempler er ugyldige. Validerer ikke fremmed JSON.
- **IG Publisher**: `java -jar publisher.jar -ig LMDI/ig.ini -generate` gir full QA-rapport i `LMDI/output/qa.html`.

---

## Feilsøking (vanlige feil)

| Symptom | Sannsynlig årsak | Rettelse |
|---|---|---|
| `lr-allowed-resources` feiler | Mangler `meta.profile` på `entry.resource` | Legg til riktig LMDI-canonical |
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
| «The declared type of the element (Organization) is incompatible with that of the instance (...)» | `administrertVed`/`rekvirertVed` peker på noe annet enn en Organisasjon | La `valueReference` peke på en `Organization`-entry (posten), ikke episoden eller pasienten |

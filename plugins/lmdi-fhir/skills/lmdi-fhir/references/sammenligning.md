# Profilsammenligning — X vs Y

Dette dokumentet svarer på konkrete "når bruker jeg X og ikke Y?"-spørsmål. Reglene kommer fra FSH-filene i `LMDI/input/fsh/profiles/` og `only Reference(...)`-bindingene som finnes i profilene.

## 1. MedicationRequest vs MedicationAdministration

| Dimensjon | Legemiddelrekvirering (`lmdi-medicationrequest`) | Legemiddeladministrering (`lmdi-medicationadministration`) |
|---|---|---|
| Hva representerer den | Ordinering / rekvirering av legemiddel | Faktisk utført administrering av en dose |
| Rolle i LMDI | Referanse-ressurs (årsaken til en administrering) | **Kjerneressursen** — det er administreringen som er meldt til LMR |
| Obligatorisk i bundle? | Nei i FHIR-spec, men ja i praksis hvis `MedicationAdministration.request` settes | Ja, for hver administrert dose |
| `status` | Fra standard VS `medicationrequest-status` (f.eks. `active`, `entered-in-error`) | Begrenset til `completed` eller `entered-in-error` (`LegemiddeladministreringStatus`) |
| Tidsfelt | `authoredOn` (dateTime) | `effectiveDateTime` eller `effectivePeriod`, invariant `time-required` ned til minutt |
| Dose-representasjon | `dosageInstruction.dose*` (plan) | `dosage.dose` (faktisk gitt) + `dosage.rateRatio` for infusjon |
| Hvem utførte | `requester 0..1 MS only Reference(Helsepersonell)` — oppgis når rekvirenten er kjent | `performer` er **deaktivert** (`0..0`) — hvem som administrerte loggføres ikke |
| Indikasjon | `reasonReference only Reference(Diagnose)` | `reasonReference only Reference(Diagnose)` |
| Relasjoner seg imellom | — | `MedicationAdministration.request only Reference(Legemiddelrekvirering)` kobler administreringen til sin ordinering |

**Kort regel**: Hvis noen har skrevet ut / ordinert = `MedicationRequest`. Hvis noen har gitt en dose = `MedicationAdministration`. For én og samme kur som både er ordinert og gitt, trenger du begge, koblet via `request`-referansen.

## 2. Medication vs Substance

| Dimensjon | Legemiddel (`lmdi-medication`) | Virkestoff (`lmdi-substance`) |
|---|---|---|
| Hva representerer den | Et ferdig produkt, en pakning, en dose, en merkevare — eller et lokalt legemiddel | Et rent kjemisk virkestoff (parent: `NoBasisSubstance`) |
| Kodesystemer | FEST (Merkevare / Virkestoff / Pakning / Dose), Varenummer, LMR-løpenummer, SNOMED CT, lokalt legemiddel | SNOMED CT, evt. andre stoff-kodesystemer |
| ATC | Via `extension[classification]` (0..*) — kan gi flere ATC per produkt | Nei (settes ikke på Substance i LMDI) |
| `ingredient` | Ja, `0..*`. `itemReference` kan peke til **Virkestoff eller annet Legemiddel** (sammensatte produkter) | Nei (`ingredient 0..0` i Virkestoff) |
| Invariant | `lmdi-medication-code-or-ingredient`: enten `code` eller `ingredient` må være satt | `category 1..1` |
| Når brukes den | Alltid — det er dette `MedicationAdministration.medicationReference` peker på | Bare når du trenger å referere til et rent virkestoff (typisk som `Medication.ingredient.itemReference`) |

**Kort regel**: Det du administrerer = `Legemiddel`. Har du oppskalert lokalt legemiddel med flere virkestoffer, opprett egne `Virkestoff`-instanser og referer til dem fra `Legemiddel.ingredient.itemReference`.

## 3. Encounter vs Organization

| Dimensjon | Episode (`lmdi-encounter`) | Organisasjon (`lmdi-organization`) |
|---|---|---|
| Hva representerer den | Et opphold / en episode i institusjonen (f.eks. innleggelse, dagopphold, sykehjemsopphold) | Organisatorisk enhet (HF, sykehus, avdeling, seksjon, post, sykehjem) |
| Levetid | Tidsbegrenset (episode) — selv om `period` er deaktivert i LMDI | Permanent (strukturell) |
| Identifikator | `NprEpisodeIdentifier`-extension (string eller uuid) | ENH (org.nr) eller RSH (håndhevet av `lmdi-org-identifier`) |
| Hierarki | Nei — episoder relateres ikke til hverandre | Ja — `partOf only Reference(Organisasjon)` danner HF → Sykehus → Avdeling → Seksjon → Post |
| Kobling | `serviceProvider only Reference(Organisasjon)` — hvilken org der episoden foregår | Refereres fra `Encounter.serviceProvider`, `partOf` (seg selv) |

**Kort regel**: "Hvor" = Organisasjon. "Når / under hvilket opphold" = Episode. Episoden peker på organisasjonen via `serviceProvider`.

## 4. reasonCode vs reasonReference

Begge finnes på `MedicationAdministration` og `MedicationRequest` i FHIR-standard. I LMDI:

| Felt | Status i LMDI |
|---|---|
| `reasonCode` | Ikke eksplisitt begrenset (arvet fra FHIR-base) — kan brukes for enkelt kodet indikasjon |
| `reasonReference` | Begrenset via `only Reference(Diagnose)` — peker på en `lmdi-condition`-ressurs |

**Kort regel**: Når du har en strukturert diagnose (ICD-10, SNOMED CT etc.) som ligger som `Condition` i samme bundle → bruk `reasonReference`. Hvis du bare har en fritt kodet årsak uten egen `Condition`-ressurs → `reasonCode` er akseptabelt, men mindre informativt for LMR. Foretrukket mønster i LMDI er `reasonReference` til en `Diagnose`.

## 5. `Medication.code` vs `Medication.ingredient`

Begge er tillatt samtidig. Invariant `lmdi-medication-code-or-ingredient` krever at minst én er satt.

| Scenario | Sett `code.coding` | Sett `ingredient` |
|---|---|---|
| FEST-legemiddel (merkevare, virkestoff, pakning, dose) | Ja, med riktig FEST-slice + ATC-extension | Valgfritt |
| Lokalt legemiddel (f.eks. Metavision-katalog) | Ja, slice `LokaltLegemiddel` med `display 1..1` | Anbefalt når blanding av flere virkestoffer |
| SNOMED CT-kodet legemiddel | Ja, slice `SCT` | Valgfritt |
| Cellegift / lokal blanding uten offisiell kode | Valgfritt (hopp over `code`) | Påkrevd — referer til flere `Virkestoff`-ressurser |
| Kun virkestoffsammensetning kjent | Nei (kan droppes) | Påkrevd |

**Kort regel**: Har du en offisiell kode (FEST, varenummer, SCT, lokal katalog) → bruk `code`. Har du ikke kode men vet hvilke virkestoffer som inngår → bruk `ingredient`. Har du begge deler → sett begge.

## 5b. `strength` (styrke) vs `strength.extension[mengde]` (mengde)

Begge sitter på `Medication.ingredient.strength`. Detaljer i `extensions.md` og `validering.md` (`rat-1`).

| Spørsmålet du svarer på | Bruk | Form |
|---|---|---|
| «Hvor sterk er ingrediensen i sluttproduktet?» | `strength` (Ratio) | `numerator` + `denominator`, f.eks. 5 mg / 1 mL |
| «Hvor mye av utgangslegemidlet gikk med?» | `strength.extension[mengde].valueQuantity` | Volum eller masse, f.eks. 12,5 mL |
| «Fylt opp til, sporbar mengde» | `strength.extension[mengde].valueCodeableConcept` | `qs` eller `trace` |

**Kort regel**: Vet du konsentrasjonen i blandingen → `strength` som Ratio. Vet du bare hvor mye
konsentrat som ble tilsatt → `extension[mengde]` med volum, la `ingredient.item` peke på
utgangslegemidlet, og sett `Medication.amount` slik at konsentrasjonen kan regnes ut. Ikke press
mengde inn i en Ratio med kunstig nevner — det er semantisk feil.

## 6. `MedicationRequest.priorPrescription` vs nytt `MedicationRequest`

- `priorPrescription only Reference(Legemiddelrekvirering)` brukes når én rekvirering erstatter eller fortsetter en tidligere.
- Brukes **ikke** rutinemessig ved hver ny administrering. Hver administrering peker på sin egen rekvirering via `MedicationAdministration.request`.

## 7. `effectiveDateTime` vs `effectivePeriod` (MedicationAdministration)

Begge er tillatt via `effective[x]`, men invariant `time-required` gjelder begge.

| Bruk `effectiveDateTime` når | Bruk `effectivePeriod` når |
|---|---|
| Ett øyeblikksgitt inntak (tablett svelget kl 09:30) | Infusjon, drypp, eller administrering som varer over tid |
| Raskt inngitt injeksjon | `effectivePeriod.start` og `effectivePeriod.end` er begge `1..1` |

For infusjon, kombinér `effectivePeriod` med `dosage.rateRatio` for strømningshastighet.

## 8. Praktisk beslutningsregel — "trenger jeg en Virkestoff-ressurs?"

1. Er legemidlet kjent i FEST med virkestoff-ID? → Nei, bruk `Medication.code.coding[FestLegemiddelVirkestoff]`.
2. Er det en lokal blanding / cellegift / intern katalog der hver ingrediens er et identifiserbart virkestoff? → Ja, opprett `Virkestoff`-ressurser og referer via `Medication.ingredient.itemReference`.
3. Vil du kun oppgi virkestoffnavn som fri kode? → Nei, bruk `Medication.ingredient.itemCodeableConcept` (preferred binding til `LegemiddelKoder`).

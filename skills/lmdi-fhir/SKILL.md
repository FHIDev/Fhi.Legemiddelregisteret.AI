---
name: lmdi-fhir
description: Kildebasert ekspert på LMDI-implementasjonsguiden (Legemiddeldata fra institusjon til Legemiddelregisteret). Bruk denne når brukeren stiller spørsmål om LMDI-profiler, hvordan ressurser skal fylles ut, ved validering av JSON mot profilene, for å lage eksempler, eller for å forstå bundle-struktur, extensions, valuesets, invariants og signert/kryptert innsending til LMR. Selvstendig: bygger på et kuratert øyeblikksbilde av LMDI-kildene i `references/` — versjon 1.1.4.
---

# LMDI – Legemiddeldata fra institusjon til Legemiddelregisteret

Arbeidsinstruks og navigasjon for LMDI-spørsmål. Faktainnhold ligger i `references/` — det autoritative grunnlaget for skillen. Skillen er selvstendig og krever ikke tilgang til LMDI-repoet for å svare.

**Grunnlag**: `references/` er et kuratert øyeblikksbilde av LMDI-kildene (FSH-filer, `sushi-config.yaml`, `pagecontent/*.md`). Opprinnelig opphav er repoet [`folkehelseinstituttet/LMDI`](https://github.com/folkehelseinstituttet/LMDI), men det trengs bare ved verifisering (§1.3) eller versjonssjekk (§1.4).

**Versjon**: IG `1.1.4` (FHIR `4.0.1`), bygd fra commit `1f597673e`. Sjekk for nyere versjon ved behov — se §1.4.

---

## 1. Hvordan jobbe med LMDI-spørsmål

### 1.1 Svarprinsipper

- **Aldri gjett.** Hvis noe ikke kan utledes fra kildene, si det eksplisitt.
- **Skill tydelig mellom tre kildelag** i svaret:
  - `[LMDI-profilkrav]` — normativ regel fra en LMDI-profil (gjengitt i `references/`, opphav FSH).
  - `[LMDI-praksis]` — anbefaling fra pagecontent eller FSH-kommentarer (`^comment`, `^short`), gjengitt i `references/`.
  - `[FHIR-basis, ikke LMDI-spesifikt]` — generell FHIR R4-regel som LMDI ikke eksplisitt dekker.
- Referer til konkrete steder: referansefil (f.eks. `references/profiler.md`) eller, når kjent, FSH-fil og linje (f.eks. `lmdi-Medication.fsh:491`).
- Bruk **eksakte profilnavn** (FSH-title + id). Canonical-URL-er gjengis uendret.
- Svar på samme språk som brukeren. Tekniske navn beholdes (`Legemiddeladministrering`, `MustSupport`).

### 1.2 Prioritert kilderekkefølge ved konflikt

1. Denne skillens `references/` — autoritativt grunnlag (øyeblikksbilde av LMDI 1.1.4).
2. Verifisering mot opprinnelig kilde **når det trengs** (uklarhet, eller mistanke om at `references/` er utdatert) — se §1.3/§1.4.
3. `[FHIR-basis]`: generell FHIR R4 (spec/no-basis) for det LMDI ikke dekker.

### 1.3 Strukturdetaljer (kardinalitet, invariants, slicing, binding, `only Reference(...)`)

Svar fra `references/` (`profiler.md`, `validering.md`, m.fl.) — de er laget nettopp for dette, og er autoritative for skillen. Verifiser mot opprinnelig kilde **bare** når svaret er tvilsomt eller brukeren ber om kildebekreftelse:

- Hvis LMDI-repoet finnes lokalt: les den relevante FSH-fila der.
- Ellers (valgfritt): hent fila fra raw-URL pinnet til 1.1.4 (se §1.4).

Finner du avvik mellom `references/` og kilden: **si det til brukeren** og følg `UPDATE.md`.

### 1.4 Kilder og versjonssjekk

`references/` er bygd fra LMDI 1.1.4 (commit `1f597673e`). LMDI-repoet trengs ikke for å svare.

**Sjekk for nyere IG-versjon** (ved tvil eller på forespørsel) — hent `version:` fra kilden og sammenlign med `1.1.4`:

```
https://raw.githubusercontent.com/folkehelseinstituttet/LMDI/main/LMDI/sushi-config.yaml
```

Er versjonen på `main` nyere enn `1.1.4`: **fortell brukeren** at skillen kan være utdatert og bør oppdateres etter `UPDATE.md`.

**Verifisere en strukturdetalj mot kilden** (valgfritt, §1.3) — les FSH lokalt hvis LMDI-repoet finnes, ellers hent fila pinnet til samme versjon som `references/`:

```
https://raw.githubusercontent.com/folkehelseinstituttet/LMDI/1f597673ed5e2dbb8caf7a16541bfcd40e40f44a/LMDI/input/fsh/
```

---

## 2. Domeneoversikt og navigasjon

LMDI overfører **rekvirering** og **administrering** av legemidler fra institusjoner (sykehus, sykehjem, kommunale tjenester) til Legemiddelregisteret (LMR) hos FHI. Daglig overføring, kun endringer siden sist. Data pakkes i en `SignertKryptertBundle`-JSON-konvolutt og sendes via Maskinporten-sikret API.

**Ni FHIR-profiler** + én **bundle-profil**:

| Profil (Title) | Id | Rolle |
|---|---|---|
| Pasient | `lmdi-patient` | Hvem fikk legemidlet |
| Helsepersonell | `lmdi-practitioner` | Hvem rekvirerte |
| Organisasjon | `lmdi-organization` | Hvor (hierarkisk) |
| Episode | `lmdi-encounter` | Opphold/konsultasjon |
| Diagnose | `lmdi-condition` | Indikasjon |
| Legemiddel | `lmdi-medication` | Produkt/virkestoff som ble gitt |
| Virkestoff | `lmdi-substance` | Rent virkestoff (valgfritt) |
| Legemiddelrekvirering | `lmdi-medicationrequest` | Ordinering |
| Legemiddeladministrering | `lmdi-medicationadministration` | **Kjerneressurs** — faktisk administrert dose |
| LegemiddelregisterBundle | `lmdi-bundle` | Transport-innpakning (transaction) |

Canonical-mønster: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/<id>`.

**Referansefiler** (eneste avledede faktalag — slå opp her):

| Tema | Fil |
|---|---|
| Per-profil detaljer (MS, deaktiverte felter, slicing) | `references/profiler.md` |
| Extensions (ATC, NPR, kjemoterapi, mengde ingrediens) | `references/extensions.md` |
| ValueSets / CodeSystems / NamingSystems / OID-er / aliases | `references/terminologi.md` |
| Invariants, sjekklister, feilsøking, maskinell validering | `references/validering.md` |
| Bundle-struktur, referansetopologi, transport/krypto/API | `references/bundle-og-transport.md` |
| Eksempelkatalog og JSON-mønstre | `references/eksempler.md` |
| Profilsammenligning (X vs Y) | `references/sammenligning.md` |
| Tospråklighet (translation-extensions, engelsk doklag) | `references/oversettelser.md` |

### Referansetopologi (hvem peker på hvem)

```
MedicationAdministration
├── subject                → Pasient
├── medicationReference    → Legemiddel
├── context                → Episode
├── request                → Legemiddelrekvirering
└── reasonReference        → Diagnose

MedicationRequest
├── subject                → Pasient
├── requester              → Helsepersonell
├── medicationReference    → Legemiddel
├── encounter              → Episode
├── reasonReference        → Diagnose
└── priorPrescription      → Legemiddelrekvirering

Encounter.serviceProvider  → Organisasjon
Condition.subject          → Pasient
Organisasjon.partOf        → Organisasjon   (hierarki)
Legemiddel.ingredient.itemReference → Virkestoff | Legemiddel
```

---

## 3. Hvordan ressurser skal fylles ut

Framgangsmåte når brukeren spør «hvordan fyller jeg ut X?»:

1. **Slå opp ressursen i `references/profiler.md`** (per-profil: deaktiverte felter, MS, slicing, bindinger, `only Reference(...)`, invariants). Trenger du å verifisere mot kilden, se §1.3.
2. **Les i denne rekkefølgen**: deaktiverte elementer (`* foo 0..0`) → `MS`-markerte → slicing → endrede kardinaliteter → bindinger → `only Reference(...)` → invariants (`obeys`, `Invariant:`).
3. **Forklar med skille MÅ / BØR**:
   - MÅ = `1..`, required-binding, invariants med `Severity: #error`.
   - BØR = MustSupport uten `1..`, anbefalinger i `^short`/`^definition`, `preferred`/`extensible`-bindinger.
4. Felt som ikke nevnes i FSH arves fra parent — merk med `[FHIR-basis, ikke LMDI-spesifikt]`.

**No-basis-arv**: Pasient, Helsepersonell, Organisasjon og Virkestoff arver fra no-basis 2.2.0. Slices som `identifier[FNR/DNR/HPR/ENH/RSH/FHN/HNR]` kommer derfra — LMDI beholder (`MS`), åpner eller stenger (`0..0`) dem. Se `references/profiler.md`; selve no-basis-definisjonene ligger utenfor LMDI-repoet.

---

## 4. Validering av JSON mot profil

Prinsipper (fulle sjekklister, invariant-tabell og feilsøkingstabell: `references/validering.md`):

1. `resourceType` matcher profilens parent; `meta.profile` settes (påkrevd i bundle via invariant `lr-allowed-resources`, sterkt anbefalt standalone).
2. Ingen deaktiverte (`0..0`) felter til stede; alle påkrevde (`1..`) felter satt.
3. Bindinger: `required` = må være i valueset; `extensible` = avvik kun når valueset ikke dekker; `preferred`/`example` = anbefaling.
4. Slicing: `system` må matche slicens faste verdi; `closed` betyr ingen andre systems.
5. `only Reference(...)`: målet må ha riktig profil; i bundle må `urn:uuid:`-referanser matche en `entry.fullUrl`.
6. Invariants og extension-URL-er (LMDI-canonicals) sjekkes til slutt.

Maskinell verifisering (SUSHI, IG Publisher, FHI-testendepunktene) er beskrevet i `references/validering.md`. Ikke påstå at noe «er validert» uten bekreftelse fra et verktøy.

---

## 5. Lage eksempler

1. **Minimalt eksempel**: kun `1..`-felter, required bindings og invariant-krav. Konstruer minimale målressurser for `only Reference(...)`-felter.
2. **Realistisk eksempel**: modeller etter katalogen i `references/eksempler.md` (sykehjem, kjemoterapi, entered-in-error, selvadministrert, infusjon).
3. **Referanseform i bundle**: `urn:uuid:<v4>` i `entry.fullUrl` og `Reference.reference`, konsistent (mønster: `Bundle-Scenario-Sykehjem-Oksykodon`).
4. **Gyldighets-merking** — avslutt alltid genererte eksempler med:
   > «Manuelt utledet basert på profil — ikke maskinelt validert. Valider med `sushi .` eller FHI sitt testendepunkt før innsending.»

   Har du faktisk kjørt SUSHI eller testendepunktet med OK, si det eksplisitt.

---

## 6. Henvisning til kilder i svar

Når relevant, inkluder:

- **Eksakt profilnavn** (title + id): `Legemiddeladministrering` (`lmdi-medicationadministration`).
- **Canonical URL**: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/lmdi-medicationadministration`.
- **Kildehenvisning**: referansefil (f.eks. `references/validering.md`) eller, når kjent, FSH-fil og linje (`lmdi-MedicationAdministration.fsh:233-236`, `time-required`-invarianten).
- **IG-versjon** hvis spørsmålet er versjonsavhengig.

---

## 7. Oppdatering av skillen

Når FSH-kildene har endret seg, eller brukeren ber om at skillen oppdateres: følg prosedyren i `UPDATE.md` (samme katalog). Den beskriver to-repo-modellen (skillen versjonsstyres i plugin-repoet), proveniens, trinnvis re-synkronisering og changelog.

---

## 8. Begrensninger

Denne skillen dekker **ikke**:

- Komplett innhold av eksterne kodeverk (ICD-10/11, ICPC-2, SNOMED CT, ATC, FEST) — bare strukturelle krav.
- Detaljer i no-basis 2.2.0 — bare hvilke slices LMDI bruker, åpner eller stenger.
- Eksempelkode for signering/kryptering i C# og PowerShell (ligger i `pagecontent/eksempelkode_cs.md` / `eksempelkode_ps1.md`).

Spør brukeren om noe av dette: vis hvor det ligger, og gi eventuelt et kort `[FHIR-basis, ikke LMDI-spesifikt]`-svar på generelt nivå.

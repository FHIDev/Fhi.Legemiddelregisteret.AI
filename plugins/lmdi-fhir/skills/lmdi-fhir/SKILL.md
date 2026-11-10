---
name: lmdi-fhir
description: LMDI-implementasjonsguiden (FHIR R4) for innsending av legemiddeldata fra institusjon til Legemiddelregisteret, IG-versjon 1.1.9. Bruk ved spørsmål om LMDI-profiler og hvordan ressurser fylles ut (MedicationAdministration, MedicationRequest, Medication, Patient, Encounter, Condition, Organization, Practitioner, Substance), LegemiddelregisterBundle, extensions, valuesets og invariants, ved validering eller feilsøking av FHIR-JSON og OperationOutcome fra FhirMottak, når det skal lages eksempler, og ved signert og kryptert innsending (SignertKryptertBundle, Maskinporten). Hva LMR gjør med meldingen etter mottak, dekkes av skillen lmr.
---

# LMDI – Legemiddeldata fra institusjon til Legemiddelregisteret

Arbeidsinstruks og navigasjon for LMDI-spørsmål. Faktainnholdet ligger i `references/`, som er et øyeblikksbilde av LMDI-kildene. Skillen er selvstendig og krever ikke tilgang til LMDI-repoet for å svare.

**Versjon**: IG `1.1.9` (FHIR `4.0.1`), repo [`folkehelseinstituttet/LMDI`](https://github.com/folkehelseinstituttet/LMDI), commit `9355f8e969425a59489ae724e7ba4b9bc545ea1f`.

Dette er det eneste stedet versjonen og commit-pinnen vedlikeholdes (i tillegg til `description` over og `version` i `marketplace.json`). `scripts/sjekk-skills.py` i plugin-repoet feiler hvis de ikke stemmer overens.

**Avgrensning**: Denne skillen dekker avsendersiden, altså hva som skal sendes og hvordan. Hva som skjer i LMR etter mottak (FhirMottak, splitting, registre, meldingsstatus) dekkes av skillen `lmr`.

---

## 1. Hvordan svare

### 1.1 Svarprinsipper

- **Aldri gjett.** Kan noe ikke utledes fra `references/`, si det eksplisitt.
- **Skill mellom krav og anbefaling** når det har betydning for svaret:
  - **MÅ**: kardinalitet `1..`, `0..0`, required-binding, lukket slicing, `Reference(...)`-mål, invariant.
  - **BØR**: MustSupport uten `1..`, `preferred`/`extensible`-binding, anbefalinger i profiltekst og IG-sider.
  - **FHIR-basis**: generell R4- eller no-basis-regel som LMDI ikke endrer. Si at den ikke er LMDI-spesifikk.
- **Kildehenvisning**: oppgi profil og element (`Legemiddeladministrering.dosage.dose`) og referansefila du har det fra (`references/struktur.md`). **Oppgi aldri FSH-linjenummer.** De finnes ikke i `references/`, og et linjenummer du ikke har lest i kilden, er gjetning.
- Bruk eksakte profilnavn (tittel og id, f.eks. `Legemiddeladministrering` / `lmdi-medicationadministration`). Canonical-URL-er gjengis uendret.
- Svar på samme språk som brukeren. Tekniske navn beholdes.
- Oppgi IG-versjonen når svaret er versjonsavhengig.

### 1.2 Hvilken kilde gjelder

1. `references/struktur.md` for kardinalitet, MustSupport, typer, referansemål, bindinger, faste verdier, slicing og invarianter. Fila er generert fra StructureDefinitionene og går foran de håndskrevne filene ved motstrid.
2. De håndskrevne filene i `references/` for forklaring, praksis, transport og eksempler.
3. FHIR R4 og no-basis for det LMDI ikke dekker.

Finner du motstrid mellom `struktur.md` og en håndskrevet fil: bruk `struktur.md`, og si fra til brukeren at den håndskrevne fila bør rettes.

### 1.3 Verifisering mot kilden og versjonssjekk

Bare ved tvil, eller når brukeren ber om det.

**Nyere IG-versjon?** Hent `version:` fra kilden og sammenlign med versjonen over:

```
https://raw.githubusercontent.com/folkehelseinstituttet/LMDI/main/LMDI/sushi-config.yaml
```

Er versjonen på `main` nyere, fortell brukeren at skillen kan være utdatert og bør oppdateres etter `UPDATE.md`.

**En strukturdetalj?** Les FSH lokalt hvis LMDI-repoet finnes, ellers hent fila pinnet til commiten over. Raw-URL-er kan ikke liste kataloger, så oppgi filnavnet:

```
https://raw.githubusercontent.com/folkehelseinstituttet/LMDI/<commit>/LMDI/input/fsh/profiles/lmdi-Medication.fsh
```

Underkatalogene er `profiles`, `extensions`, `valuesets` og `namingsystems`. Finner du avvik mellom `references/` og kilden, si det til brukeren og følg `UPDATE.md`.

---

## 2. Domeneoversikt og navigasjon

LMDI overfører **rekvirering** og **administrering** av legemidler fra institusjoner (sykehus, sykehjem, kommunale tjenester) til Legemiddelregisteret (LMR) hos FHI. Daglig overføring, kun endringer siden sist. Data pakkes i en `SignertKryptertBundle`-JSON-konvolutt og sendes via Maskinporten-sikret API.

**Ni FHIR-profiler** og én **bundle-profil**:

| Profil (tittel) | Id | Rolle |
|---|---|---|
| Pasient | `lmdi-patient` | Hvem fikk legemidlet |
| Helsepersonell | `lmdi-practitioner` | Hvem rekvirerte |
| Organisasjon | `lmdi-organization` | Hvor (hierarkisk) |
| Episode | `lmdi-encounter` | Opphold/konsultasjon |
| Diagnose | `lmdi-condition` | Indikasjon |
| Legemiddel | `lmdi-medication` | Produkt/virkestoff som ble gitt |
| Virkestoff | `lmdi-substance` | Rent virkestoff (valgfritt) |
| Legemiddelrekvirering | `lmdi-medicationrequest` | Ordinering |
| Legemiddeladministrering | `lmdi-medicationadministration` | **Kjerneressurs**, faktisk administrert dose |
| LegemiddelregisterBundle | `lmdi-bundle` | Transport-innpakning (transaction) |

Canonical-mønster: `http://hl7.no/fhir/ig/lmdi/StructureDefinition/<id>`.

**Referansefiler for å bruke IG-en:**

| Tema | Fil |
|---|---|
| Eksakt struktur per profil og extension (generert) | `references/struktur.md` |
| Forklaring og praksis per profil | `references/profiler.md` |
| Extensions (ATC, NPR, kjemoterapi, mengde ingrediens, administrert/rekvirert ved) | `references/extensions.md` |
| ValueSets, CodeSystems, NamingSystems, OID-er | `references/terminologi.md` |
| Sjekklister, testendepunkter, feilsøking | `references/validering.md` |
| Bundle-struktur, referansetopologi, transport, krypto, API | `references/bundle-og-transport.md` |
| C#-eksempelkode for komprimering, kryptering og signering | `references/eksempelkode-cs.md` |
| Eksempelkatalog og JSON-mønstre | `references/eksempler.md` |
| Komplett bundle som JSON | `assets/Bundle-Scenario-Sykehjem-Oksykodon.json` |
| Profilsammenligning (X eller Y?) | `references/sammenligning.md` |

**For den som vedlikeholder IG-en** (ikke relevant for avsendere): `references/oversettelser.md` beskriver det engelske oversettelseslaget i LMDI-repoet.

### Referansetopologi (hvem peker på hvem)

```
MedicationAdministration
├── subject                → Pasient
├── medicationReference    → Legemiddel
├── context                → Episode
├── request                → Legemiddelrekvirering
├── reasonReference        → Diagnose
└── extension[administrertVed] → Organisasjon

MedicationRequest
├── subject                → Pasient
├── requester              → Helsepersonell
├── medicationReference    → Legemiddel
├── encounter              → Episode
├── reasonReference        → Diagnose
├── priorPrescription      → Legemiddelrekvirering
└── extension[rekvirertVed] → Organisasjon

Encounter.serviceProvider  → Organisasjon
Condition.subject          → Pasient
Organisasjon.partOf        → Organisasjon   (hierarki)
Legemiddel.ingredient.itemReference → Virkestoff | Legemiddel
```

---

## 3. Hvordan ressurser skal fylles ut

Når brukeren spør «hvordan fyller jeg ut X?»:

1. **Slå opp profilen i `references/struktur.md`.** Linja «Påkrevd inkl. FHIR-basis» gir minimumet, «Deaktivert (0..0)» det som ikke kan sendes, og tabellen resten.
2. **Les forklaringen i `references/profiler.md`** for samme profil: hva feltene betyr, praksisregler og versjonsmerknader.
3. **Forklar med skillet MÅ / BØR** fra §1.1.
4. Felt som verken står i `struktur.md` eller `profiler.md`, arves uendret fra parent. Si at svaret da er FHIR-basis og ikke LMDI-spesifikt.

**No-basis-arv**: Pasient, Helsepersonell, Organisasjon og Virkestoff arver fra no-basis 2.2.0. Slices som `identifier[FNR/DNR/HPR/ENH/RSH/FHN/HNR]` kommer derfra. LMDI beholder dem (`MS`), åpner dem eller stenger dem (`0..0`). Selve no-basis-definisjonene ligger utenfor skillen.

---

## 4. Validering av JSON mot profil

Manuell gjennomgang (fulle sjekklister og feilsøkingstabell i `references/validering.md`):

1. `resourceType` matcher profilens type, og `meta.profile` er satt (påkrevd i bundle via invarianten `lr-allowed-resources`).
2. Ingen deaktiverte (`0..0`) felter er til stede, og alle påkrevde felter er satt, også de fra FHIR-basis.
3. Bindinger: `required` må være i valuesettet, `extensible` kan avvike bare når valuesettet ikke dekker, `preferred` er en anbefaling.
4. Slicing: `system` må matche slicens faste verdi. Lukket slicing tillater ingen andre systemer.
5. Referanser: målet må ha riktig profil, og `urn:uuid:`-referanser må matche en `entry.fullUrl`.
6. Invarianter og extension-URL-er til slutt.

**Maskinell validering.** Testendepunktet for ukrypterte bundler krever ikke autentisering og lagrer ingenting. Har du nettilgang, bruk det i stedet for å stole på manuell gjennomgang:

```bash
curl -sS -X POST "https://test-fhirmottak.lmr.fhi.no/fhirmottak/v1/validateLegemiddelregisterBundle" \
  -H "Content-Type: application/json" --data-binary @bundle.json
```

400 betyr feil. 200 betyr at endepunktet ikke fant feil i det det kontrollerer, ikke at bundelen er gyldig:

- **Kontrolleres**: struktur, kardinalitet (også `0..0`), faste verdier, slicing og invarianter.
- **Kontrolleres ikke**: terminologi. Koder sjekkes ikke mot valuesettene, heller ikke der bindingen er `required`. En oppdiktet SNOMED CT-kode i `dosage.route`, `status = in-progress` og `address.use = work` gir alle 200 (observert 2026-11-10).

Etter 200 må bindingene derfor fortsatt kontrolleres manuelt (punkt 3 over, «Required-bindinger» i `references/validering.md`). Si i svaret hva som er maskinelt kontrollert og hva som ikke er det.

- **Send bare syntetiske data.** Kan en bundle fra brukeren inneholde ekte pasientopplysninger (fødselsnummer, virkelige administreringer), skal den ikke sendes noe sted. Spør brukeren, eller valider manuelt.
- Får du ikke kontakt med endepunktet, si det, og gi brukeren kommandoen.
- Ikke påstå at noe «er validert» uten svar fra endepunktet eller et annet verktøy, og ikke påstå at kodeverdier er validert på grunnlag av 200 fra endepunktet.

---

## 5. Lage eksempler

1. **Komplett bundle**: start fra `assets/Bundle-Scenario-Sykehjem-Oksykodon.json`. Den er hentet uendret fra den publiserte IG-en. IG Publisher rapporterer én uavklart feil på den (`dosage.route`, se `references/eksempler.md`).
2. **Minimalt eksempel**: «Påkrevd inkl. FHIR-basis» i `references/struktur.md`, pluss required-bindinger og invarianter. Lag minimale målressurser for påkrevde referanser.
3. **Realistisk eksempel**: velg nærmeste scenario i `references/eksempler.md` (sykehjem, kjemoterapi, entered-in-error, selvadministrert, infusjon).
4. **Referanser i bundle**: `urn:uuid:<v4>` i `entry.fullUrl` og `Reference.reference`, konsekvent.
5. **Bare syntetiske data** i eksempler. Ikke gjenbruk personopplysninger brukeren har limt inn.
6. **Valider eksempelet** mot testendepunktet (§4) når det er en bundle og du har nettilgang, og si hva svaret ble og at kodeverdiene ikke inngår i kontrollen. Ellers avslutt med:
   > «Manuelt utledet fra profilene, ikke maskinelt validert. Valider mot FHI sitt testendepunkt før innsending.»

---

## 6. Oppdatering av skillen

Når LMDI-kildene er endret, eller brukeren ber om at skillen oppdateres: følg `UPDATE.md` (samme katalog).

---

## 7. Begrensninger

Skillen dekker **ikke**:

- Komplett innhold i eksterne kodeverk (ICD-10/11, ICPC-2, SNOMED CT, ATC, FEST). Bare hvilke systemer som skal brukes hvor.
- Detaljer i no-basis 2.2.0. Bare hvilke slices LMDI bruker, åpner eller stenger.
- PowerShell-eksempelkoden for signering og kryptering (ligger i IG-en, `eksempelkode_ps1.html`). C#-koden er med.
- Hvilken IG-versjon mottaket til enhver tid validerer mot. Se `references/validering.md`.
- Behandlingen i LMR etter mottak. Bruk skillen `lmr`.

Spør brukeren om noe av dette, si hvor det ligger, og gi eventuelt et kort svar på FHIR-basis-nivå.

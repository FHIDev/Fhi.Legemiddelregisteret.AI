# Oppdateringsprosedyre for skillen `lmdi-fhir`

Følg denne prosedyren når brukeren ber om at skillen oppdateres mot FSH-endringer i LMDI-repoet.

## To-repo-modellen

| Hva | Hvor |
|---|---|
| Kilde-sannhet (FSH, sushi-config, pagecontent) | `C:\dev\LMDI` (repo `HL7Norway/LMDI` el.l.) |
| Skill-filene (denne katalogen) | `C:\dev\Fhi.Lmr.AI\skills\lmdi-fhir` — versjonsstyres i **plugin-repoet** (`Fhi.Lmr.AI`, Azure DevOps: `fhi/Fhi.Legemiddelregisteret/_git/Fhi.Lmr.AI`), som er kilden for skillen |

Endringer i skill-filene committes og pushes altså i `Fhi.Lmr.AI`, ikke i LMDI-repoet, wiki-repoet eller det gamle `Fhi.Legemiddelregisteret.AI`.

## Proveniens (oppdatér ved hver kjøring)

| Felt | Verdi |
|---|---|
| Branch (LMDI) | `roar/apne-form-coding` (ikke merget til `main` ennå) |
| HEAD commit (LMDI) | `02346e2a1cebc6509b1096709bdf91a7b3bdcc03` |
| Analysedato | 2026-09-21 |
| Verifiseringsmetode | Mot lokalt LMDI-arbeidstre på branchen. `sushi .` kjørt (0 errors, 2 warnings); `StructureDefinition-lmdi-medication.json` lest direkte for å bekrefte `Medication.form.coding` med `slicing.rules = open` og begge slices intakte. Eneste FSH-endring siden `1f597673e` er i `lmdi-Medication.fsh` (`git diff 1f597673e..HEAD`) |
| IG-versjon | 1.1.5 (fra `sushi-config.yaml`, dato 2026-09-21) |

## Prosedyre

### Trinn 1: Verifiser arbeidstre i LMDI-repoet

```bash
cd /c/dev/LMDI
git rev-parse --abbrev-ref HEAD           # branch
git rev-parse HEAD                        # HEAD commit
git status --short LMDI/input/fsh LMDI/sushi-config.yaml LMDI/input/pagecontent
git log -5 --oneline
```

Hvis `git status --short LMDI/input/fsh` returnerer noe: **STOPP**. Informer brukeren og spør om oppdateringen skal bygge på de ucommittede endringene eller siste commit. Endringer i andre stier utløser ikke stop-regelen.

Noter branch, HEAD-commit og dato — disse skrives inn i proveniens-tabellen over i trinn 4.

### Trinn 2: Les inn kilder på nytt

- `LMDI/input/fsh/profiles/*.fsh`, `extensions/*.fsh`, `valuesets/*.fsh`, `namingsystems/*.fsh`, `aliases.fsh`
- `LMDI/sushi-config.yaml`
- `LMDI/input/pagecontent/*.md` (minst: `index.md`, `integrasjon.md`, `protokoll.md`, `SignertKryptertBundle.md`, `informasjonsmodell.md`)

Bruk gjerne `git diff <forrige proveniens-commit>..HEAD -- LMDI/input/fsh LMDI/sushi-config.yaml LMDI/input/pagecontent` for å avgrense hva som faktisk er endret.

### Trinn 3: Sammenlign med `references/`

`references/` er det **eneste** avledede faktalaget. For hver endring:

1. **Nye / fjernede profiler, extensions, valuesets, codesystems, namingsystems** — oppdater tabellene i `profiler.md`, `extensions.md`, `terminologi.md`.
2. **Endret kardinalitet, binding, slicing, `only Reference(...)`** — oppdater den aktuelle seksjonen i `profiler.md`/`extensions.md`, og referansetabellene i `bundle-og-transport.md` og `validering.md`.
3. **Nye / endrede invariants** — `validering.md` er eneste sted invariant-tabellen vedlikeholdes.
4. **Nye / endrede eksempelinstanser** — `eksempler.md` (instansnavn-tabellen og scenarier).
5. **Endrede norske tekster med engelske translation-extensions** — `oversettelser.md` ved mekanisme-endringer.
6. **Versjonsbump** — oppdater versjon i proveniens-tabellen her og i SKILL.md-frontmatter/-preamble.

### Trinn 4: Oppdater filer

Rekkefølge og arbeidsdeling — **ikke dupliser innhold på tvers, lenk heller**:

1. `references/*.md` — alt avledet faktainnhold.
2. `SKILL.md` — bare ved strukturelle endringer (ny profil, versjon, ny invariant, endret transport). SKILL.md er arbeidsinstruks + navigasjon, ikke faktaoppslag.
3. `UPDATE.md` (denne fila) — proveniens-tabellen + changelog-entry nederst.

### Trinn 5: Fjern utdaterte antakelser

Søk i skill-katalogen etter fraser som avhenger av gamle URL-er / kardinaliteter / navn:

```bash
SKILL_DIR="/c/dev/Fhi.Lmr.AI/skills/lmdi-fhir"
grep -rn "<utgått-frase>" "$SKILL_DIR"
```

Historiske eksempler på slike fraser: `fh.no/lokaltVirkemiddel` (URL endret i 1.1.0), `organisatoriskNiva` som aktivt felt (deaktivert i 1.1.0), `nprEpisodeIdentifier 0..1` (ble 0..* i 1.1.2), `requester 1..1` på Legemiddelrekvirering (ble 0..1 i 1.1.3).

### Trinn 6: Rapportér til brukeren

- Hvilke filer som ble oppdatert.
- Endrede kardinaliteter / bindinger / slicing per profil og extension.
- Nye eller fjernede artefakter.
- Versjonsendring (hvis noen).
- Usikkerheter (f.eks. ny parent uten alias — må verifiseres mot generert artefakt).

### Trinn 7: Verifiser frontmatter, så commit i plugin-repoet

Før commit: kontrollér at YAML-frontmatteren i alle `SKILL.md` faktisk lar seg parse. Ugyldig
frontmatter gjør at skillen ikke tilbys i sesjonen, uten noen feilmelding — og `claude plugin
validate` fanger det **ikke** (den rapporterer «Validation passed»).

```bash
python -c "
import yaml,io,re,glob
for p in glob.glob(r'C:\dev\Fhi.Lmr.AI\skills\*\SKILL.md'):
    fm=re.search(r'^---\r?\n(.*?)\r?\n---',io.open(p,encoding='utf-8').read(),re.S).group(1)
    try: print('OK  ',p,list(yaml.safe_load(fm)))
    except Exception as e: print('FAIL',p,type(e).__name__,e)
"
```

Vanligste fallgruve: kolon-mellomrom (`: `) inne i en usitert `description`. Bruk tankestrek i
stedet for kolon i løpende tekst.

Kryssjekk med `claude plugin details lmr`: er `always-on`-tallet for en skill lavt i forhold til
hvor lang descriptionen er (til sammenligning: `lmr` ≈ 100 tok for 202 tegn), er det et tegn på at
descriptionen ikke kommer med.

Commit deretter skill-endringene i `Fhi.Lmr.AI` med beskrivende norsk melding. Push etter avtale
med brukeren. Pushen trigger `azure-pipelines.yml`, som speiler til GitHub
(`FHIDev/Fhi.Legemiddelregisteret.AI`) — kilden marketplacen `fhi-lmr` leser fra. Verifiser
speilingen med `git ls-remote https://github.com/FHIDev/Fhi.Legemiddelregisteret.AI main` — den tar
noen minutter, og pipelineresultatet er ikke synlig fra Claude Code.

Hent så inn på nytt lokalt. Begge lagene må oppdateres, i denne rekkefølgen, og pluginen må
kvalifiseres med marketplace-navnet (`claude plugin update lmr` alene feiler med
«Plugin "lmr" not found»):

```bash
claude plugin marketplace update fhi-lmr
claude plugin update lmr@fhi-lmr
```

Restart Claude Code for å ta det i bruk.

## Verifiseringsstrategi

Når en antakelse kan bekreftes ved å lese `LMDI/fsh-generated/resources/*.json` eller no-basis-pakken (`~/.fhir/packages/hl7.fhir.no.basis#2.2.0/` eller `node_modules/hl7.fhir.no.basis/`), gjør det i stedet for å markere som usikkert. Verifiser minst: baseDefinition-relasjoner, canonical-URL-er på lokalt definerte CS/VS, extension-URL-er fra no-basis.

## Changelog for skillen

### 2026-09-21 (sist — IG 1.1.5, branch `roar/apne-form-coding`)
- `Medication.form.coding`: slicingen er endret fra `closed` til `open`. Slicene `OID7448` og `SCT`
  beholdes, men andre kodesystemer for legemiddelform er nå tillatt. `system 1..1` / `code 1..1`
  gjelder fortsatt alle codings. `^comment` (norsk og engelsk) omskrevet i FSH. Oppdatert
  `profiler.md` §Legemiddel/`form`.
- Versjon 1.1.5 i `SKILL.md`, `terminologi.md` og proveniensen. Versjonspin flyttet fra
  `1f597673e` til `02346e2a1`.
- **Merk**: bygd på branchen før merge. Når PR-en er merget, bør pinnen flyttes til merge-commiten
  på `main`, slik det ble gjort for 1.1.4 (se oppføringen 2026-08-19).

### 2026-08-24 (full gjennomgang mot IG 1.1.4)
Hele `references/` verifisert mot `fsh-generated/resources/*.json` på `1f597673e`: 10 profiler,
6 extensions, 7 ValueSets, 2 CodeSystems, 5 NamingSystems, 50 eksempelinstanser, 5 invariants og
11 slicing-definisjoner stemte uten avvik. Fire rettinger:
- **Rettet feil**: `extensions.md` §«Kjent QA-støy» påsto «Bindingen er `preferred`» og at
  meldingene var undertrykt i `ignoreWarnings.txt`. Begge deler var utdatert etter PR #109 —
  extensionen har ingen binding, og `ignoreWarnings.txt` har ingen oppføringer for
  `medication-ingredientstrength`. Avsnittet motsa fila 40 linjer lenger opp. Omskrevet, og
  antall QA-meldinger fjernet siden det ikke er etterprøvd mot et bygg etter endringen
  (`output/qa.txt` er fra før PR #109 ble merget).
- `bundle-og-transport.md`: nytt punkt om hvor sertifikatene hentes (`certificates.zip` fra
  nedlastingssiden) — krypto-kjeden forutsatte LMRs offentlige nøkkel uten å si hvor den kom fra.
- `profiler.md`: Organisasjonens adresse ble beskrevet som «samme regler som Pasient», men
  Organisasjon har ingen `LmdiAddressUse`-binding på `address.use`. Presisert.
- `SKILL.md` §1.4: raw-URL-en pekte på en katalog, som ikke kan listes over raw.githubusercontent.

### 2026-08-24 (rettet ugyldig frontmatter)
- **Rettet feil**: `description` i `SKILL.md` inneholdt «Selvstendig: bygger på …» — kolon-mellomrom
  inne i en usitert YAML-skalar. Frontmatteren lot seg dermed ikke parse (`mapping values are not
  allowed here`), og skillen ble ikke tilbudt i sesjonen. Kolonet er byttet mot tankestrek.
  `lmr`-skillen i samme plugin var upåvirket.
- Trinn 7 utvidet med en frontmatter-parsesjekk før commit, siden `claude plugin validate` ikke
  fanger denne feilklassen, og med stegene for speiling og lokal plugin-oppdatering.

### 2026-08-24 (IG 1.1.4, etter merge av PR #111)
- **Rettet feil**: `extensions.md` og `terminologi.md` dokumenterte fortsatt en `preferred`-binding
  på `value[x]` i `lmdi-ingredient-strength`. Bindingen ble fjernet i PR #109 (commit `97157fda9`)
  fordi R5-valuesettet ikke lot seg resolve i en R4-IG, og fordi den lå på `value[x]` og dermed
  også ville ha gjeldt enhetskoden i `Quantity`-grenen. Kodeverk anbefales nå i `^comment`:
  OID `2.16.578.1.12.4.1.1.7502` eller `medication-ingredientstrength`. Verifisert mot generert
  artefakt (`binding` mangler helt).
- Ny OID-rad i `terminologi.md` for `2.16.578.1.12.4.1.1.7502`.
- Eksempler: `Virkestoff-Natriumklorid` er **fjernet** fra `lmdi-Substance.fsh` og erstattet av
  `Legemiddel-NatriumkloridBBraun` (sterilt saltvann med FEST legemiddelmerkevare-id). Smerteblandingen
  viser derfor nå to måter å angi ingrediens på, ikke tre, men alle tre `strength`-variantene.
  Midazolam-ingrediensen rettet til varenummer 525858 (5 mg/ml). Oppdatert `eksempler.md`,
  `extensions.md`.
- `profiler.md`: seksjonsoverskriften «styrke vs. mengde» merket 1.1.4 i stedet for 1.1.3.
- Versjonspin i `SKILL.md` flyttet fra `ad8dde0c7` (1.1.3) til `1f597673e` (1.1.4). Dermed er
  problemet fra forrige oppføring lukket: extensionen har nå en egen IG-versjon.
- `ignoreWarnings.txt` mistet de to undertrykkingene for `medication-ingredientstrength` — konsekvens
  av at bindingen forsvant, ingen endring i `validering.md` nødvendig.


### 2026-08-19 (sist — etter merge av PR #106)
- Re-verifisert mot `main @ ad8dde0c7`: extension-FSH, `mengde`-slicen på `ingredient.strength`,
  aliaset `$IngrediensStyrkeKoder` og de tre eksempelinstansene er uendret fra branchen.
- Versjonspin i `SKILL.md` flyttet fra `e02c00ad9` til `ad8dde0c7` — `e02c00ad9` inneholder ikke
  extensionen, så den gamle pinnen pekte på en kilde som motsa `references/`.
- **Merk**: extensionen kom inn på `main` uten versjonsbump — `sushi-config.yaml` står fortsatt på
  1.1.3 med dato 2026-08-14. IG-versjonen alene skiller derfor ikke denne skillen fra en som
  mangler extensionen; bruk HEAD-commiten i proveniensen.

### 2026-08-19 (senere — issue #101)
- Ny extension `lmdi-ingredient-strength` («Mengde ingrediens») på `Medication.ingredient.strength`,
  `value[x]` = `CodeableConcept | Quantity`. Speiler de to typene R4 mangler i forhold til R5/R6
  `strength[x]`. Oppdatert `extensions.md`, `profiler.md`, `terminologi.md`, `sammenligning.md`
  (ny §5b styrke vs mengde), `validering.md` (base-invarianten `rat-1`), `eksempler.md`
  (`Legemiddel-Smerteblanding`, `Legemiddel-MorfinKonsentrat`, `Virkestoff-Natriumklorid`).
- Skillen flyttet til `Fhi.Lmr.AI`; stier i to-repo-modellen, Trinn 5 og Trinn 7 rettet.
- Bygde opprinnelig på branchen `roar/101-ingrediens-styrke`. PR #106 ble merget samme dag, og
  innholdet er re-verifisert mot `main @ ad8dde0c7` uten avvik.

### 2026-08-19
- Oppdatert til IG 1.1.3: `MedicationRequest.requester` er endret fra 1..1 MS til 0..1 MS. Feltet er fortsatt Must Support og begrenset til `Reference(Helsepersonell)` når det finnes.
- Oppdatert profiloppslag, referansetopologi, profilsammenligning, valideringsnotat og versjonsmetadata mot LMDI `main @ e02c00ad9`.

### 2026-06-19
- Gjort skillen selvstendig: `references/` er nå det autoritative grunnlaget i SKILL.md, ikke et avledet lag som måtte verifiseres mot FSH før svar. Fjernet instruksjonene som ba agenten mistro referansefilene og åpne FSH i `LMDI/input/fsh/` først (§1.2-rekkefølge, §1.3-stoppbetingelse, §3 trinn 1). Dette stoppet at agenten lette etter LMDI-repoet i feil arbeidsmappe.
- §1.4 erstattet «git status på arbeidstre» (pekte på feil relativ sti) med en versjonssjekk mot raw-URL: `sushi-config.yaml` på `main` for å oppdage nyere IG-versjon, og FSH pinnet til commit `cb419e640` for valgfri kildeverifisering når LMDI-repoet ikke finnes lokalt.

### 2026-06-17
- Flyttet til plugin-repoet `Fhi.Legemiddelregisteret.AI` (`skills/lmdi-fhir/`), som nå er kilden for skillen. To-repo-modellen og prosedyrestier oppdatert tilsvarende.

### 2026-06-12
- Restrukturert: `_analysis.md` fjernet (innhold migrert til `references/` og denne fila); `references/` er nå eneste avledede faktalag.
- Ny `references/oversettelser.md` — tospråklighetsmekanismen (translation-extensions, `en-*.md`, `lag-en-doklag.py`).
- Ny `UPDATE.md` (denne fila) — erstatter § 7 i SKILL.md; rettet stier som pekte på ikke-eksisterende kataloger.
- SKILL.md slanket til arbeidsinstruks + navigasjon; feilsøkingstabell flyttet til `validering.md`, OID-tabell til `terminologi.md`.
- Re-verifisert mot LMDI `main @ cb419e640` (IG 1.1.2): flere NPR-identifikatorer per episode (eksempel med to forekomster), engelske translation-extensions i alle FSH-filer.

### 2026-06-12 (tidligere, commit `4e9b6125`)
- Oppdatert til IG 1.1.2: `nprEpisodeIdentifier` 0..* på Episode.

### 2026-04 (commit `415e6c02`)
- Restrukturert fra FSH-kildekopier til tematiske markdown-referanser (`references/`).

### 2026-03 (commits `88b8d4d4`, `53135b70`)
- Skill opprettet i wiki-repoet og synkronisert med LMDI v1.1.0.

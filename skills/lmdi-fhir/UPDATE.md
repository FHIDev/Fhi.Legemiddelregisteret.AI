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
| Branch (LMDI) | `main` |
| HEAD commit (LMDI) | `ad8dde0c71354bd04ce34fd687fc57c5dc72285f` |
| Analysedato | 2026-08-19 |
| Verifiseringsmetode | Opprinnelig mot lokalt LMDI-arbeidstre (`fsh-generated/resources/*.json` + qa.html fra full IG-bygg) på branchen. Etter merge re-verifisert mot `main` via GitHub-API (`compare e02c00ad9...ad8dde0c7`) — FSH-kilde, aliases og `ignoreWarnings.txt` uendret fra branchen |
| IG-versjon | 1.1.3 (fra `sushi-config.yaml`, ingen bump) |

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

### Trinn 7: Commit i plugin-repoet

Commit skill-endringene i `Fhi.Lmr.AI` med beskrivende norsk melding. Push etter avtale med brukeren.

## Verifiseringsstrategi

Når en antakelse kan bekreftes ved å lese `LMDI/fsh-generated/resources/*.json` eller no-basis-pakken (`~/.fhir/packages/hl7.fhir.no.basis#2.2.0/` eller `node_modules/hl7.fhir.no.basis/`), gjør det i stedet for å markere som usikkert. Verifiser minst: baseDefinition-relasjoner, canonical-URL-er på lokalt definerte CS/VS, extension-URL-er fra no-basis.

## Changelog for skillen

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

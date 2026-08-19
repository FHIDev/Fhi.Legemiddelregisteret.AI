# Oppdateringsprosedyre for skillen `lmdi-fhir`

Følg denne prosedyren når brukeren ber om at skillen oppdateres mot FSH-endringer i LMDI-repoet.

## To-repo-modellen

| Hva | Hvor |
|---|---|
| Kilde-sannhet (FSH, sushi-config, pagecontent) | `C:\dev\LMDI` (repo `HL7Norway/LMDI` el.l.) |
| Skill-filene (denne katalogen) | `C:\dev\Fhi.Legemiddelregisteret.AI\skills\lmdi-fhir` — versjonsstyres i **plugin-repoet** (`Fhi.Legemiddelregisteret.AI`), som er kilden for skillen |

Endringer i skill-filene committes og pushes altså i `Fhi.Legemiddelregisteret.AI`, ikke i LMDI-repoet eller wiki-repoet.

## Proveniens (oppdatér ved hver kjøring)

| Felt | Verdi |
|---|---|
| Branch (LMDI) | `main` |
| HEAD commit (LMDI) | `e02c00ad998e8406ac9730a8411b46697fa04d18` |
| Analysedato | 2026-08-19 |
| Verifiseringsmetode | GitHub-API mot `main` (`compare cb419e640...e02c00ad9`) — intet lokalt LMDI-arbeidstre ble brukt, så stop-regelen i Trinn 1 er ikke kjørt |
| IG-versjon | 1.1.3 (fra `sushi-config.yaml`) |

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
SKILL_DIR="/c/dev/Fhi.Legemiddelregisteret.AI/skills/lmdi-fhir"
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

Commit skill-endringene i `Fhi.Legemiddelregisteret.AI` med beskrivende norsk melding. Push etter avtale med brukeren.

## Verifiseringsstrategi

Når en antakelse kan bekreftes ved å lese `LMDI/fsh-generated/resources/*.json` eller no-basis-pakken (`~/.fhir/packages/hl7.fhir.no.basis#2.2.0/` eller `node_modules/hl7.fhir.no.basis/`), gjør det i stedet for å markere som usikkert. Verifiser minst: baseDefinition-relasjoner, canonical-URL-er på lokalt definerte CS/VS, extension-URL-er fra no-basis.

## Changelog for skillen

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

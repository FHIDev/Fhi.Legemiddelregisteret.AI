# Oppdateringsprosedyre for skillen `lmdi-fhir`

Følg denne prosedyren når skillen skal oppdateres mot endringer i LMDI.

## To-repo-modellen

| Hva | Hvor |
|---|---|
| Kilden (FSH, `sushi-config.yaml`, `pagecontent`) | LMDI-repoet, [`folkehelseinstituttet/LMDI`](https://github.com/folkehelseinstituttet/LMDI). Kalt `<LMDI>` under |
| Skill-filene (denne katalogen) | Plugin-repoet `Fhi.Lmr.AI` (Azure DevOps: `fhi/Fhi.Legemiddelregisteret/_git/Fhi.Lmr.AI`), `plugins/lmdi-fhir/skills/lmdi-fhir`. Kalt `<SKILL>` under |

Stiene til de lokale klonene varierer fra maskin til maskin. Spør brukeren hvis du ikke finner dem.
Endringer i skill-filene committes i `Fhi.Lmr.AI`, ikke i LMDI-repoet. GitHub-repoet
`FHIDev/Fhi.Legemiddelregisteret.AI` er en speiling og skal ikke endres direkte.

## Proveniens

IG-versjon og commit-pinne står **ett** sted: linja **Versjon** i `SKILL.md`. Tabellen under beskriver
bare siste gjennomgang.

| Felt | Verdi |
|---|---|
| Analysedato | 2026-11-09 |
| Grunnlag for `references/struktur.md` og `assets/` | Publisert IG (`gh-pages` i LMDI-repoet), bygd fra pinnen |
| Verifiseringsmetode | `git diff 28460d020..9355f8e96 -- LMDI/input/fsh LMDI/sushi-config.yaml LMDI/input/pagecontent` viser bare `releaseLabel` i `sushi-config.yaml`. `struktur.md` generert fra de publiserte StructureDefinitionene (med snapshot) og sammenholdt med `profiler.md`. Testendepunktet og Firely-validator er ikke brukt |

## Prosedyre

### Trinn 1: Verifiser arbeidstreet i LMDI-repoet

```bash
cd <LMDI>
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
git status --short LMDI/input/fsh LMDI/sushi-config.yaml LMDI/input/pagecontent
```

Returnerer `git status --short` noe for `LMDI/input/fsh`: **STOPP**. Spør brukeren om oppdateringen skal
bygge på de ucommittede endringene eller siste commit. Bygger du på en branch før merge, skal pinnen
flyttes til merge-commiten på `main` etterpå.

### Trinn 2: Generer strukturen på nytt og les diffen

Bygg StructureDefinitionene og kjør generatoren:

```bash
cd <LMDI>/LMDI && sushi -s .          # -s gir snapshot, som trengs for «Påkrevd inkl. FHIR-basis»
python <SKILL>/scripts/generer-struktur.py <LMDI>/LMDI/fsh-generated/resources
cd <SKILL> && git diff -- references/struktur.md
```

Alternativt kan katalogen være den publiserte IG-en (`LMDI/output` etter IG Publisher, eller utpakket
`package.tgz`), som alltid har snapshot.

SUSHI setter ikke `version` på StructureDefinitionene (det gjør IG Publisher). Generatoren henter da
IG-versjonen fra `ImplementationGuide-*.json` i samme katalog, og stopper hvis den ikke finner noen.

Diffen på `struktur.md` er fasiten for hva som er endret i kardinalitet, MS, bindinger, slicing,
referansemål og invarianter. `struktur.md` redigeres aldri for hånd.

### Trinn 3: Les tekstendringene

```bash
cd <LMDI>
git diff <pinnen i SKILL.md>..HEAD -- LMDI/input/fsh LMDI/sushi-config.yaml LMDI/input/pagecontent
```

Her finner du det generatoren ikke fanger: beskrivelser, `^short`/`^definition`/`^comment`,
eksempelinstanser, valuesets, namingsystems og IG-sidene.

### Trinn 4: Oppdater de håndskrevne filene

Ikke dupliser innhold på tvers. Lenk heller.

| Endring | Fil |
|---|---|
| Strukturendring fra trinn 2 som trenger forklaring eller versjonsmerknad | `references/profiler.md`, `references/extensions.md` |
| Nye/endrede valuesets, codesystems, namingsystems, OID-er | `references/terminologi.md` |
| Ny/endret invariant: forklaring og feilsøkingsrad | `references/validering.md` |
| Nye referansekanter | topologien i `SKILL.md` og tabellen i `references/bundle-og-transport.md` |
| Endret transport, krypto, API, protokoll | `references/bundle-og-transport.md` |
| Endret `eksempelkode_cs.md` | kopier inn på nytt under streken i `references/eksempelkode-cs.md` |
| Nye/endrede eksempelinstanser | `references/eksempler.md` |
| Endret `Bundle-Scenario-Sykehjem-Oksykodon` | kopier `Bundle-Bundle-Scenario-Sykehjem-Oksykodon.json` på nytt til `assets/` |
| Endret valg mellom profiler/felter | `references/sammenligning.md` |
| Endret oversettelsesmekanisme | `references/oversettelser.md` |
| Ny profil, ny referansefil, endret arbeidsmåte | `SKILL.md` (arbeidsinstruks og navigasjon, ikke faktaoppslag) |

Søk til slutt etter fraser som avhenger av det som er endret (gamle URL-er, kardinaliteter, navn):

```bash
grep -rn "<utgått frase>" <SKILL>
```

Historiske eksempler: `fh.no/lokaltVirkemiddel` (URL endret i 1.1.0), `organisatoriskNiva` som aktivt
felt (deaktivert i 1.1.0), `nprEpisodeIdentifier 0..1` (0..* fra 1.1.2), `requester 1..1` på
Legemiddelrekvirering (0..1 fra 1.1.3), `lmdi-org-identifier` (fjernet i 1.1.9).

### Trinn 5: Versjon

1. `SKILL.md`: IG-versjon og commit i linja **Versjon**, og versjonen i `description`.
2. `.claude-plugin/marketplace.json` i roten av plugin-repoet: `version` for `lmdi-fhir`. Formatet er
   `<LMDI-versjon>-<løpenummer>`. Ny LMDI-versjon starter på `-1`, endring uten ny LMDI-versjon øker
   løpenummeret. **Uten bump får ikke brukerne oppdateringen.** Regelen står i `CLAUDE.md` i roten.
3. Proveniens-tabellen over og en oppføring i changeloggen under.

### Trinn 6: Kontroller

```bash
python -m pip install pyyaml          # én gang. Skriptet krever PyYAML og stopper uten
python <Fhi.Lmr.AI>/scripts/sjekk-skills.py
```

Skriptet sjekker at frontmatteren i alle `SKILL.md` lar seg parse, at versjon og pinne stemmer overens
i `SKILL.md`, `marketplace.json` og `struktur.md`, at referansefilene som nevnes finnes, og at
`evals.json` er gyldig. Det kjøres også i `azure-pipelines.yml` før speilingen til GitHub.

Ugyldig frontmatter gjør at skillen ikke tilbys i sesjonen, uten feilmelding, og
`claude plugin validate` fanger det ikke. Vanligste årsak er kolon-mellomrom (`: `) inne i en usitert
`description`. Bruk komma eller tankestrek i stedet.

Gå gjennom `evals/evals.json`: stemmer forventet oppførsel fortsatt etter endringene? Legg til en eval
for hver endring som er lett å svare feil på.

### Trinn 7: Rapportér til brukeren

- Hvilke filer som ble oppdatert.
- Endrede kardinaliteter, bindinger og slicing per profil og extension (fra diffen i trinn 2).
- Nye eller fjernede artefakter, og versjonsendring.
- Det som ikke er verifisert.

### Trinn 8: Commit, speiling og lokal oppdatering

Commit i `Fhi.Lmr.AI` med beskrivende norsk melding. Push etter avtale med brukeren. Pushen til `main`
trigger `azure-pipelines.yml`, som kjører kontrollen og speiler til GitHub
(`FHIDev/Fhi.Legemiddelregisteret.AI`), kilden marketplacen `fhi-lmr` leser fra. Verifiser speilingen
med `git ls-remote https://github.com/FHIDev/Fhi.Legemiddelregisteret.AI main`. Den tar noen minutter.

Hent så inn lokalt. Begge lagene må oppdateres, i denne rekkefølgen, og pluginen må kvalifiseres med
marketplace-navnet:

```bash
claude plugin marketplace update fhi-lmr
claude plugin update lmdi-fhir@fhi-lmr
```

Restart Claude Code. Kryssjekk med `claude plugin details lmdi-fhir`: er `always-on`-tallet lavt i
forhold til lengden på descriptionen, kommer den ikke med.

## Changelog

Bare de siste oppføringene står her. Resten ligger i git-historikken:
`git log -- plugins/lmdi-fhir`.

### 2026-11-10 (IG 1.1.9, rettelser etter gjennomgang)
- `SKILL.md` og `validering.md`: 200 fra `validateLegemiddelregisterBundle` betyr ikke «gyldig».
  Endepunktet sjekker ikke koder mot valuesett. Tabell over hva det fanger, observert mot test.
- `generer-struktur.py` henter IG-versjonen fra `ImplementationGuide-*.json` når SUSHI-utdata mangler
  `version` på StructureDefinitionene, i stedet for å skrive «?».
- `sjekk-skills.py` krever PyYAML. Reservekontrollen godtok ugyldig YAML.

### 2026-11-09 (IG 1.1.9, skillen gjennomgått)
- Ny generert `references/struktur.md` (`scripts/generer-struktur.py`) som fasit for strukturfakta.
  Genereringen avdekket at `profiler.md` plasserte `manufacturer 0..0` og `text 0..0` under
  `Legemiddel.batch`. De gjelder ressursrot. Rettet.
- Påkrevde felter fra FHIR-basis er synlige per profil (`Episode.status`/`class`, `Virkestoff.code`).
- Nye filer: `assets/Bundle-Scenario-Sykehjem-Oksykodon.json`, `references/eksempelkode-cs.md`,
  `evals/evals.json`.
- `SKILL.md`: ny description, én versjonslinje, MÅ/BØR/FHIR-basis i stedet for tre kildelag, ingen
  FSH-linjenummer, validering mot testendepunktet, avgrensning mot `lmr`.
- `validering.md`: avsnitt om hvilken IG-versjon mottaket validerer mot. `bundle-og-transport.md`:
  rettet diagram, presisert at signaturen beregnes over rå bytes.
- Pinnen flyttet til `9355f8e96` (bare `releaseLabel` endret siden `28460d020`).

### 2026-11-04 (IG 1.1.9, `main @ 28460d020`)
- Invarianten `lmdi-org-identifier` («minst ENH eller RSH») er fjernet fra Organisasjon (PR #131).
  Identifikatorene er fortsatt støttet, men ikke påkrevd.
- Ny seksjon «Hierarki» i `profiler.md` etter den utvidede profilbeskrivelsen på Organisasjon
  (PR #130/#131). Bare tekst, ikke håndhevet.

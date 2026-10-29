---
description: Gjennomgå agentoppsettet (CLAUDE.md, AGENTS.md, .claude/settings.json og repo-skillene) i repoet du står i, kontroller hver påstand mot koden og rapporter funn uten å endre filer
argument-hint: "[sti til Test-Agentfiler.ps1]"
---

Brukeren vil ha en innholdsgjennomgang av agentoppsettet i repoet du står i (repo-roten er
arbeidsmappen). `$1` er en valgfri sti til `Test-Agentfiler.ps1`.

## Hvorfor denne kommandoen finnes

Agentfilene peker til koden og forklarer den, men ingenting feiler når koden endres og
filene ikke følger med. Tverrgående endringer, som overgangen fra HelseID til Entra ID, har
etterlatt flere repoer med agentfiler som beskriver en løsning som ikke finnes lenger. En agent
som stoler på slike filer, gjør feil med stor selvtillit. Gjennomgangen skal derfor kunne
gjentas av hvem som helst, med samme metode og samme rapportformat.

## Regler

- **Bare lesing.** Ikke opprett, endre, flytt eller slett filer, ikke commit, og ikke skriv til
  eksterne systemer. Gjelder også subagenter du starter. Ber brukeren om rettinger etter at
  rapporten er levert, er det en ny oppgave.
- **Koden er fasit.** Et funn skal vise til kildefilen som viser hva som er riktig. Har du ikke
  funnet kildefilen, merkes funnet `(usikkert)`.
- Ikke gjengi persondata, hemmeligheter eller miljøspesifikke ID-er i rapporten. Vis til fil og
  linje.

## Steg

**1. Les agentfilene i sin helhet:** `CLAUDE.md`, `AGENTS.md` (hvis den finnes),
`.claude/settings.json` og alt under `.claude/skills/`. Les også `README.md` og `docs/` (hvis den
finnes), slik at du kan se duplisering. Last lmr-skillen
(`${CLAUDE_PLUGIN_ROOT}/skills/lmr/SKILL.md`) og les referansefilene den lenker til når
agentfilene overlapper med dem.

**2. Kjør `Test-Agentfiler.ps1`** fra Fhi.Lmr.DevOps (`script/powershell/Test-Agentfiler.ps1`).
Bruk `$1` hvis den er oppgitt, ellers `../Fhi.Lmr.DevOps/script/powershell/Test-Agentfiler.ps1`
ved siden av repoet. Kjør den fra repo-roten med `pwsh <sti>/Test-Agentfiler.ps1`. Skriptet leser
bare. Ta hvert funn med i rapporten med kategorien `skript`. Finnes ikke skriptet, hopp over
steget og skriv det under «Ikke verifisert».

**3. Kontroller hver faktapåstand mot koden:** stier, klasse- og metodenavn,
konfigurasjonsnøkler, kommandoer, statuser, flyter, regler og tall. Les koden påstanden gjelder,
ikke bare filnavnet. Er det mange påstander, kan kontrollen deles på subagenter per agentfil;
gi dem reglene over.

**4. Se etter:**

- utdatert innhold, særlig om autentisering (IDP, pakker, konfigurasjonsnøkler, hvilke ruter som
  er anonyme eller bevisst uten `[Authorize]`/`RequireAuthorization`), målrammeverk, testprosjekter
  og pipelines
- brutte pekere: lenker, stier og navn på klasser, metoder og referansefiler som ikke finnes
- innhold som speiler koden: enum-verdier, ruter, feltlister, grenseverdier og metodesignaturer
  som burde vært en peker til kildefilen
- duplisering mot `README.md`, `docs/` og lmr-skillen, og mellom `CLAUDE.md` og skillen
- feil plassering: arkitektur, bygg, konfigurasjon og arbeidsflyt hører hjemme i `CLAUDE.md`;
  domenekunnskap, forretningsregler og gotchas i skillen; kunnskap om én konkret kodebit i en
  kodekommentar; kunnskap som gjelder flere tjenester i lmr-skillen
- tidsavhengig tekst i skillen: «nå», «nylig», saksnumre, PR-numre og datoer for når noe ble
  endret. Historikk som fortsatt forklarer dagens kode, skal stå under «Tidligere løsninger».
- domenekunnskap som er tydelig i koden, men ikke dokumentert. Prioriter det en ny utvikler
  eller agent mest sannsynlig ville gjort feil: sikkerhet og autorisasjon, tap av data,
  stille feil, avvik fra konvensjoner og overraskende standardverdier.

**5. Kontroller mønsteret:**

- `CLAUDE.md` starter med `# CLAUDE.md` og `## Om tjenesten`, uten standardteksten fra `/init`,
  er under ca. 200 linjer og har kapitlene *Om tjenesten*, *Bygg, test og kjør*,
  *Databasemigreringer* (når repoet har database), *Arkitektur*, *Konvensjoner*, *CI/CD*,
  *Versjonering (semver)*, *CLAUDE.md-vedlikehold*, *Skill-vedlikehold* og, når repoet har et
  domenemodell-dokument, *Domenemodell-vedlikehold*.
- Vedlikeholdsreglene dekker oppdatering i samme commit, kunnskap fra økten (legges i repoet,
  ikke i auto-memory) og én samlet vurderingslinje etter en endring, med versjon.
- Repo-skillen heter `lmr-<navn>`, har `SKILL.md`, referansefiler i `references/` som alle lenkes
  direkte fra `SKILL.md` (ett nivå), `## Innhold` i referansefiler over 100 linjer, og
  `evals/evals.json` med minst tre scenarier.
- Hver lenke fra `SKILL.md` til en referansefil har en setning om når filen skal leses.
  Referansefiler lenker ikke videre til andre referansefiler.
- Frontmatter i hver `SKILL.md`: `name` er lik mappenavnet, er maks 64 tegn, har bare små
  bokstaver, tall og bindestrek, og inneholder ikke «claude» eller «anthropic». Sjekk dette selv
  også når `Test-Agentfiler.ps1` er kjørt.
- `.claude/settings.json` har marketplace `fhi-lmr` og `lmr@fhi-lmr` aktivert, og
  `.claude/settings.local.json` er ikke sjekket inn.
- `.azuredevops/pull_request_template.md` finnes med kapitlene *Endring*, *Versjon* (avkrysning
  for major / minor / patch, med taggen sist i PR-tittelen ved major og minor) og
  *Dokumentasjon vurdert* (avkrysning for `CLAUDE.md` og repo-skillen). Linjen
  `Domenemodell - <tjeneste>.docx` skal være med bare når repoet har et domenemodell-dokument.
  Du kan ikke se SharePoint herfra. Bruk derfor `CLAUDE.md` som kilde: har den kapitlet
  *Domenemodell-vedlikehold*, skal linjen være med.
- Pipelinen som validerer PR-er (normalt `<Navn>.CI.yml`), har steget
  `templates/agentfiler-sjekk.yaml@FhiLmrDevOps` og en `resources.repositories`-oppføring
  `FhiLmrDevOps` som peker til `Fhi.Legemiddelregisteret/Fhi.Lmr.DevOps`. Finnes ingen egen
  CI-pipeline, gjelder dette pipelinen som kjøres ved PR. Hvilken pipeline som kjøres ved PR,
  styres av branch policy og vises ikke i repoet. Går det ikke fram av pipeline-filene, merkes
  funnet `(usikkert)`.
  Unntak: finnes ikke `templates/agentfiler-sjekk.yaml` på `master` i Fhi.Lmr.DevOps, skal steget
  mangle, fordi PR-valideringen ellers feiler. Da er det ikke et funn. Kontroller dette med
  `git -C ../Fhi.Lmr.DevOps cat-file -e origin/master:templates/agentfiler-sjekk.yaml`. Klonen
  kan være utdatert, så skriv under «Ikke verifisert» hvilken commit på `origin/master` du
  sjekket. Finnes ikke klonen, skriv det der, og merk funnet `(usikkert)` hvis steget mangler.
- `AGENTS.md`, hvis den finnes, peker bare til `CLAUDE.md` og skillen.

**6. Vurder `description`** i hver `SKILL.md`: maks 1024 tegn, tredjeperson, sier både hva
skillen dekker og når den skal brukes, med konkrete triggerord fra domenet (begreper, statuser,
integrasjoner, typiske oppgaver), og avgrenser mot lmr-skillen. Generelle ord som «kode»,
«flyter» og «integrasjoner» er ikke nok. Står det noe om når skillen skal brukes i teksten under
frontmatter, hører det hjemme i `description`.

**7. Kontroller versjoneringskapitlet** mot `GitVersion.yml` (modus og hvilke brancher som er
mainline) og mot standardteksten:

- hver merge til `develop` gir patch-bump, med mindre merge-commiten har en `+semver`-tagg
- taggen står sist i PR-tittelen, i parentes, med et eksempel fra dette repoet (ikke fra et
  annet repo)
- major, minor og patch er definert for kallere og drift av tjenesten, og ved tvil velges det
  høyeste nivået. Definisjonene skal stemme med kortformen under (tagformat: `+semver: minor`):
  - major: brudd i API- eller meldingskontrakter, fjernede/omdøpte endepunkter og felt,
    konfignøkler som må endres ved deploy, nye krav til autentisering/scope
  - minor: ny bakoverkompatibel funksjonalitet
  - patch: feilretting, refaktorering, dokumentasjon, tester og avhengigheter uten endret
    oppførsel
- Claude vurderer versjonsnivået for hver endring og foreslår PR-tittel med tagg
- PR-er fullføres med squash-merge, og den foreslåtte merge-meldingen endres ikke

**8. Kjør evalueringene** i `.claude/skills/*/evals/evals.json`. Start én ny subagent per
scenario, uten kontekst fra gjennomgangen. Gi den bare repo-stien, skillene i `skills`,
`query` og regelen om bare lesing, ikke `expected_behavior`. Kontroller svaret mot
`expected_behavior` og mot koden. Et scenario feiler når svaret bommer på et punkt i
`expected_behavior`, eller når `expected_behavior` selv er feil mot koden. Rapporter hvert
scenario som feiler, som et funn med kategorien `evals`.

**9. Se etter persondata, hemmeligheter og miljøspesifikke ID-er** i agentfilene: navn,
fødselsnumre, tokens, passord, connection strings, ClientId, tenant- og abonnement-ID-er,
sertifikat-thumbprints og navn på konkrete Azure-ressurser.

## Rapport

Én linje per funn, sortert etter alvorlighet (høy, middels, lav), og innenfor hvert nivå etter
fil:

```
[høy|middels|lav] [kategori] fil:linje – hva som står – hva koden viser (kildefil) – foreslått endring
```

- **høy**: får en agent eller utvikler til å gjøre feil med konsekvens, eller avslører
  persondata, hemmeligheter eller miljø-ID-er i agentfilene. Eksempler:
  - sikkerhetshull, for eksempel utdatert beskrivelse av autentisering eller autorisasjon
  - stille datatap som ikke er dokumentert, for eksempel at en hel batch forkastes og kalleren
    likevel får 200
  - utdatert målrammeverk, IDP eller pakke
  - feil bygg-, test- eller migreringskommando, eller en påstand om at det ikke finnes tester
    når det gjør det
- **middels**: unøyaktig eller mangelfull beskrivelse av en regel, en manglende gotcha som ikke
  gir datatap eller sikkerhetshull, duplisering, feil plassering eller en svak `description`.
- **lav**: mindre presiseringer, speiling av kode og kosmetiske avvik fra mønsteret.

Kategorier: `utdatert`, `brutt peker`, `speiler kode`, `duplisering`, `plassering`,
`tidsavhengig`, `udokumentert`, `description`, `versjonering`, `mønster`, `evals`, `sensitivt`,
`skript`.

Funn som ikke er verifisert mot koden, merkes `(usikkert)` etter kategorien. Avslutt svaret
med avsnittet **Ikke verifisert**: det som ikke kunne kontrolleres, for eksempel skriptet som
manglet, påstander om miljøer, portalinnstillinger og eksterne systemer, og domenemodell-
dokumentet (se `DOMENEMODELL-LESE-SKRIVE.md` i lmr-skillen). Ikke rett noe.

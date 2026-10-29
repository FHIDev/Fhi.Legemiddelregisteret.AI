# Introduksjon
Dette repoet skal inneholde skills for LMR sine tjenester

## VIKTIG: GitHub-repoet er en speiling

GitHub-repoet er en speiling av repoet i Azure DevOps. Endringer i dette repoet **må** gjøres i kilderepoet:

https://fhi.visualstudio.com/Fhi.Legemiddelregisteret/_git/Fhi.Lmr.AI

Endringer som gjøres direkte i GitHub-speilet vil bli overskrevet.

## Pluginene

Repoet er en Claude Code plugin-marketplace (`fhi-lmr`) med én plugin per skill. Hver plugin ligger i `plugins/<navn>/`:

- **`lmr`** – systemkunnskap om Legemiddelregisteret (LMR): repoer, tjenester, meldingsflyter, arkitektur og integrasjoner, samt teknisk veiledning for autentisering, .NET 10-oppgradering og domenemodeller.
- **`lmr-entraid`** – EntraId-ressursene bak tjenestene: hvordan `.Api`, `.Client.Web` og `.Client.Machine` settes opp og henger sammen, provisjonert med Bicep (Microsoft Graph-extensionen). Inneholder kjørbare referansemaler for alle fire variantene, sertifikat-scripts, og det som må bestilles fra NHN (admin consent, Groups Administrator).
- **`lmdi-fhir`** – kildebasert ekspert på LMDI-implementasjonsguiden (Legemiddeldata fra institusjon til Legemiddelregisteret): profiler, validering av JSON mot profilene, eksempler, bundle-struktur, extensions, valuesets, invariants og signert/kryptert innsending til LMR.

## Installasjon i Claude Code

Kjør disse slash-kommandoene i Claude Code:

1. Legg til marketplace:

   ```
   /plugin marketplace add FHIDev/Fhi.Legemiddelregisteret.AI
   ```

2. Installer pluginene du trenger:

   ```
   /plugin install lmr@fhi-lmr
   /plugin install lmr-entraid@fhi-lmr
   /plugin install lmdi-fhir@fhi-lmr
   ```

> Merk: Tidligere lå alle tre skillene i pluginen `lmr`. Har du installert `lmr@fhi-lmr` fra før,
> inneholder den nå bare skillen `lmr` etter `/plugin update`. Installer `lmr-entraid` og
> `lmdi-fhir` i tillegg hvis du trenger dem.

## Kommandoer

- **`/lmr-entraid:entraid-ny-tjeneste [tjeneste] [variant]`** (pluginen `lmr-entraid`) – kopierer EntraId Bicep-malene og
  skriptene ut fra pluginen til et repo du kontrollerer, og stilaserer parameterfila.
  Malene skal ikke redigeres i plugin-katalogen; den byttes ut ved `/plugin update`.
- **`/lmr:gjennomga-agentoppsett [sti til Test-Agentfiler.ps1]`** (pluginen `lmr`) – gjennomgår agentoppsettet
  (`CLAUDE.md`, `AGENTS.md`, `.claude/settings.json` og repo-skillene) i repoet du står i.
  Kommandoen kontrollerer hver påstand mot koden, kjører `Test-Agentfiler.ps1` fra
  Fhi.Lmr.DevOps og evalueringene i skillene, og rapporterer én linje per funn sortert etter
  alvorlighet. Den endrer ingen filer.

### Når gjennomgangen skal kjøres

Regelen om å oppdatere agentfilene i samme commit fanger ikke alt, særlig ikke når én endring
berører mange repoer. Kjør `/lmr:gjennomga-agentoppsett`:

- etter tverrgående endringer som berører flere tjenester, for eksempel ny autentisering,
  .NET-oppgradering eller endrede meldingskontrakter, i hvert berørte repo
- minst én gang per kvartal per repo
- før et repo tas i bruk av nye utviklere eller agenter

## Bekreft installasjonen

Deretter kan du bekrefte installasjonen med `/plugin`. Hver plugin aktiverer skillen sin (`lmr`, `lmr-entraid` eller `lmdi-fhir`) automatisk ved relevante spørsmål.

## Versjonering og oppdatering

Pluginene versjoneres på commit-SHA: hver commit i kilderepoet teller som en ny versjon. Det er ikke noe `version`-felt å bumpe manuelt, og enhver endring i en skill blir dermed tilgjengelig som en oppdatering automatisk.

Slik holder du din Claude Code oppdatert:

1. Hent nyeste fra marketplace:

   ```
   /plugin marketplace update fhi-lmr
   ```

2. Oppdater pluginene du har installert:

   ```
   /plugin update lmr@fhi-lmr
   /plugin update lmr-entraid@fhi-lmr
   /plugin update lmdi-fhir@fhi-lmr
   ```

Hvis du allerede har siste versjon, rapporterer `/plugin update` det. Du ser installert tilstand og tilgjengelige oppdateringer i `/plugin`-menyen.

> Merk: Siden GitHub-repoet er en speiling, må endringer gjøres i Azure DevOps-kilderepoet for at de skal nå brukerne.

# Introduksjon
Dette repoet skal inneholde skills for LMR sine tjenester

## VIKTIG: GitHub-repoet er en speiling

GitHub-repoet er en speiling av repoet i Azure DevOps. Endringer i dette repoet **må** gjøres i kilderepoet:

https://fhi.visualstudio.com/Fhi.Legemiddelregisteret/_git/Fhi.Lmr.AI

Endringer som gjøres direkte i GitHub-speilet vil bli overskrevet.

## Pluginen lmr

Repoet er en Claude Code plugin-marketplace. Pluginen `lmr` inneholder tre skills:

- **`lmr`** – systemkunnskap om Legemiddelregisteret (LMR): repoer, tjenester, meldingsflyter, arkitektur og integrasjoner, samt teknisk veiledning for autentisering, .NET 10-oppgradering og domenemodeller.
- **`lmr-entraid`** – EntraId-ressursene bak tjenestene: hvordan `.Api`, `.Client.Web` og `.Client.Machine` settes opp og henger sammen, provisjonert med Bicep (Microsoft Graph-extensionen). Inneholder kjørbare referansemaler for alle fire variantene, sertifikat-scripts, og det som må bestilles fra NHN (admin consent, Groups Administrator).
- **`lmdi-fhir`** – kildebasert ekspert på LMDI-implementasjonsguiden (Legemiddeldata fra institusjon til Legemiddelregisteret): profiler, validering av JSON mot profilene, eksempler, bundle-struktur, extensions, valuesets, invariants og signert/kryptert innsending til LMR.

## Installasjon i Claude Code

Kjør disse slash-kommandoene i Claude Code:

1. Legg til marketplace:

   ```
   /plugin marketplace add FHIDev/Fhi.Legemiddelregisteret.AI
   ```

2. Installer pluginen:

   ```
   /plugin install lmr@fhi-lmr
   ```

## Kommandoer

- **`/lmr:entraid-ny-tjeneste [tjeneste] [variant]`** – kopierer EntraId Bicep-malene og
  skriptene ut fra pluginen til et repo du kontrollerer, og stilaserer parameterfila.
  Malene skal ikke redigeres i plugin-katalogen; den byttes ut ved `/plugin update`.

## Bekreft installasjonen

Deretter kan du bekrefte installasjonen med `/plugin`. Pluginen aktiverer riktig skill (`lmr`, `lmr-entraid` eller `lmdi-fhir`) automatisk ved relevante spørsmål.

## Versjonering og oppdatering

Pluginen versjoneres på commit-SHA: hver commit i kilderepoet teller som en ny versjon. Det er ikke noe `version`-felt å bumpe manuelt, og enhver endring i en skill blir dermed tilgjengelig som en oppdatering automatisk.

Slik holder du din Claude Code oppdatert:

1. Hent nyeste fra marketplace:

   ```
   /plugin marketplace update fhi-lmr
   ```

2. Oppdater selve pluginen:

   ```
   /plugin update lmr@fhi-lmr
   ```

Hvis du allerede har siste versjon, rapporterer `/plugin update` det. Du ser installert tilstand og tilgjengelige oppdateringer i `/plugin`-menyen.

> Merk: Siden GitHub-repoet er en speiling, må endringer gjøres i Azure DevOps-kilderepoet for at de skal nå brukerne.

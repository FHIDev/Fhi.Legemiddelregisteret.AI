# Introduksjon
Dette repoet skal inneholde skills for LMR sine tjenester

## VIKTIG: GitHub-repoet er en speiling

GitHub-repoet er en speiling av repoet i Azure DevOps. Endringer i dette repoet **må** gjøres i kilderepoet:

https://fhi.visualstudio.com/Fhi.Legemiddelregisteret/_git/Fhi.Lmr.AI

Endringer som gjøres direkte i GitHub-speilet vil bli overskrevet.

## Pluginen lmr

Repoet er en Claude Code plugin-marketplace. Pluginen `lmr` inneholder to skills:

- **`lmr`** – systemkunnskap om Legemiddelregisteret (LMR): repoer, tjenester, meldingsflyter, arkitektur og integrasjoner, samt teknisk veiledning for autentisering, .NET 10-oppgradering og domenemodeller.
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

Deretter kan du bekrefte installasjonen med `/plugin`. Pluginen aktiverer riktig skill (`lmr` eller `lmdi-fhir`) automatisk ved relevante spørsmål.

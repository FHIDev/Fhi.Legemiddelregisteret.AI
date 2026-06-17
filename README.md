# Introduction 
Dette repoet skal inneholde skills for LMR sine tjenester

## Pluginen lmr

Repoet er en Claude Code plugin-marketplace. Pluginen `lmr` gir systemkunnskap om Legemiddelregisteret (LMR): repoer, tjenester, meldingsflyter, arkitektur og integrasjoner, samt teknisk veiledning for autentisering, .NET 10-oppgradering og domenemodeller.

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

Deretter kan du bekrefte installasjonen med `/plugin`. Pluginen aktiverer LMR-skillen automatisk ved relevante spørsmål.
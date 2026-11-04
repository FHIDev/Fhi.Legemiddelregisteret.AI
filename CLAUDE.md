# CLAUDE.md

Marketplace `fhi-lmr` med pluginene `lmr`, `lmr-entraid` og `lmdi-fhir` under `plugins/`.

## Versjonering av plugins

- Hver plugin har eksplisitt `version` i `.claude-plugin/marketplace.json`.
- Brukerne får bare oppdatering når `version` endres. Hver commit som endrer filer under
  `plugins/<navn>/` skal derfor bumpe `version` for akkurat den pluginen, i samme commit.
  Ikke bump pluginer som ikke er endret.
- `lmr` og `lmr-entraid`: vanlig semver. Patch for rettelser, minor for nytt innhold,
  major for brytende endringer.
- `lmdi-fhir`: formatet er `<LMDI-versjon>-<løpenummer>`, f.eks. `1.1.9-1`, `1.1.9-2`.
  - Endring i skillen uten ny LMDI-versjon: øk løpenummeret.
  - Ny LMDI-versjon (se `SKILL.md`): bytt LMDI-delen og start på `-1`, f.eks. `1.1.10-1`.
  - LMDI-delen må alltid stemme med versjonen som står i `SKILL.md`.

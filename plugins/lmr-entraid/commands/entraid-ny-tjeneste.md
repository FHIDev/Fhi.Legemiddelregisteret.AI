---
description: Kopier EntraId Bicep-maler og skript ut fra lmr-pluginen til et repo du kontrollerer, ferdig stilaset for en LMR-tjeneste
argument-hint: "[tjenestenavn] [variant]"
---

Brukeren skal sette opp EntraId-app-registreringer for en LMR-tjeneste.

`$1` = tjenestenavn uten `Fhi.`-prefiks (f.eks. `Lmr.Grunndata`). `$2` = variant.
Begge kan være tomme — avklar da med brukeren i stedet for å gjette.

## Hvorfor denne kommandoen finnes

Malene ligger i pluginen, men **den utfylte fila hører hjemme i `entraid/tjenester/<tjeneste>/`
i repoet Fhi.Lmr.AI**, der fasiten for alle app-registreringene ligger. Plugin-katalogen byttes
ut ved `/plugin update`, så alt som redigeres der går tapt. Denne kommandoen kopierer derfor
malene ut.

## Steg

**1. Last skillen.** Les `${CLAUDE_PLUGIN_ROOT}/skills/lmr-entraid/SKILL.md` hvis den ikke
allerede er lastet. Den har variant-velgeren, navnekonvensjonene og miljøregelen.

**2. Avklar variant** hvis `$2` er tom:

| Tjenesten... | Mal |
|---|---|
| eksponerer API, kaller ingen | `m2m-api` |
| kaller andre, eksponerer ingenting | `m2m-client-machine` |
| begge deler (vanligst) | begge |
| har brukerinnlogging | `brukerinnlogging` |
| er en SPA | `spa` (ingen LMR-tjeneste bruker denne) |

**3. Avklar miljø.** M2M: `Test` og `Prod`. Brukerinnlogging: eget app-reg per miljø
(`Dev`/`Test`/`QA`/`Prod`) — les miljøregelen i SKILL.md og forklar den hvis brukeren velger
noe annet.

**4. Finn målkatalogen.** Den er `entraid/tjenester/<tjeneste>/` i en klone av Fhi.Lmr.AI
(tjenestenavnet med små bokstaver, uten `Fhi.`/`Lmr.`, f.eks. `grunndata`). Spør hvor klonen
ligger hvis du ikke står i den. **Ikke** legg filene i tjenestens eget repo.

**4b. ⛔ Sjekk hver app-registrering malen vil opprette.** Utled de konkrete `uniqueName`-ene
for valgt variant og miljø (`fhi-<navn>-api-<miljo>`, `fhi-<navn>-client-machine-<miljo>`,
`fhi-<navn>-client-web-<miljo>`), og se etter hver av dem i `entraid/baseline/`:

- **Ingen finnes:** fortsett.
- **Noen finnes:** malen brukes bare til å opprette, og en deploy mot en eksisterende
  app-registrering kan overskrive verdier og erstatte lister som kantene. Velg en variant som bare
  oppretter det som mangler — f.eks. kun `m2m-client-machine` når `.Api` finnes og tjenesten skal
  få sin første klient. Finnes alt, stopp: en ny kant på en eksisterende klient gis med
  `entraid/scripts/legg-til-kant.sh`.

`sjekk-uniquename.sh` gjør samme kontroll mot Entra rett før deploy og stopper hvis et navn finnes.

**5. Kopier fra `${CLAUDE_PLUGIN_ROOT}/skills/lmr-entraid/bicep/`:**

Alltid:
- `bicepconfig.json`
- `moduler/api-applikasjon.bicep` (kun hvis varianten bruker den — alle utenom `m2m-client-machine`)

Per valgt variant: `<variant>.bicep` + `<variant>.bicepparam`

**Ikke** kopier `scripts/`. Skriptene brukes fra pluginen i samme repo
(`plugins/lmr-entraid/skills/lmr-entraid/bicep/scripts/`), så det finnes én versjon av dem.

**6. Tilpass parameterfila.** Døp den om til `<variant>-<miljo>.bicepparam` (f.eks.
`m2m-api-test.bicepparam`, slik at `m2m-api` og `m2m-client-machine` ikke kolliderer), og fyll inn:
- `tjenesteNavn` og `miljo` fra argumentene
- **nye stabile UUID-er** for app-roller og scopes — generér dem nå (`uuidgen` eller
  `[guid]::NewGuid()`) og skriv dem inn. De skal aldri endres senere.
  ⚠️ **Unntak:** bruker tjenesten det felles LMR-rollesettet (brukerinnlogging), skal
  UUID-ene i `brukerinnlogging.bicepparam` **kopieres som de er** — de er allerede i bruk i
  EntraID, og nye UUID-er ville gjort rollene appspesifikke.
- `eiere` — hent brukerens object-id med `az ad signed-in-user show --query id -o tsv`.
  **I Prod** skal fagpersonen også være eier (LMR: Kari, Grossiststatistikken: Kristine) — se
  `references/NHN-OG-ADMIN.md`.

La sertifikat-base64 og callee-IDer stå som placeholder; de fylles inn når sertifikatet er
generert og callee-tjenestene er kjent.

**7. Ikke deploy.** Denne kommandoen stilaserer bare. Fortell brukeren hva som gjenstår.
Skriptene ligger i `plugins/lmr-entraid/skills/lmr-entraid/bicep/scripts/` (forkortet `S`):

1. Generér sertifikat — `${CLAUDE_PLUGIN_ROOT}/skills/lmr-entraid/cert-tooling/` (kun for
   klient-app-regene; rene ressurser trenger det ikke)
2. `base64 -w0 <navn>.cer` inn i `.bicepparam`
3. `S/sjekk-uniquename.sh <uniqueName> …` — må gi exit 0. Stopper den, finnes app-registreringen
   allerede: **ikke deploy**, bruk `entraid/scripts/legg-til-kant.sh`
4. `az deployment group create -g <rg> --template-file <variant>.bicep --parameters <fil>.bicepparam`
5. Baseline for hver ny app-registrering:
   `S/verifiser.sh <uniqueName> > ny.json && mv ny.json entraid/baseline/<uniqueName>.json`
6. M2M-kanter fra en ny `.Client.Machine`: `entraid/scripts/legg-til-kant.sh` per callee
7. Commit parameterfil, baselines og `KALL-GRAF-ENTRAID.md` i samme PR i Fhi.Lmr.AI
8. Delegerte scopes krever admin consent fra NHN — se `references/NHN-OG-ADMIN.md`

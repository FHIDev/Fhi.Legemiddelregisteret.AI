---
description: Kopier EntraId Bicep-maler og skript ut fra lmr-pluginen til et repo du kontrollerer, ferdig stilaset for en LMR-tjeneste
argument-hint: "[tjenestenavn] [variant]"
---

Brukeren skal sette opp EntraId-app-registreringer for en LMR-tjeneste.

`$1` = tjenestenavn uten `Fhi.`-prefiks (f.eks. `Lmr.Grunndata`). `$2` = variant.
Begge kan være tomme — avklar da med brukeren i stedet for å gjette.

## Hvorfor denne kommandoen finnes

Malene ligger i pluginen, men **den utfylte fila hører hjemme i et repo brukeren
kontrollerer**. Plugin-katalogen byttes ut ved `/plugin update`, så alt som redigeres der går
tapt. Denne kommandoen kopierer derfor malene ut.

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

**4. Avklar målkatalog.** Foreslå `infra/entraid/` i tjenestens eget repo hvis du står i et.
Spør hvis du er usikker — ikke skriv filer utenfor det brukeren forventer.

**5. Kopier fra `${CLAUDE_PLUGIN_ROOT}/skills/lmr-entraid/bicep/`:**

Alltid:
- `bicepconfig.json`
- `moduler/api-applikasjon.bicep` (kun hvis varianten bruker den — alle utenom `m2m-client-machine`)
- `scripts/` (alle tre)

Per valgt variant: `<variant>.bicep` + `<variant>.bicepparam`

**6. Tilpass parameterfila.** Døp den om til `<tjeneste>-<miljo>.bicepparam`, og fyll inn:
- `tjenesteNavn` og `miljo` fra argumentene
- **nye stabile UUID-er** for app-roller og scopes — generér dem nå (`uuidgen` eller
  `[guid]::NewGuid()`) og skriv dem inn. De skal aldri endres senere.
  ⚠️ **Unntak:** bruker tjenesten det felles LMR-rollesettet (brukerinnlogging), skal
  UUID-ene i `brukerinnlogging.bicepparam` **kopieres som de er** — de er allerede i bruk i
  EntraID, og nye UUID-er ville gjort rollene appspesifikke.
- `eiere` — hent brukerens object-id med `az ad signed-in-user show --query id -o tsv`

La sertifikat-base64 og callee-IDer stå som placeholder; de fylles inn når sertifikatet er
generert og callee-tjenestene er kjent.

**7. Ikke deploy.** Denne kommandoen stilaserer bare. Fortell brukeren hva som gjenstår:

1. Generér sertifikat — `${CLAUDE_PLUGIN_ROOT}/skills/lmr-entraid/cert-tooling/` (kun for
   klient-app-regene; rene ressurser trenger det ikke)
2. `base64 -w0 <navn>.cer` inn i `.bicepparam`
3. `./scripts/sjekk-uniquename.sh <uniqueName>` — bekreft OPPRETTER vs. OPPDATERER
4. `az deployment group create -g <rg> --template-file <variant>.bicep --parameters <fil>.bicepparam`
5. `./scripts/verifiser.sh <uniqueName> > baseline.json`
6. Admin consent — se `references/NHN-OG-ADMIN.md`

**8. Nevn kort** at malene bevisst kopieres ut fordi det ikke finnes et felles infra-repo for
EntraId i dag, og at et slikt repo kan opprettes senere hvis teamet vil samle oppsettet ett
sted. Ikke gjør noe med det nå.

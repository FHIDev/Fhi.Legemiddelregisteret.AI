# EntraID-fasit for LMR og Grossiststatistikken

Denne katalogen er fasiten for app-registreringene til LMR og Grossiststatistikken i FHI-tenanten
(`54475f80-1baa-4ea9-9185-c0de5cc603fe`): hvilke som finnes, hvordan de ser ut, og Bicep-oppsettet
for dem som forvaltes med Bicep.

Katalogen ligger bevisst **utenfor `plugins/`**. `plugins/` distribueres som cache til alle som har
installert pluginene, og byttes ut ved `/plugin update`. Endringer her gir ingen ny pluginversjon.

Malene, skriptene og forklaringen av modellen står i skillen `lmr-entraid`
(`plugins/lmr-entraid/skills/lmr-entraid/`). Denne katalogen inneholder bare tilstanden.

## Innhold

| | |
|---|---|
| `baseline/<uniqueName>.json` | Tilstanden til hver app-registrering, skrevet av `verifiser.sh`. Én fil per app-registrering. |
| `tjenester/<tjeneste>/` | Utfylte Bicep-maler og parameterfiler for tjenester som forvaltes med Bicep. |
| `adopsjon-uniquename.tsv` | Mappingen som ga de eksisterende app-registreringene `uniqueName` 25. november 2026. |
| `scripts/adopter-uniquename.sh` | Skriptet som satte dem. |
| `KALL-GRAF.md` | Hvem kaller hvem, også kanter utenfor EntraID (HelseID, Maskinporten). |
| `KALL-GRAF-ENTRAID.md` | Alle EntraID-kanter, generert fra baselinene med `scripts/lag-kall-graf.sh`. |
| `scripts/legg-til-kant.sh` | Det eneste skriptet for å endre en eksisterende app-registrering: legger til en m2m-kant, og kan ikke fjerne noe. |

Fasiten dekker både LMR og Grossiststatistikken fordi app-registreringene henger sammen på tvers
av tjenester: en kant mellom to tjenester er én endring, og den skal være én PR.

## Hvorfor samlet her, og ikke i hver tjeneste

En m2m-kant endrer kallerens `.Client.Machine`, mens app-rollen den peker på tilhører callee. Med
fasiten spredt på tjenesterepoene ville én kant blitt to PR-er i to repoer, og den som vil se alle
kallerne til en tjeneste, måtte lett gjennom 22 repoer.

## `uniqueName`

Alle app-registreringene har `uniqueName` etter mønsteret `fhi-<navn>-<rolle>-<miljo>`, med små
bokstaver, for eksempel `fhi-lmr-grunndata-api-test` og `fhi-grossiststatistikken-client-web-prod`.
Navnet følger visningsnavnet, så `Fhi.Reservasjonsregister` blir `fhi-reservasjonsregister-…` uten
`lmr`.

⚠️ `uniqueName` er **immutable**. Det er nøkkelen både `verifiser.sh` og Bicep-extensionen bruker
for å finne app-registreringen.

Av de 83 fikk 82 navnet satt med `scripts/adopter-uniquename.sh` ut fra `adopsjon-uniquename.tsv`
(DataproduktFormidler ble laget med Bicep og hadde det fra før). Det endret ikke appId, tokens,
consent eller sertifikater. Skriptet tørrkjører uten `--utfor` og hopper over app-registreringer
som allerede har navnet.

⚠️ **Sikkerhetsgruppene har ingen `uniqueName`.** Bicep-malene refererer dem derfor med object ID
(`gruppeObjektId`).

Ikke med, bevisst:

- `Fhi.Lmr.PimPilot - Test` — pilotappen for PIM, skal slettes
- `fhi-Fhi.Legemiddelregisteret-8a969e96-…` — ser ut som en tjenestetilkobling fra DevOps

## Sjekke drift

```bash
V=../plugins/lmr-entraid/skills/lmr-entraid/bicep/scripts/verifiser.sh
for f in baseline/*.json; do bash "$V" "$(basename "$f" .json)" "$f" || true; done
```

`verifiser.sh` sammenligner dagens tilstand i Entra mot baselinen og viser en diff ved avvik:
kanter, app-roller, scopes, redirect-URI-er, sertifikat-thumbprints, eiere, rolletildelinger
appen har **gitt** som ressurs (`appRoleAssignedTo`: kallere og grupper) og rolletildelinger den har
**fått** som kaller (`appRoleAssignments`). Delegert consent (`oauth2PermissionGrants`) er ikke med.
Baselinen inneholder bare ID-er, ingen navn. Det tar 10–15 minutter for alle, fordi hvert
`az rest`-kall starter en ny prosess.

Et avvik betyr ikke at noe er galt — det betyr at Entra ikke lenger stemmer med fasiten. Er
endringen tilsiktet, skriv ny baseline i samme PR som forklarer den:

```bash
bash "$V" <uniqueName> > ny.json && mv ny.json baseline/<uniqueName>.json
```

(Via en temp-fil: feiler skriptet, skriver det ingenting, og da skal ikke baselinen tømmes.)

⚠️ **Forventet avvik: sertifikatrotering.** `Fhi.Lmr.SertifikatFornyelse` bytter LMR-sertifikatene
automatisk når det er under fire uker til utløp, og da endres `sertifikatThumbprints`. Skriv ny
baseline. Baselinen inneholder ikke utløpsdatoen; se `SERTIFIKATER.md` i skillen.

## Sjekke eierskap i Prod

```bash
bash scripts/sjekk-prod-eiere.sh            # alle fagområder
bash scripts/sjekk-prod-eiere.sh lmr        # bare LMR (Kari)
bash scripts/sjekk-prod-eiere.sh grossist   # bare Grossiststatistikken (Kristine)
```

Melder hver prod-app-registrering som har en annen eier enn fagpersonen (LMR: Kari, pluss
`mi-lmr-sertifikatfornyelse-prod` på `Client.*`; Grossiststatistikken: Kristine), eller som mangler
fagpersonen. Leser bare baselinene og endrer ingenting — kjør driftsjekken over først hvis du vil
være sikker på at de stemmer med Entra. Bakgrunn: «Eierskap og tilgang» i `NHN-OG-ADMIN.md`.
Fagområdet avgjøres av prefikset i `uniqueName` (`fhi-lmr-` / `fhi-grossiststatistikken-`). Et ukjent
prefiks gir avvik, slik at en ny tjeneste ikke stille regnes med til feil fagområde.
Reservasjonsregister er utenfor fagperson-modellen og hoppes over.

## Endre en app-registrering

### Rettigheter

- **Ny app-registrering** (alle miljøer): aktiver PIM-rollen `Application Developer` først. Den
  utløper, og gir da `Authorization_RequestDenied` på `POST /applications`.
- **Alt i Prod**, også `legg-til-kant.sh` mot `…-prod`: aktiver PIM-gruppen for fagområdet og vent
  på godkjenning før du skriver noe. I Dev/Test/QA er utviklerne faste eiere, og ingen PIM trengs.

Se «Rettigheter før du skriver i Entra» i skillen `lmr-entraid` og `NHN-OG-ADMIN.md` der.

### ⛔ Grunnregel: ingenting som finnes, skal overskrives

**Bicep-malene brukes bare til å OPPRETTE nye app-registreringer.** En Bicep-mal beskriver hvordan
app-registreringen *skal se ut*, ikke hva som skal legges til. Deployes den mot en app-registrering
som finnes fra før (samme `uniqueName`), settes de deklarerte propertyene til malens verdi — og en
mal som ikke har med alt, kan fjerne kanter, roller og redirect-URI-er. Det finnes ingen `what-if`
som viser det på forhånd.

Merk at målingene i skillen viser at properties malen *ikke* deklarerer, blir stående. Risikoen er
deklarerte lister (kantene, app-rollene, redirect-URI-ene): det er ikke målt hva som skjer når malen
har færre elementer enn Entra, og Graph erstatter normalt hele lista.

Derfor:

| Hva | Hvordan |
|---|---|
| Ny app-registrering | Bicep, én gang. `sjekk-uniquename.sh` stopper hvis navnet finnes. |
| Ny kant på en eksisterende klient | `scripts/legg-til-kant.sh` — kan bare legge til |
| Annen endring på en eksisterende app-registrering | Manuelt mot Graph, med `verifiser.sh` før og etter. Spør først. |
| Fjerne noe | Manuelt, bevisst, aldri via et skript eller en mal |

En parameterfil i `tjenester/` er altså en beskrivelse av hvordan app-registreringen ble **laget**.
Den deployes ikke på nytt. Fasiten for hvordan den ser ut **nå**, er baselinen.

Terraform-oppsettet (`Fhi.Lmr.Terraform`) er **pensjonert** og skal ikke kjøres. Modulene der
gjenskaper app-registreringen med ny appId når en kant eller et sertifikat endres.

### Ny tjeneste

1. `/lmr-entraid:entraid-ny-tjeneste` legger malene i `tjenester/<tjeneste>/`.
2. `sjekk-uniquename.sh <uniqueName> …` rett før deploy — må gi exit 0.
3. Deploy.
4. Baseline for hver ny app-registrering (se «Sjekke drift» for kommandoen).
5. Kanter fra en ny `.Client.Machine`: `scripts/legg-til-kant.sh` for hver callee. Malen gir
   ikke rolletildelingene selv (`giAdminConsent = false`).
6. Commit parameterfiler, baselines og `KALL-GRAF-ENTRAID.md` i samme PR.

### Når en deploy feiler halvveis

Kjør `sjekk-uniquename.sh` med de samme navnene:

- **Ingen av dem finnes** (exit 0): ingenting ble opprettet. Rett årsaken og deploy på nytt.
- **Noen finnes** (exit 2): **ikke deploy på nytt.** Ta en baseline av det som finnes, og
  sammenlign med malen for å se hva som mangler. Typiske rester:
  - `identifierUris` mangler (pass 2 feilet): `az ad app update --id <appId> --identifier-uris api://<appId>`
  - service principal mangler (replikering): `az ad sp create --id <appId>`
  - rolletildelinger mangler: `scripts/legg-til-kant.sh`

  Skriv baseline når alt er på plass.

### Ny kant på en eksisterende klient

```bash
./scripts/legg-til-kant.sh <kaller-client-machine> <callee-api>            # tørrkjøring
./scripts/legg-til-kant.sh --utfor <kaller-client-machine> <callee-api>
git diff -- baseline/
```

Skriptet stopper uten å skrive noe hvis:

- az står på feil tenant
- kaller ikke er en `…-client-machine-<miljo>` eller callee ikke er en `…-api-<miljo>`
- miljøene ikke passer: lovlig er samme miljø, eller kaller i `dev`/`qa` og callee i `test`
  (m2m-API-ene finnes bare i Test og Prod)
- en av dem mangler baseline, **eller Entra ikke stemmer nøyaktig med baselinen** — ukjent drift
  skal forstås før noen endrer noe
- callee ikke har nøyaktig én aktiv application-rolle (oppgi rolleverdien som tredje argument)
- den nye kantlista ikke er nøyaktig den gamle pluss kanten

Etter hvert steg leser det tilstanden på nytt og sammenligner med **forventet tilstand** — den gamle
baselinen pluss nøyaktig denne kanten og tildelingen. Bare da skrives ny baseline; har noen andre
endret noe underveis, stopper det med en diff i stedet for å gjøre endringen til ny fasit.

Etter skriving gir det rolletildelingen
(application permission — eier av callee, eller i prod den som har aktivert PIM-gruppen, kan gi
den selv), og skriver nye baselines og kall-grafen. `git diff` viser da nøyaktig hva som ble lagt
til, og er det som reviewes i PR-en.

Avbrytes skriptet etter at kanten er lagt til, men før rolletildelingen er gitt, er kallerens
baseline allerede oppdatert. Kjør det på nytt; det gir da bare tildelingen.

### Samtidige kjøringer

⚠️ **Bare én person endrer samme klient eller samme API om gangen.** Reserver begge i Teams-kanalen
**Team A-informasjonsgruppe** før `--utfor`:

1. Se etter en åpen reservasjon som nevner kalleren **eller** API-et. Finnes den, vent.
2. Skriv `🔒 <kaller-uniqueName> → <callee-api-uniqueName>` i kanalen.
3. Les kanalen på nytt. Har noen andre postet en reservasjon som nevner kalleren eller API-et,
   gjelder **den som står først i kanalen**. Står din etter, svarer du `↩️ trukket` i din egen
   tråd og venter. Først når din reservasjon er den eldste åpne for begge navnene, kan du fortsette.
4. Kjør `--utfor`, og commit baselinene og kall-grafen.
5. Svar `✅ ferdig` i samme tråd når commiten er pushet. Da er begge frigitt.

Kalleren reserveres fordi PATCH erstatter hele kantlista dens. API-et reserveres fordi skriptet
også gir rolletildelingen og skriver API-ets baseline: to klienter som får rolle på samme API
samtidig, forventer hver sin «gammel baseline pluss min tildeling», og sluttkontrollen stopper da
uten at API-baselinen blir oppdatert. To personer kan trygt jobbe samtidig når de verken deler
kaller eller API.

Graph har ingen betinget oppdatering for app-registreringer, og skriptet har ingen lås. To
samtidige kjøringer mot samme klient kan derfor begge gå grønt, og da overskriver den siste kanten til den første i
`requiredResourceAccess`. Rolletildelingen, som er det som gir rollen i tokenet, blir stående. Når
begge PR-ene er merget, stemmer ikke baselinen lenger med Entra: neste kjøring mot klienten stopper,
og driftsjekken viser avviket.

**Gjenopprette en tapt kant.** Skriptet kan ikke bare kjøres på nytt, fordi det stopper når Entra
avviker fra baselinen. Gjør det slik, fra `entraid/` på en oppdatert main:

```bash
V=../plugins/lmr-entraid/skills/lmr-entraid/bicep/scripts/verifiser.sh
K=<kaller-client-machine>

C=<callee-api>

# 0. Reserver kalleren og API-et (se over) FØR første oppslag mot Entra.

# 1. Hent Entra ÉN gang, og sammenlign akkurat denne fila med baselinen.
#    Diffen skal vise NØYAKTIG én manglende kant i requiredResourceAccess, ingenting annet.
#    Viser den mer, stopp: slett ny.json og finn ut hva som har skjedd.
bash "$V" "$K" > ny.json
git diff --no-index -- "baseline/$K.json" ny.json

# 2. Først når diffen bare viser den tapte kanten: flytt NØYAKTIG den fila inn som baseline.
mv ny.json "baseline/$K.json"

# 3. Legg kanten til igjen. Rolletildelingen finnes fra før.
./scripts/legg-til-kant.sh --utfor "$K" "$C"

# 4. Baselinene skal nå være identiske med dem i main igjen. Ingen diff = gjenopprettet.
git diff --exit-code -- "baseline/$K.json" "baseline/$C.json" KALL-GRAF-ENTRAID.md
```

Delegerte kanter (brukerinnlogging, `scp`) og Microsoft Graph-tillatelser støttes ikke — de
krever admin consent fra NHN uansett, se `NHN-OG-ADMIN.md` i skillen.

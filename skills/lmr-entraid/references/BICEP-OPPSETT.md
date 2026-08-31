# Bicep-oppsett for EntraId-ressurser

Hvordan du faktisk provisjonerer app-registreringer i LMR. Les denne før første deploy.

## Hvorfor Bicep

EntraID er **ikke** Azure Resource Manager. Bicep alene kan ikke røre app-registreringer — det
er **Microsoft Graph Bicep-extensionen** som gjør det, og den ble **GA 29. juli 2025**.

Alternativene er portalen (uten sporbarhet) eller egne `az rest`-skript (som fort blir
imperative og udokumenterte). Bicep gir:

| | |
|---|---|
| Deklarativt | App-reg, service principal, roller, tillatelser og consent i én fil |
| Idempotent | `uniqueName` gir upsert — samme fil kan kjøres om igjen uten å opprette duplikater |
| Ingen state | Ingenting lokalt som kan mistes eller komme ut av synk |
| Eierskap deklareres | `owners` er en property, ikke en bivirkning av hvilken auth-path du brukte |
| Reviewbart | Alt som endrer en app-registrering er en `git diff` |

Les også [«Hva en re-deploy FAKTISK gjør»](#-hva-en-re-deploy-faktisk-gjør--målt-ikke-antatt)
lenger ned — Bicep konvergerer **ikke** mot malen, og det er viktigere å vite enn det høres ut.

## Oppsett

`bicepconfig.json` ved siden av malene:

```json
{
  "experimentalFeaturesEnabled": { "extensibility": true },
  "extensions": {
    "microsoftGraphV1": "br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:1.0.0"
  }
}
```

Øverst i hver `.bicep`:

```bicep
extension microsoftGraphV1
```

**`1.0.0` er den eneste GA-versjonen.** Målt i MCR er de publiserte taggene
`0.1.8-preview`, `0.1.9-preview`, `0.2.0-preview` og `1.0.0`. Bruk `1.0.0`.

## Deploy

LMR har Azure-abonnement, så **deploy på resource-group-scope**:

```bash
az account set --subscription FHI-LMR-Dev
az deployment group create -g <resource-group> \
  --template-file m2m-api.bicep \
  --parameters m2m-api.bicepparam
```

Resource-gruppa er bare et sted ARM lagrer deployment-historikken — ingen Azure-ressurser
opprettes der.

⚠️ **Ikke bruk tenant-scope** (`az deployment tenant create`). Den varianten finnes for tenanter
uten Azure-abonnement og krever `Owner` på `/`-scope, som igjen krever at man eleverer seg til
User Access Administrator. Unødvendig hos oss, og admin-gated.

## `uniqueName` — idempotensnøkkelen

`uniqueName` er **påkrevd** og **immutable** på `Microsoft.Graph/applications` og
`Microsoft.Graph/groups`. Extensionen bruker den til upsert: finnes den, oppdateres appen;
finnes den ikke, opprettes en ny.

Det gjør at samme fil kan kjøres om igjen uten å opprette duplikater — men det flytter
risikoen ett sted: **en skrivefeil i `uniqueName` oppretter en ny app-registrering** med ny
appId, stille.

Derfor: kjør **`scripts/sjekk-uniquename.sh`** før hver deploy. Den sier OPPDATERER eller
OPPRETTER for hver `uniqueName`.

Konvensjon: `fhi-lmr-<tjeneste>-<rolle>-<miljo>`, små bokstaver.

⚠️ Oppretter du feil: `uniqueName` frigjøres ikke ved sletting alene. Appen soft-slettes og
ligger 30 dager i papirkurven. Tøm den:
```bash
az rest --method DELETE --uri "https://graph.microsoft.com/v1.0/directory/deletedItems/<objectId>"
```

## `owners` — eierskap deklareres

```bicep
owners: {
  relationships: eiere          // string[] med OBJECT-IDer
  relationshipSemantics: 'append'
}
```

⚠️ **`relationships` er `string[]` i extension 1.0.0** — ikke `[{ id: '...' }]`, som
Learn-referansen for `Microsoft.Graph/applications` viser. Objektformen gir `BCP036`.
Målt med `bicep build`; Learn beskriver en nyere type enn den som er publisert.

`'append'` lar eiere satt utenfor malen stå. `'replace'` ville fjernet dem.

Finn din egen object-id: `az ad signed-in-user show --query id -o tsv`

## ⚠️ `identifierUris` krever to pass

`appId` tildeles av Graph først ved opprettelse, og Bicep tillater ikke at en ressurs refererer
sin egen `appId`:

```
BCP079: This expression is referencing its own declaration, which is not allowed.
```

Løsningen er en liten modul (`moduler/api-applikasjon.bicep`) som kalles to ganger: pass 1
oppretter appen, pass 2 setter `identifierUris: ['api://${pass1.outputs.appId}']`. Samme
`uniqueName` i begge, så pass 2 oppdaterer — den oppretter ikke en ny.

Pass 2 er en **fullstendig** deklarasjon, ikke en delvis. Målt oppførsel er merge-semantikk,
så en delvis deklarasjon ville også "virket" — men da ville pass 2 stilltiende bevart alt
pass 1 satte, og malen ville sluttet å være autoritativ. Hold den fullstendig.

**Verifisert:** to pass gir én app-registrering, uendret `appId`, og
`identifierUris = api://<appId>`.


## ⚠️ For-uttrykk kan ikke stå inne i `concat()`

```
BCP138: For-expressions are not supported in this context.
```

Bygger du `requiredResourceAccess` av flere lister, må hver løkke hoistes til en `var` først:

```bicep
var calleeAccess = [for c in callees: { resourceAppId: c.apiAppId, resourceAccess: [...] }]
var graphAccess  = krevGraph ? [ ... ] : []
// og så:
requiredResourceAccess: concat(calleeAccess, graphAccess)
```

## ⚠️ En app-rolle eller et scope kan ikke fjernes mens det er aktivt

Graph avviser det:

```
CannotDeleteOrUpdateEnabledEntitlement:
Permission (scope or role) cannot be deleted or updated unless disabled first.
```

Det slår inn når du fjerner en rolle fra `appRoles`, bytter `id` på den, eller endrer
`allowedMemberTypes` — altså når rollen i praksis erstattes.

**Å endre `value` eller `displayName` på en rolle som beholder samme `id` er derimot greit**
(verifisert).

**Fjerning krever to deployer:**

1. Behold rollen i malen, men sett `isEnabled: false`. Deploy.
2. Fjern rollen fra malen. Deploy.

⚠️ Kombinert med at en re-deploy ikke fjerner udeklarerte properties (se over): å bare stryke
rollen fra malen gjør **ingenting**. Den blir stående.

## Brownfield — adoptere eksisterende app-registreringer

LMR har allerede ~31 app-registreringer i Entra fra før Bicep ble tatt i bruk. De ble
provisjonert med et eldre verktøyoppsett som **ikke er tilgjengelig for teamet**, så i praksis
er de i dag ikke forvaltet av noe som helst — de kan bare endres i portalen, eller adopteres
inn i en Bicep-mal.

Kjennetegnet på en slik app-registrering: **den har ingen `uniqueName`.** Etterfyll den én
gang, så kan malen ta over:

```bash
az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications/<OBJECT-ID>" \
  --headers "Content-Type=application/json" \
  --body '{"uniqueName":"fhi-lmr-mintjeneste-api-test"}'
```

⚠️ **`<OBJECT-ID>`, ikke `appId`.** De to forveksles lett.
⚠️ Immutable etterpå — du får ett forsøk.

Samme for grupper (`/v1.0/groups/<objectId>`). Etterpå kan de refereres:

```bicep
resource gruppe 'Microsoft.Graph/groups@v1.0' existing = {
  uniqueName: 'a-fhi-app-lmr-test-godkjenn'
}
```

En service principal kan refereres på `appId` uten `uniqueName`:

```bicep
resource sp 'Microsoft.Graph/servicePrincipals@v1.0' existing = { appId: '<appId>' }
```

Finn en eksisterende app-registrering og dens object-id:

```bash
az ad app list --display-name "Fhi.Lmr.<Tjeneste>.Api - Test"   --query "[0].{appId:appId, objectId:id, uniqueName:uniqueName}" -o json
```

⚠️ Skriv malen slik at den matcher **det som faktisk står i Entra** før du deployer — kjør
`scripts/verifiser.sh` først og bruk output som fasit. Deployer du en mal som mangler noe app-
registreringen har, blir det stående (se «Hva en re-deploy FAKTISK gjør»), men deployer du feil
*verdier*, blir de skrevet over.

## ⚠️ Det finnes ingen `what-if`

Graph-ressurser støtter ikke `az deployment ... what-if`
([Azure/bicep#17743](https://github.com/Azure/bicep/issues/17743), åpen siden august 2025).

Det betyr at du ikke får se hva en deploy kommer til å gjøre før du kjører den. To skript
dekker de to tingene som faktisk kan gå galt:

| Skript | Når | Hva det fanger |
|---|---|---|
| `scripts/sjekk-uniquename.sh` | **før** deploy | Skrivefeil i `uniqueName` som ville opprettet en ny app-reg |
| `scripts/verifiser.sh` | **etter** deploy, og senere | Ekte drift: sammenligner faktisk tilstand i Entra mot en committet baseline |

```bash
./scripts/verifiser.sh fhi-lmr-mintjeneste-api-test > baseline/api-test.json   # etter deploy
./scripts/verifiser.sh fhi-lmr-mintjeneste-api-test baseline/api-test.json     # senere
```

`verifiser.sh` normaliserer og sorterer alt før sammenligning — Graph returnerer lister i
tilfeldig rekkefølge, så uten sortering ville diffen slått ut på ingenting.

## ⚠️ Hva en re-deploy FAKTISK gjør — målt, ikke antatt

Dette er den mest overraskende delen, og den er verifisert ved å deploye mot ekte Entra,
endre ting utenfor malen, og deploye på nytt.

| Situasjon | Resultat |
|---|---|
| Deploy samme mal + samme parametre på nytt | **ARM hopper over ressursen.** Ingenting sendes til Graph. Drift blir IKKE rettet. |
| Deploy med endret parameterverdi | Ressursen sendes. **Deklarerte properties håndheves** — en `displayName` endret i portalen ble satt tilbake til malens verdi. |
| Property malen IKKE deklarerer (eller deklarerer tom) | **Blir stående.** `web: {}` i malen fjernet ikke en `web.redirectUris` som var lagt til utenfor. |
| App-registreringens `appId` gjennom alt dette | **Uendret.** Ingen destroy/create. |

**Konsekvensen, og den er viktig:**

> En re-deploy er **ikke** en måte å rette opp drift på. Er malen uendret, skjer det ingenting.
> Og selv når ressursen sendes, konvergerer den ikke mot malen — den legger malens verdier
> *oppå* det som står der.

Derfor er `scripts/verifiser.sh` ikke valgfritt. Det er den eneste drift-deteksjonen du har,
og opprydding etter en portal-endring må gjøres manuelt.

⚠️ Det betyr også at **du ikke kan fjerne noe ved å slette det fra malen.** Skal en
redirect-URI, en app-rolle eller en `requiredResourceAccess`-kant bort, må den fjernes
eksplisitt mot Graph.

## ⚠️ Gruppeoppretting holdes utenfor Bicep

Extensionen har ingen `Microsoft.Graph/administrativeUnits`, og rettighetene rundt AU-er er
asymmetriske:

| Operasjon | Endepunkt | Minste rolle |
|---|---|---|
| **Opprette ny** gruppe inne i AU-en | `POST /directory/administrativeUnits/{au}/members` | `Groups Administrator` **scoped til AU-en** |
| **Flytte eksisterende** gruppe inn i AU-en | `POST /directory/administrativeUnits/{au}/members/$ref` | **`Privileged Role Administrator`** |

LMR sine rollegrupper **må** ligge i `AU-Legemiddelregisteret`
(`a563113b-80b4-4187-a938-a8d97992c3ce`) av to grunner: utvikleren har bare `Groups
Administrator` innenfor AU-en, og applikasjonens AU-scopede rolle dekker bare grupper som
ligger der.

Lar du Bicep opprette gruppa, havner den i katalogroten — og å flytte den inn krever en
NHN-bestilling **per gruppe**.

**Derfor:** kjør `scripts/opprett-gruppe-i-au.sh` først, og la Bicep referere gruppa med
`existing`. Scriptet treffer AU-endepunktet direkte og krever **ingen ny rettighet**.

Dette er en begrensning i extensionen, ikke i Bicep som sådan — AU-medlemskap finnes rett og
slett ikke som ressurstype ennå.

**Omfanget er lite:** de 20 gruppene finnes allerede, `opprett_grupper = false` var normalen fra
app nummer to i et miljø, og de to m2m-variantene rører aldri en gruppe. Nye grupper trengs kun
ved ny rolle eller nytt miljø.

## Øvrige begrensninger

| Begrensning | Konsekvens for LMR |
|---|---|
| `passwordCredentials` støttes ikke | Ingen — LMR bruker sertifikat overalt |
| Role-assignable groups (`isAssignableToRole`) kan ikke deployes | Ingen — rollegruppene våre er vanlige sikkerhetsgrupper |
| Deployment stacks støttes ikke | Bruk vanlig deployment |
| Verbose output støttes ikke | Ressursene vises i portalens deployment-detaljer kun i debug-modus |
| Maks 20 `members`/`owners` deklarert inline på en gruppe | Ingen — medlemmer administreres av appen via Graph, ikke i malen |

## Rettigheter du trenger

- `az login` mot FHI-tenanten (`54475f80-1baa-4ea9-9185-c0de5cc603fe`)
- **PIM `Application Developer` aktivert** — den utløper, og gir
  `Authorization_RequestDenied` på `POST /applications` når den har gjort det
- Contributor på resource-gruppa du deployer i
- `Groups Administrator` scoped til AU-en, hvis du skal opprette grupper

⚠️ `az` faller jevnlig tilbake til feil tenant. Symptomet er
`Resource '<appId>' does not exist`, som leser som om app-registreringen er slettet. Alle tre
skriptene sperrer for dette, men sjekk selv med `az account show --query tenantId`.

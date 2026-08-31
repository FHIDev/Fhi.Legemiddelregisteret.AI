# Feller

Ting som har kostet en feilsøkingsrunde i LMR sin EntraId-migrering. Les når noe ikke gir
mening.

Felles for de fleste: **de bygger og starter helt fint. Feilen viser seg først i drift.**

## Tilgang og consent

### Token gyldig, men `roles` er tomt → 403, ikke 401

Skill de to fra hverandre — de peker på helt ulike ting:

| Status | Betydning |
|---|---|
| **401** | Tokenet ble ikke akseptert. Feil issuer, audience eller signatur. |
| **403** | Tokenet er greit, men bærer ingen rettighet. **Consent mangler**, eller app-rollen er ikke tildelt. |

### Rolletildeling uten gruppemedlemskap gir ingen `roles`

App-rollen kan være korrekt definert, tildelt gruppa, og consent gitt — men står ingen brukere
i gruppa, kommer det ingen `roles`-claims. Brukeren får «mangler tilgang», og alt ser riktig ut
i portalen.

### Gruppe-eierskap gir POST, ikke DELETE

Eierskap lar appen **legge til** medlemmer via Graph, men ikke **fjerne** dem — eierskap er en
delegert mekanisme, ikke app-only. Symptomet: å gi tilgang virker, å fjerne den gir 403.
Løsning: `Groups Administrator` scoped til AU-en. Se [NHN-OG-ADMIN.md](./NHN-OG-ADMIN.md).

### `DuplicateValue` når en app-rolle skal hete som et scope

EntraID tillater ikke at en app-rolles `value` kolliderer med et delegert scope på **samme**
app-registrering. Traff Kontroll→InternStatistikk: `Fhi.Lmr.InternStatistikk.All` fantes
allerede som delegert scope, så en application-app-rolle med samme verdi ble avvist i alle fire
miljøer.

**Et annet rollenavn hjelper ikke:** `TokenValidation` sin fallback-policy legger alltid på
`ScopeRequirement(DefaultScope)`, og verdien må være nøyaktig `DefaultScope` — den godtas fra
`scope`, `scp` eller `roles`, men den må matche.

Løsningen der ble en **delegert** kant i stedet for m2m.

## Graph-oppførsel

### ⚠️ `GET /groups/{id}/owners` viser ikke service-principal-eiere

Den svarer `[]` selv når eieren er satt. Samme gjelder `/owners/$ref` og
`az ad group owner list`.

Bevist: kallet ga tom liste, mens `POST .../owners/$ref` med samme referanse svarte
*"One or more added object references already exist"*.

**Bruk `GET /v1.0/groups/{id}?$expand=owners`.** Verifiseringsmetoden var feil, ikke oppsettet
— og feilkonklusjonen var at eierskapet manglet.

### Graph-replikering: SP kan ikke opprettes umiddelbart

Etter at en app-registrering er opprettet, tar det tid før den er replikert nok til at en
service principal kan lages for den — erfaringsmessig opptil ~30 sekunder.

Bicep orkestrerer selv gjennom ressursavhengigheter og traff det ikke i testkjøringen, men
slår det til, er symptomet `Request_ResourceNotFound` rett etter opprettelse. Kjør på nytt.

### Rollegrupper må OPPRETTES i AU-en, ikke flyttes dit

| Operasjon | Minste rolle |
|---|---|
| Opprette ny gruppe inne i AU-en | `Groups Administrator` scoped til AU-en |
| Flytte eksisterende gruppe inn | **`Privileged Role Administrator`** |

Lager du gruppa utenfor først, trenger du en NHN-bestilling for å rette det opp. Bruk
`bicep/scripts/opprett-gruppe-i-au.sh`.

### ⚠️ `az rest` kan ikke tildele katalogroller

Azure CLI-appen ber aldri om scopet `RoleManagement.ReadWrite.Directory`, så `POST` mot
`roleManagement/directory/roleAssignments` svarer **403 uansett hvilken rolle du har**. En 403
derfra sier altså ingenting om dine egne rettigheter. Bruk portalen eller `Connect-MgGraph`.

### ⚠️ `az` faller tilbake til feil tenant

Symptomet er `Resource '<appId>' does not exist`, som leser som om app-registreringen er
slettet. Den er ikke det — du står i en annen tenant.

```bash
az account show --query tenantId   # skal være 54475f80-1baa-4ea9-9185-c0de5cc603fe
az account set --subscription FHI-LMR-Dev
```

Alle tre skriptene i `bicep/scripts/` sperrer for dette.

### `az` siler bort norske tegn

Ikke-ASCII forsvinner stille fra `az`-output. Skal du verifisere norsk tekst (beskrivelser,
visningsnavn), gjør det utenom `az`.

## Bicep-spesifikt

### `BCP079` — `identifierUris` kan ikke referere egen `appId`

`appId` tildeles først ved opprettelse, og en ressurs kan ikke referere sin egen deklarasjon.
Løses med to pass over samme `uniqueName` — se [BICEP-OPPSETT.md](./BICEP-OPPSETT.md).

### `BCP138` — for-uttrykk kan ikke stå inne i `concat()`

Hoist hver løkke til en `var` først.

### `BCP036` på `owners.relationships`

I extension **1.0.0** er `relationships` en `string[]` med object-IDer — ikke `[{ id: '...' }]`,
som Learn-referansen viser. Learn beskriver en nyere type enn den som er publisert. Målt med
`bicep build`.

### `CannotDeleteOrUpdateEnabledEntitlement` ved endring av app-roller

En app-rolle eller et delegert scope kan ikke fjernes eller erstattes mens det er aktivt. Sett
`isEnabled: false` og deploy, fjern så i en andre deploy. Å endre `value` på en rolle som
beholder samme `id` er greit.

### En re-deploy retter ikke drift

Målt: er malen og parametrene uendret, hopper ARM over ressursen og sender ingenting. Og selv
når ressursen sendes, fjernes ikke properties du har tatt ut av malen — `web: {}` ryddet ikke
bort en `redirectUris` lagt til i portalen.

Deklarerte verdier håndheves når ressursen faktisk sendes (en `displayName` endret i portalen
ble satt tilbake), men **malen konvergerer ikke** — den legger seg oppå. Bruk
`scripts/verifiser.sh`, og rydd manuelt.

### `uniqueName` frigjøres ikke ved sletting

Sletting soft-sletter: objektet ligger 30 dager i papirkurven og holder fortsatt på navnet.
Tøm den før du gjenbruker navnet:

```bash
az rest --method DELETE --uri "https://graph.microsoft.com/v1.0/directory/deletedItems/<objectId>"
```

### Brownfield: `uniqueName` settes på **objectId**, ikke `appId`

```bash
az rest --method PATCH --url "https://graph.microsoft.com/v1.0/applications/<OBJECT-ID>" ...
```

De to forveksles lett, og feilen gir en lite hjelpsom 404.

## Konfigurasjon i backend

### v2-tokens: `Audience` er ren GUID, uten `api://`

Med `requestedAccessTokenVersion: 2` er `aud` i access-tokenet appId-GUID-en. Setter du
`ApiTokenValidation:Audience = api://<appId>`, feiler valideringen med
«The audience claim is invalid».

De eldre v1-app-regene (Administreringslager, Meldingsformidler) sameksisterer fint — token-
versjon settes per ressurs.

### Klient-scope er alltid `.default`

`Apis:<Klient>:Scope = api://<callee-appId>/.default`. Client credentials ber ikke om enkelt-
scopes; `.default` betyr «alt appen har fått consent for».

### EntraID støtter ikke DPoP

**Utelat `RequireDPoP` helt** — den defaulter til `false`. Ikke sett `RequireDPoP: false`
eksplisitt for EntraID-tjenester. DPoP gjelder kun HelseId.

### `RoleClaimType = "roles"` må settes eksplisitt på OIDC-handleren

Uten den leter ASP.NET Core etter `ClaimTypes.Role`
(`schemas.microsoft.com/ws/2008/06/identity/claims/role`), og `IsInRole` treffer **aldri** —
brukeren kastes ut selv med korrekt rolle i tokenet.

`TokenValidation`-pakken gjør dette selv for API-siden. For OIDC-handleren i en webapp må du
sette det.

Alt bygger og starter fint; feilen viser seg først ved innlogging.

### Redirect-URI-er må inneholde post-logout-stien

EntraID krever at `post_logout_redirect_uri` er registrert **blant `redirectUris`**. Er den
ikke det, feiler utloggingen — ikke innloggingen, så det oppdages sent.

Ta med både `/signin-oidc` og signout-stien.

### Pseudo-roller skal ikke bli app-roller

Kontrolls `ingen` betyr «hvilken som helst innlogget bruker». Den finnes ikke i databasen og
skal **ikke** opprettes som app-rolle. Et `[Authorize(Roles = "ingen")]` gir 403 til alle,
fordi ingen har en rolle som ikke finnes.

## Verifisering

### En 200 uten token er ikke et bevis

Sjekk **alltid** at callee svarer **401 uten token** før du tolker en 200 som bevis på at
autentiseringen virker. Flere ganger i denne migreringen har en tjeneste kjørt med
`UseAuth: false` (typisk `Development`), og da beviser en 200 ingenting.

### Kontrakter mellom repoer må prøves over HTTP

Enhetstester som konstruerer kommandoobjektet direkte går **utenom modellbindingen**. Et
`400` fra modellbindingen — som i praksis slettet hele revisjonssporet i Tilganger — ble ikke
fanget av 22 grønne tester.

### Ekte browser-innlogging er reell verifisering, ikke en formalitet

Tre av feilene i Rak.Web ble ikke fanget av bygg, endepunkt-sjekker eller curl. DPoP-feilen lå
bak alt som kunne testes uten pålogging, og PAR-testen var grønn hele veien.

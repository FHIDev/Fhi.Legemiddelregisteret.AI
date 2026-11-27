# Det du ikke kan gjøre selv — NHN og admin-roller

FHI-tenanten administreres av NHN. Noen steg i et EntraId-oppsett er admin-gated, og de er
ikke tilgjengelige på bestilling over natta. Planlegg dem tidlig — de har blokkert
verifisering i denne migreringen mer enn én gang.

## Oversikt: hva du kan og ikke kan

| Handling | Kan du selv? | Kreves |
|---|---|---|
| Opprette app-registrering + SP | ⚠️ kun Ludvig | PIM `Application Developer` — se «PIM: `Application Developer`» under |
| Sette `owners` på egne app-regs | ✅ | app-eier |
| **Application permission** (`appRoleAssignedTo`) — m2m-consent | ✅ | eier av ressurs-app-regen, eller `Application Administrator` på den (prod: via PIM) |
| **Delegert scope** (`oauth2PermissionGrants`) — brukerinnlogging | ❌ | Cloud Application Administrator / Application Administrator |
| Opprette gruppe **inne i** fagområdets AU | ✅ | `Groups Administrator` scoped til AU-en |
| **Flytte** eksisterende gruppe inn i en AU | ❌ | **Privileged Role Administrator** |
| Opprette en ny AU | ❌ | Privileged Role Administrator |
| Gi appen rett til å **fjerne** gruppemedlemmer | ❌ | Privileged Role Administrator (tildeler rollen) |

## Administrative enheter — én for prod og én for øvrige miljøer, per fagområde

LMR og Grossiststatistikken er separate fagområder i FHI med hver sin fagansvarlige. Fram til
september 2026 lå Grossiststatistikkens rollegrupper i LMRs AU, fordi det var den eneste som
fantes. US **120849** skilte dem: ny AU, og de fire gruppene flyttet dit av NHN.

Deretter ble hvert fagområde delt i én AU for prod og én for øvrige miljøer (Grossiststatistikken
US 123533, LMR november 2026). Grunnen: `Groups Administrator` gjelder alle grupper i AU-en, så så
lenge alle miljøene delte AU kunne en Dev- eller Test-applikasjon endre hvem som har tilgang i
prod. Prod-AU-en er den opprinnelige, med nytt navn; gruppene ble flyttet, ikke gjenskapt.

| AU | Object ID | Grupper | `Groups Administrator` scoped til AU-en |
|---|---|---|---|
| `AU-Legemiddelregisteret-Prod` | `a563113b-80b4-4187-a938-a8d97992c3ce` | Prod: 5 × `A-FHI-App-Lmr-Prod-<Rolle>` + sertifikathemmelighetsgruppa | `Fhi.Lmr.Kontroll.Client.Machine - Prod` + personer, se «Eierskap og tilgang» |
| `AU-Legemiddelregisteret-Test` | `7aa36d85-8358-42f1-96fb-d511f49b40f2` | Dev/Test/QA: 15 rollegrupper + Test-sertifikathemmelighetsgruppa | `Fhi.Lmr.Kontroll.Client.Machine` Dev + Test + QA + Ludvig (målbilde: alle utviklerne) |
| `AU-Grossiststatistikken-Prod` | `94d49e82-a17c-458f-93b1-5bab0c2fcfb2` | `…-Prod-Admin`, `…-Prod-Bruker` | `Fhi.Grossiststatistikken.Client.Machine - Prod` + personer, se «Eierskap og tilgang» |
| `AU-Grossiststatistikken-Test` | `60f3749d-721f-4b0c-8793-90949662ffb9` | Sandbox/Test × Admin/Bruker | `Fhi.Grossiststatistikken.Client.Machine` Sandbox + Test + Ludvig (målbilde: alle utviklerne) |

En AU har ikke «eier». Det som gir noen rett til å legge til og fjerne medlemmer i gruppene er
`Groups Administrator` scoped til AU-en — samme mekanisme for en bruker som for en applikasjon.
`User Administrator` er ikke i bruk: AU-ene inneholder kun grupper, ingen brukere, så rollen
ville ikke gitt noe.

Nye grupper opprettes i riktig AU med `bicep/scripts/opprett-gruppe-i-au.sh`. Scriptet utleder
AU-en av miljøet i gruppenavnet, og nekter å gjette for andre navn (oppgi da AU som tredje
argument). En gruppe i feil AU kan bare flyttes med en NHN-bestilling.

### Eierskap og tilgang: fagperson eier prod, utvikler låner via PIM

ADO-feature **120885** («Teknisk: Overføring av EntraID-eierskap til fagansvarlige») og US
**121935**. Pilot bestått 17.–18. november 2026. **LMR er satt opp av NHN 26. november 2026** og
verifiseres med en første ekte aktivering. Grossiststatistikken bestilles når LMR er verifisert.

#### Prinsippet

En utvikler skal **ikke** kunne gi seg selv tilgang til Prod. Det holder ikke å nekte utvikleren
`Groups Administrator`: **eieren av en app-registrering kan tildele en bruker direkte til en
app-rolle** («Users and groups» på enterprise-appen), og `roles`-claimet beregnes fra alle
tildelinger, ikke bare gruppene. Eieren kan også laste opp nytt sertifikat på `Client.Machine` og
hente tokens som appen. Permanent eierskap i Prod gir altså samme makt som `Groups Administrator`.

#### Målbildet

**Dev / Test / QA / Sandbox — ingen PIM.** Utviklerne på teamet er faste eiere av app-registreringene
og har `Groups Administrator` på test-AU-ene.

**Prod:**

| | LMR | Grossiststatistikken |
|---|---|---|
| Fast eier av prod-app-registreringene og SP-ene | Kari (+ `mi-lmr-sertifikatfornyelse-prod` på `Client.*`) | Kristine |
| Fast `Groups Administrator` på prod-AU-en | Kari + Kontroll `Client.Machine - Prod` | Kristine + Grossist `Client.Machine - Prod` |
| Utviklernes tilgang | PIM-gruppen `P-AU-Legemiddelregisteret-Prod-GroupsAdministrator` | ikke bestilt ennå |
| Godkjenner | `P-AU-Legemiddelregisteret-Prod-GroupsAdministrator-Approver`, eier Kari, medlemmer Kari + Siv | godkjennergruppe, eier Kristine, to faste medlemmer |

**PIM-gruppen** (én per fagområde, role-assignable, ingen faste medlemmer, utviklerne er
*eligible*) har permanent det en utvikler trenger i prod:

- `Groups Administrator` avgrenset til prod-AU-en
- `Application Administrator` avgrenset til **hver** prod-app-registrering **og** hver SP
- *Key Vault Secrets Officer* på prod-hvelvet for sertifikathemmeligheter

Aktivering krever begrunnelse, MFA og godkjenning, og varer maks 8 timer. **Eierskap kan ikke
lånes via PIM** — det er ikke en rolle — så `Application Administrator` på objektet er det som
erstatter det. Piloten bekreftet at app- og SP-avgrenset `Application Administrator` virker når
mottakeren er en gruppe.

**Godkjennergruppen** har faste medlemmer (minst to — en PIM-søknad når bare godkjennerne som fantes
da den ble sendt), ligger **utenfor** AU-ene (ellers kunne alle med `Groups Administrator` der,
også en utvikler med aktivert PIM, endre hvem som godkjenner), og har ingen utviklere som eier
eller medlem. Fagpersonen bytter vikar selv. Fagpersonen eier **ikke** PIM-gruppen: en eier kan
endre PIM-innstillingene og gi tilgang uten godkjenning.

#### Konsekvenser i det daglige

- **Alt prod-arbeid i Entra** — ny kant (`legg-til-kant.sh` mot prod), redirect-URI, rollegruppe,
  manuell sertifikatfornyelse: aktiver PIM-gruppen, vent på godkjenning, gjør jobben.
- ⚠️ **Hvelvet slår inn flere minutter etter Entra-rollene.** Får du `ForbiddenByRbac` rett etter
  godkjenning, vent ~10 minutter og kjør `az login` på nytt.
- **Ny prod-app-registrering:** utvikleren med `Application Developer` oppretter den og blir eier
  (i dag bare Ludvig, se «PIM: `Application Developer`» under),
  legger til fagpersonen som eier, bestiller hos NHN at PIM-gruppen får `Application Administrator`
  på den nye app-registreringen **og** SP-en, og fjerner seg selv som eier. For LMR `Client.*`: legg
  den også inn i `Fhi.Lmr.SertifikatFornyelse`. **Hver ny prod-app-registrering blir en liten
  NHN-bestilling.** Lista over app-registreringer per fagområde står i `entraid/baseline/`.
  `entraid/scripts/sjekk-prod-eiere.sh` melder prod-app-registreringer med andre eiere enn
  fagpersonen.
- **Historikk** over aktiveringer og godkjenninger: Entra beholder den i 30 dager, NHN i ett år.
  Fag ber NHN om uttrekket for PIM-gruppen ved behov.

⚠️ Det som ikke lukkes av dette: den som kan deploye Kontroll til Prod eller lese
Prod-sertifikatet i Octopus, kan handle *som* Kontroll, som selv har `Groups Administrator`.
Den døren lukkes med tilgangsstyring og godkjenning i Octopus, ikke i Entra.

#### Hva en ny rolle krever

1. Ny app-rolle på `.Api` og `.Client.Web` i hvert miljø — `Application Administrator` på app-regen (manuelt mot Graph, ikke redeploy).
2. Ny sikkerhetsgruppe **inne i** AU-en — `Groups Administrator` på AU-en (`bicep/scripts/opprett-gruppe-i-au.sh`).
3. Tildeling gruppe → app-rolle på begge service principalene — `Application Administrator`.
4. Kode og config: autorisasjonsattributt, rollekonstant, `Tilgangsstyring:GruppeIder` i alle appsettings, SPA.
5. Gjenta 1–3 per miljø. I prod med aktivert PIM-gruppe.

## Admin consent

### ⚠️ Skillet som koster tid

**Application permissions kan du gi selv.** `appRoleAssignedTo` er en tildeling på
ressurs-APIets service principal, og eier av den app-registreringen (eller den som har
`Application Administrator` på den) kan opprette den. Hos oss gjøres det med
`entraid/scripts/legg-til-kant.sh` i Fhi.Lmr.AI, også rett etter at en ny klient er opprettet
(`giAdminConsent` i `m2m-client-machine.bicep` står derfor som `false`).

**Delegerte scopes kan du ikke.** `oauth2PermissionGrants` — altså «Client.Web får kalle Api på
vegne av innlogget bruker» — krever Cloud Application Administrator eller Application
Administrator.

Konsekvensen i praksis: **rene m2m-kanter er selvbetjent, brukerinnlogging er ikke det.**

### Symptomet når consent mangler

Tokenet blir **utstedt og er gyldig**, men `roles`-claimet er **tomt**. Callee svarer da
**403**, ikke 401.

401 = tokenet ble ikke akseptert (feil issuer/audience/signatur).
403 = tokenet er greit, men bærer ingen rettighet. **Det er consent som mangler.**

### Slik gis det

Consent gis **per app-registrering** — ett klikk godkjenner alle tillatelsene appen har
erklært. Har du 122 tillatelser fordelt på 31 app-regs, er det 31 handlinger, ikke 122.

Portalen: **Entra ID → App registrations → All applications** → søk opp på **Program-ID**
(navn kan være like) → **API permissions** → **Grant admin consent for FHI**. Alle rader skal
få grønn hake i **Status**.

CLI: `az ad app permission admin-consent --id <clientId>`

### Bestillingsmal

> **Til:** identitetsadministrator hos NHN
> **Fra:** Folkehelseinstituttet, Legemiddelregisteret (LMR)
> **Tenant:** FHI — `54475f80-1baa-4ea9-9185-c0de5cc603fe`
>
> Vi ber om **admin consent** for følgende app-registreringer. Uten dette svarer tjenestene
> **403 Forbidden** på interne kall.
>
> | # | App-registrering | Program-ID | Tillatelser |
> |---|---|---|---|
> | 1 | `Fhi.Lmr.<Tjeneste>.Client.Machine - Test` | `<appId>` | `Fhi.Lmr.<Callee>.All` (Application) |
>
> Consent gis per app-registrering: Entra ID → App registrations → søk på Program-ID →
> API permissions → **Grant admin consent for FHI**.
>
> Dette gir ingen tilgang til persondata. Tillatelsene gjelder kun at våre egne tjenester
> får kalle hverandre.

## `Groups Administrator` scoped til AU

### ⚠️ Gruppe-eierskap gir POST, ikke DELETE

Det er lett å tro at det holder å gjøre appens service principal til **eier** av gruppa. Det
gjør det ikke: eierskap lar appen **legge til** medlemmer, men ikke **fjerne** dem. Eierskap er
en **delegert** mekanisme, ikke app-only.

Symptomet: å gi en tilgang virker, å fjerne den svarer `403`.

Løsningen er den innebygde rollen **`Groups Administrator`**, **scoped til den administrative
enheten** — ikke `GroupMember.ReadWrite.All`, som ville gitt tenant-vid tilgang til alle
grupper.

| | |
|---|---|
| Rolle | `Groups Administrator` — `fdd7a751-b60b-444a-984c-02652fe8fa1c` |
| Scope | LMR: `/administrativeUnits/a563113b-80b4-4187-a938-a8d97992c3ce` (`AU-Legemiddelregisteret-Prod`) for Prod, `/administrativeUnits/7aa36d85-8358-42f1-96fb-d511f49b40f2` (`AU-Legemiddelregisteret-Test`) for Dev/Test/QA. Grossiststatistikken har sine egne, se over |
| Tenant | `54475f80-1baa-4ea9-9185-c0de5cc603fe` |

AU-scopet begrenser rettigheten til gruppene som ligger i den aktuelle AU-en — våre egne
applikasjonsroller. Rollen gir ingen tilgang til brukere, andre grupper eller noe annet i
katalogen.

### ⚠️ Kan IKKE gjøres med `az rest`

Azure CLI-appen ber aldri om scopet `RoleManagement.ReadWrite.Directory`, så `POST` mot
`roleManagement/directory/roleAssignments` svarer **403 uansett hvilken rolle du har**. En 403
derfra sier altså ingenting om dine egne rettigheter.

Bruk portalen eller `Connect-MgGraph`:

```powershell
Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory"

$au    = "/administrativeUnits/<AU for miljøet>"   # se tabellen over — prod og øvrige miljøer har hver sin
$rolle = "fdd7a751-b60b-444a-984c-02652fe8fa1c"   # Groups Administrator

New-MgRoleManagementDirectoryRoleAssignment `
    -PrincipalId "<SP-object-id>" -RoleDefinitionId $rolle -DirectoryScopeId $au
```

Portalen: Entra ID → Roles & admins → Admin units → riktig AU (f.eks. `AU-Legemiddelregisteret-Test`) →
Roles and administrators → `Groups Administrator` → Add assignments.

**Den som utfører tildelingen trenger `Privileged Role Administrator`.** Det gjelder kun
utføreren — applikasjonene får ingen slik rolle.

### Bestillingsmal

> Tildel den innebygde Entra-rollen **`Groups Administrator`**, **scoped til den administrative
> enheten `<AU-navn>`**, til følgende service principals:
>
> | # | Service principal | Object ID | Application ID |
> |---|---|---|---|
> | 1 | `Fhi.Lmr.<Tjeneste>.Client.Machine - <Miljø>` | `<objectId>` | `<appId>` |
>
> | | |
> |---|---|
> | Rolle | `Groups Administrator` — `fdd7a751-b60b-444a-984c-02652fe8fa1c` |
> | Scope | `/administrativeUnits/<AU object ID>` |
>
> **Dette er ikke en tenant-wide tildeling.** AU-scopet begrenser rettigheten til gruppene i
> `<AU-navn>` — våre egne applikasjonsroller.

Verifiser etterpå:

```powershell
Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '<SP-object-id>'"
```

## ⚠️ Flytte en eksisterende gruppe inn i en AU

Krever **`Privileged Role Administrator`** — altså en NHN-bestilling. Det er gjort to ganger:
Grossiststatistikkens fire grupper ble flyttet til egen AU i september 2026 (US 120849), og ved
delingen i prod- og test-AU i november ble gruppene flyttet på nytt. Gruppene beholdt object-ID,
medlemmer, eiere og app-rolletildelinger; det eneste som måtte følge med var
`Groups Administrator`-tildelingene, siden de er scoped per AU. En bestilling må derfor liste
både gruppene (navn + object ID), mål-AU-en og hvilke `Groups Administrator`-tildelinger som skal
gis på nytt.

Å **opprette** en gruppe inne i AU-en krever derimot bare AU-scoped `Groups Administrator`,
som du har.

**Konklusjonen er praktisk:** opprett alltid rollegrupper direkte i AU-en med
`bicep/scripts/opprett-gruppe-i-au.sh`. Lager du gruppa utenfor først — for eksempel ved å la
Bicep gjøre det — trenger du en bestilling for å rette det opp.

## PIM: `Application Developer`

**Svært få får denne rollen.** I teamet er det i dag bare Ludvig som har den, så det er han som
oppretter nye app-registreringer, i alle miljøer. Resten av teamet kan endre eksisterende
app-registreringer (i Dev/Test/QA som eiere, i Prod via PIM-gruppen), men ikke opprette nye.
Den dagen Ludvig slutter, må noen andre i teamet få rollen. Det er ikke bestilt i dag.

Rollen som lar deg opprette app-registreringer er tidsbegrenset i PIM og **utløper midt i
arbeidet**. Symptomet er `Authorization_RequestDenied` på `POST /applications`.

Skjer det på første `POST /applications`, blir ingenting opprettet — reaktiver rollen og kjør på
nytt (`sjekk-uniquename.sh` sier da fortsatt OPPRETTER). Utløper den senere i deployen, kan noe
være opprettet: se «Når en deploy feiler halvveis» i `entraid/README.md`.

## Hva som ikke lar seg verifisere uten admin

Delegert scope krever admin consent for at et ekte **brukertoken** skal kunne utstedes. Uten
det kan du verifisere strukturen (app-regs, roller, scope, tildelinger) og hele m2m-kanten,
men ikke selve authorization-code-flowen.

Det er et kjent hull i en selvbetjent testrunde, og det skal sies eksplisitt — ikke skjules
bak en «alt ser riktig ut»-konklusjon.

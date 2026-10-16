# Det du ikke kan gjøre selv — NHN og admin-roller

FHI-tenanten administreres av NHN. Noen steg i et EntraId-oppsett er admin-gated, og de er
ikke tilgjengelige på bestilling over natta. Planlegg dem tidlig — de har blokkert
verifisering i denne migreringen mer enn én gang.

## Oversikt: hva du kan og ikke kan

| Handling | Kan du selv? | Kreves |
|---|---|---|
| Opprette app-registrering + SP | ✅ | PIM `Application Developer` |
| Sette `owners` på egne app-regs | ✅ | app-eier |
| **Application permission** (`appRoleAssignedTo`) — m2m-consent | ✅ | eier av ressurs-app-regen |
| **Delegert scope** (`oauth2PermissionGrants`) — brukerinnlogging | ❌ | Cloud Application Administrator / Application Administrator |
| Opprette gruppe **inne i** fagområdets AU | ✅ | `Groups Administrator` scoped til AU-en |
| **Flytte** eksisterende gruppe inn i en AU | ❌ | **Privileged Role Administrator** |
| Opprette en ny AU | ❌ | Privileged Role Administrator |
| Gi appen rett til å **fjerne** gruppemedlemmer | ❌ | Privileged Role Administrator (tildeler rollen) |

## To administrative enheter — LMR og Grossiststatistikken

LMR og Grossiststatistikken er separate fagområder i FHI med hver sin fagansvarlige. Fram til
september 2026 lå Grossiststatistikkens rollegrupper i LMRs AU, fordi det var den eneste som
fantes. US **120849** skilte dem: ny AU, og de fire gruppene flyttet dit av NHN.

| AU | Object ID | Grupper | `Groups Administrator` scoped til AU-en |
|---|---|---|---|
| `AU-Legemiddelregisteret` | `a563113b-80b4-4187-a938-a8d97992c3ce` | 20 × `A-FHI-App-Lmr-<Miljø>-<Rolle>` | Ludvig, `Fhi.Lmr.Kontroll.Client.Machine` ×4 |
| `AU-Grossiststatistikken` | `94d49e82-a17c-458f-93b1-5bab0c2fcfb2` | 6 × `A-FHI-App-Grossiststatistikken-<Miljø>-<Rolle>` (Sandbox/Test/Prod) | Ludvig, `Fhi.Grossiststatistikken.Client.Machine` Test + Sandbox (Prod bestilt 8. sep 2026) |

En AU har ikke «eier». Det som gir noen rett til å legge til og fjerne medlemmer i gruppene er
`Groups Administrator` scoped til AU-en — samme mekanisme for en bruker som for en applikasjon.
`User Administrator` er ikke i bruk: AU-ene inneholder kun grupper, ingen brukere, så rollen
ville ikke gitt noe.

Nye grupper opprettes i riktig AU med `bicep/scripts/opprett-gruppe-i-au.sh`, som tar AU som
valgfritt tredje argument (default LMR). Grossiststatistikkens Prod-grupper skal dit når
Prod-miljøet kommer — det krever ingen ny NHN-bestilling.

### TODO: overføring til fagansvarlig — målbildet

Ikke gjort, og bevisst ikke del av 120849. ADO-feature **120885** («Teknisk: Overføring av
EntraID-eierskap til fagansvarlige», Team A) beskriver overføringen; 120849 er første steg under den.

| AU | Til | Når |
|---|---|---|
| `AU-Legemiddelregisteret` | Kari | når EntraID-arbeidet for LMR er i prod og verifisert |
| `AU-Grossiststatistikken` | Kristine Olsen | når Grossiststatistikken er ferdig utviklet og i prod |

Inntil da har Ludvig `Groups Administrator` på begge.

**⚠️ Nåsituasjonen er en bus-faktor på én person, målt 4. sep 2026:** alle 75 app-registreringene
(`Fhi.Lmr.*` + `Fhi.Grossist*`) har **nøyaktig én eier**, og bare én bruker har `Groups
Administrator` på AU-ene. Når den kontoen deaktiveres, blir app-regene eierløse, og hver
endring — inkludert sertifikatfornyelsen for Prod i **2028** — blir en NHN-bestilling med
Cloud Application Administrator.

#### Prinsippet: fagperson eier, utvikler låner

En utvikler skal **ikke** kunne gi seg selv tilgang til Prod. Merk at det ikke holder å nekte
utvikleren `Groups Administrator`: **eieren av en app-registrering kan tildele en bruker direkte
til en app-rolle** («Users and groups» på enterprise-appen), og `roles`-claimet beregnes fra alle
tildelinger, ikke bare gruppene. Eieren kan også laste opp nytt sertifikat på `Client.Machine` og
hente tokens som appen. Permanent eierskap i Prod gir altså samme makt som `Groups Administrator`.

Målbildet er derfor:

| Hvem | Hva | Varighet |
|---|---|---|
| Fagperson (Kari / Kristine Olsen) | `Groups Administrator` scoped til sin AU **+ eier av fagområdets app-registreringer**, alle miljøer | permanent |
| Utviklere | **PIM-eligible** for `Groups Administrator` scoped til AU-en og `Cloud Application Administrator` scoped til hver app-registrering. **Godkjenner: fagperson.** | aktiveres per endring, utløper selv |

Ingen utvikler har noe permanent. Fagpersonen eier medlemskapet i det daglige, og godkjenner
når strukturen skal endres. Alt logges av PIM.

**Hvorfor ikke én AU for ikke-prod og én for prod:** en rolle finnes alltid i alle miljøer, og
endringen gjøres i alle miljøer i samme økt — én aktivering dekker jobben. Det utviklerne gjør i
Test til daglig (medlemskap) går gjennom Kontrolls søknadsflyt, som virker fordi Kontrolls egen
SP har rollen. Blir godkjenning på Test-arbeid plagsomt, er justeringen å gjøre Test-app-regene
eligible **uten** godkjenning — det er en policy per app-reg, ikke en ny AU.

**Hvorfor ikke NHN-bestilling per endring:** to bestillinger per endring (gi + fjern), den siste
glemmes (`User Administrator` på LMR-AU-en var et slikt tilfelle), ukers latens, og kontrollen
ligger hos NHN i stedet for hos fagpersonen. PIM er den innebygde varianten av «midlertidig
tildeling», med fagpersonen som godkjenner og automatisk fjerning.

#### Hva en ny rolle faktisk krever (så man ser hvorfor utviklerne trenger å låne)

1. Ny app-rolle på `.Api` og `.Client.Web` i hvert miljø — app-eier / Cloud Application Administrator på app-regen.
2. Ny sikkerhetsgruppe **inne i** AU-en — `Groups Administrator` scoped til AU-en (fagperson kan gjøre dette selv i portalen: Admin units → Groups → Add).
3. Tildeling gruppe → app-rolle på begge service principalene — app-eier / Cloud Application Administrator.
4. Kode og config: autorisasjonsattributt, rollekonstant, `Tilgangsstyring:GruppeIder` i alle appsettings, SPA — utvikler + deploy.
5. Gjenta 1–3 per miljø.

Fire av fem steg er utviklerarbeid. Uten PIM blir hvert av dem en NHN-bestilling.

#### Bestillingen ved overføring (mal)

Én bestilling per fagområde, som gjør **alt** samtidig:

1. `Groups Administrator` scoped til AU-en → fagperson (permanent).
2. Fjern Ludvigs `Groups Administrator` på samme AU.
3. Legg fagperson til som eier på fagområdets app-registreringer (gjøres av nåværende eier selv, før kontoen deaktiveres — krever ingen NHN-rolle).
4. PIM-eligible for utviklerne: `Groups Administrator` scoped til AU-en + `Cloud Application Administrator` scoped til hver app-registrering, med fagperson som godkjenner. Lista over app-regs genereres fra Graph (`az rest GET /applications?$filter=startswith(displayName,'Fhi.Lmr.')`).

Presedens: Application Developer er alt PIM-basert hos NHN. Det som må bekreftes er at de
tildeler eligible-rettigheter **scoped** til AU og til enkelt-app-regs, ikke tenant-vidt.
Fallback hvis NHN sier nei: bestilling per endring, men da med tildeling **og** fjerningsdato i
samme bestilling.

⚠️ Det som ikke lukkes av dette: den som kan deploye Kontroll til Prod eller lese
Prod-sertifikatet i Octopus, kan handle *som* Kontroll, som selv har `Groups Administrator`.
Den døren lukkes med tilgangsstyring og godkjenning i Octopus, ikke i Entra.

## Admin consent

### ⚠️ Skillet som koster tid

**Application permissions kan du gi selv.** `appRoleAssignedTo` er en tildeling på
ressurs-APIets service principal, og eier av den app-registreringen kan opprette den — det er
det `giAdminConsent`-parameteren i `m2m-client-machine.bicep` gjør.

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
| Scope | `/administrativeUnits/a563113b-80b4-4187-a938-a8d97992c3ce` (`AU-Legemiddelregisteret`) — Grossiststatistikken bruker sin egen AU, se over |
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

$au    = "/administrativeUnits/a563113b-80b4-4187-a938-a8d97992c3ce"
$rolle = "fdd7a751-b60b-444a-984c-02652fe8fa1c"   # Groups Administrator

New-MgRoleManagementDirectoryRoleAssignment `
    -PrincipalId "<SP-object-id>" -RoleDefinitionId $rolle -DirectoryScopeId $au
```

Portalen: Entra ID → Roles & admins → Admin units → `AU-Legemiddelregisteret` →
Roles and administrators → `Groups Administrator` → Add assignments.

**Den som utfører tildelingen trenger `Privileged Role Administrator`.** Det gjelder kun
utføreren — applikasjonene får ingen slik rolle.

### Bestillingsmal

> Tildel den innebygde Entra-rollen **`Groups Administrator`**, **scoped til den administrative
> enheten `AU-Legemiddelregisteret`**, til følgende service principals:
>
> | # | Service principal | Object ID | Application ID |
> |---|---|---|---|
> | 1 | `Fhi.Lmr.<Tjeneste>.Client.Machine - <Miljø>` | `<objectId>` | `<appId>` |
>
> | | |
> |---|---|
> | Rolle | `Groups Administrator` — `fdd7a751-b60b-444a-984c-02652fe8fa1c` |
> | Scope | `/administrativeUnits/a563113b-80b4-4187-a938-a8d97992c3ce` |
>
> **Dette er ikke en tenant-wide tildeling.** AU-scopet begrenser rettigheten til gruppene i
> `AU-Legemiddelregisteret` — våre egne applikasjonsroller.

Verifiser etterpå:

```powershell
Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '<SP-object-id>'"
```

## ⚠️ Flytte en eksisterende gruppe inn i en AU

Krever **`Privileged Role Administrator`** — altså en NHN-bestilling. Det er gjort én gang:
Grossiststatistikkens fire grupper ble flyttet til egen AU i september 2026 (US 120849).
Gruppene beholdt object-ID, medlemmer, eiere og app-rolletildelinger; det eneste som måtte
følge med var `Groups Administrator`-tildelingene, siden de er scoped per AU. Mal for en slik
bestilling: `Fhi.Lmr.EntraIdMigrering/docs/2026-09-04-bestilling-au-grossiststatistikken.md`.

Å **opprette** en gruppe inne i AU-en krever derimot bare AU-scoped `Groups Administrator`,
som du har.

**Konklusjonen er praktisk:** opprett alltid rollegrupper direkte i AU-en med
`bicep/scripts/opprett-gruppe-i-au.sh`. Lager du gruppa utenfor først — for eksempel ved å la
Bicep gjøre det — trenger du en bestilling for å rette det opp.

## PIM: `Application Developer`

Rollen som lar deg opprette app-registreringer er tidsbegrenset i PIM og **utløper midt i
arbeidet**. Symptomet er `Authorization_RequestDenied` på `POST /applications`.

Ingenting blir halvveis opprettet når det skjer — reaktiver rollen og kjør på nytt.

## Hva som ikke lar seg verifisere uten admin

Delegert scope krever admin consent for at et ekte **brukertoken** skal kunne utstedes. Uten
det kan du verifisere strukturen (app-regs, roller, scope, tildelinger) og hele m2m-kanten,
men ikke selve authorization-code-flowen.

Det er et kjent hull i en selvbetjent testrunde, og det skal sies eksplisitt — ikke skjules
bak en «alt ser riktig ut»-konklusjon.

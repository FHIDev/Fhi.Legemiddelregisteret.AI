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
| Opprette gruppe **inne i** AU-Legemiddelregisteret | ✅ | `Groups Administrator` scoped til AU-en |
| **Flytte** eksisterende gruppe inn i AU-en | ❌ | **Privileged Role Administrator** |
| Gi appen rett til å **fjerne** gruppemedlemmer | ❌ | Privileged Role Administrator (tildeler rollen) |

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
| Scope | `/administrativeUnits/a563113b-80b4-4187-a938-a8d97992c3ce` (`AU-Legemiddelregisteret`) |
| Tenant | `54475f80-1baa-4ea9-9185-c0de5cc603fe` |

AU-scopet begrenser rettigheten til gruppene som ligger i `AU-Legemiddelregisteret` — våre egne
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

Krever **`Privileged Role Administrator`** — altså en NHN-bestilling per gruppe.

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

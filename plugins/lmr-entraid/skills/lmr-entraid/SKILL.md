---
name: lmr-entraid
description: EntraId-ressurser for LMR-tjenester — hvordan .Api, .Client.Web og .Client.Machine settes opp og henger sammen, provisjonert med Bicep (Microsoft Graph-extensionen). Bruk ved opprettelse av nye app-registreringer, nye m2m-kanter mellom tjenester, oppsett av brukerinnlogging med roller og sikkerhetsgrupper, sertifikater og kid, admin consent og andre ting NHN må gjøre, og feilsøking av tomt roles-claim eller 403 fra et LMR-API.
---

# EntraId-ressurser for LMR

Hvordan LMR sine app-registreringer i EntraID ser ut, hvorfor de ser sånn ut, og hvordan du
lager nye. Provisjoneringen gjøres med **Bicep + Microsoft Graph-extensionen**.

Denne skillen dekker **tenant-siden** — selve app-registreringene. For hvordan applikasjonen
*bruker* dem (`Fhi.Lmr.Authentication`-pakkene, `ApiTokenValidation`, `OidcClients`, DPoP,
feilsøking av 401/403), se skillen `lmr` sin `LMR-AUTHENTICATION.md`.

## Referanser

| Fil | Når |
|---|---|
| [BICEP-OPPSETT.md](./references/BICEP-OPPSETT.md) | Hvordan du faktisk deployer. `uniqueName`, `owners`, brownfield, begrensninger, hva som erstatter `what-if`. **Les før første deploy.** |
| [SERTIFIKATER.md](./references/SERTIFIKATER.md) | Generere, laste opp, rotere sertifikat. `kid` vs. PEM. |
| [NHN-OG-ADMIN.md](./references/NHN-OG-ADMIN.md) | Alt du **ikke** kan gjøre selv: admin consent, Groups Administrator, PIM. Med bestillingsmaler. |
| [FELLER.md](./references/FELLER.md) | Ting som har kostet en feilsøkingsrunde. Les når noe ikke gir mening. |

## Kjørbare filer — og hvordan du får tak i dem

Pluginen inneholder ekte, kjørbare filer, ikke bare pseudokode. De ligger under
`${CLAUDE_PLUGIN_ROOT}/skills/lmr-entraid/`:

| | |
|---|---|
| `bicep/*.bicep` + `.bicepparam` | fire maler, én per variant |
| `bicep/moduler/` | delt modul |
| `bicep/scripts/` | `sjekk-uniquename.sh`, `verifiser.sh`, `opprett-gruppe-i-au.sh` |
| `cert-tooling/` | PowerShell for sertifikater |

**Skriptene kan kjøres direkte** — de tar argumenter og trenger ingen redigering:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/lmr-entraid/bicep/scripts/sjekk-uniquename.sh" fhi-lmr-mintjeneste-api-test
"${CLAUDE_PLUGIN_ROOT}/skills/lmr-entraid/bicep/scripts/verifiser.sh" fhi-lmr-mintjeneste-api-test
```

### ⚠️ Bicep-malene må kopieres UT før bruk

`.bicepparam` er konfigurasjon for én bestemt tjeneste — ekte app-IDer, sertifikat-base64,
stabile UUID-er. Den hører hjemme i et repo som versjoneres og reviewes.

**Rediger den aldri i plugin-katalogen.** Den er en cache som byttes ut ved
`/plugin update`, og alt du har fylt inn forsvinner.

Bruk **`/lmr-entraid:entraid-ny-tjeneste`**, som kopierer riktig variant ut til et repo du velger og
fyller inn det den kan. Eller kopier manuelt.

### Hvor den utfylte fila bor — `entraid/` i Fhi.Lmr.AI

Fasiten for **alle** app-registreringene til LMR og Grossiststatistikken ligger samlet i
toppnivåkatalogen `entraid/` i repoet Fhi.Lmr.AI — utenfor `plugins/`, så den distribueres ikke
som cache:

| | |
|---|---|
| `entraid/tjenester/<tjeneste>/` | utfylte maler og parameterfiler |
| `entraid/baseline/<uniqueName>.json` | tilstanden til hver app-registrering, fra `verifiser.sh` |

**Ikke** i tjenestens eget repo. En m2m-kant endrer kallerens `.Client.Machine`, mens app-rollen
tilhører callee — spredt på tjenesterepoene ville én kant blitt to PR-er, og drift-sjekken ville
ikke sett alle app-registreringene.

Alle eksisterende app-registreringer har `uniqueName` og en baseline (siden 25. november 2026),
også de som ble laget før Bicep.

### ⛔ Malene brukes bare til å OPPRETTE

En Bicep-mal beskriver hvordan app-registreringen *skal se ut*. Deployes den mot en som finnes
fra før, settes de deklarerte propertyene til malens verdi — uten `what-if` som viser det på
forhånd. Properties malen ikke deklarerer blir stående (målt), men deklarerte lister som kantene,
app-rollene og redirect-URI-ene er ikke målt med færre elementer enn i Entra; Graph erstatter
normalt hele lista, så anta at det som mangler kan forsvinne. Derfor:

| Hva | Hvordan |
|---|---|
| Ny app-registrering | Bicep, én gang. `sjekk-uniquename.sh` stopper (exit 2) hvis navnet finnes. |
| Ny m2m-kant på en eksisterende klient | `entraid/scripts/legg-til-kant.sh` i Fhi.Lmr.AI — det eneste skriptet for eksisterende, kan bare legge til |
| Sertifikatfornyelse | automatisk for LMR (`Fhi.Lmr.SertifikatFornyelse`), ellers additivt med `--append` — se [SERTIFIKATER.md](./references/SERTIFIKATER.md) |
| Annen endring på en eksisterende | manuelt mot Graph, med `verifiser.sh` før og etter — spør brukeren først |
| Fjerne noe | manuelt og bevisst, aldri via mal eller skript |

**Deploy aldri en mal mot en app-registrering som finnes**, heller ikke for å «rette opp» noe eller
fullføre en deploy som feilet halvveis (se `entraid/README.md`).
Parameterfila i `entraid/tjenester/` beskriver hvordan app-registreringen ble laget; baselinen er
fasiten for hvordan den ser ut nå.

⚠️ **Terraform-oppsettet (`Fhi.Lmr.Terraform`) er pensjonert.** Kjør det ikke. Modulene gjenskaper
app-registreringen med ny appId når en kant eller et sertifikat endres.


## Modellen: tre roller, aldri flere

En LMR-tjeneste har opptil tre app-registreringer per miljø. Hvilke den trenger følger av hva
tjenesten gjør — ikke av hva den heter.

### `.Api` — ressursen

Finnes hvis tjenesten **eksponerer** et API som noen andre kaller.

- **M2M:** én `appRole` med `allowedMemberTypes: ["Application"]` og verdi
  `Fhi.Lmr.<Tjeneste>.All`. Havner i **`roles`**-claimet i et client-credentials-token.
- **Brukerinnlogging:** ett delegert scope i `api.oauth2PermissionScopes`. Havner i
  **`scp`**-claimet i brukertokenet. Pluss `appRoles` med `allowedMemberTypes: ["User"]` for
  rollene.
- `requestedAccessTokenVersion: 2` ⇒ **`aud` er ren appId-GUID, uten `api://`-prefiks.**
- `identifierUris: ["api://<appId>"]` — det klienter peker på i scope-strengen.

Mapper til backend:

```
ApiTokenValidation:Authority     = https://login.microsoftonline.com/<tenant>/v2.0
ApiTokenValidation:Audience      = <appId>                    ← ren GUID
ApiTokenValidation:DefaultScope  = Fhi.Lmr.<Tjeneste>.All     ← app-rolleverdien
```

### `.Client.Machine` — utgående maskin-til-maskin

Finnes hvis tjenesten **kaller** andre LMR-API-er uten en innlogget bruker.

- Sertifikat i `keyCredentials` (client assertion / `private_key_jwt`).
- `requiredResourceAccess` med `type: "Role"` mot hver callee.
- `web: {}` — ingen redirect-URI-er, ingen brukerinnlogging.

```
OidcClients:EntraIdClient:ClientId   = <appId>
OidcClients:EntraIdClient:kid        = <sertifikat-thumbprint>   ← ikke hemmelig
OidcClients:EntraIdClient:PrivateKey = <PEM>                     ← secret, aldri i git
Apis:<Klient>:Scope                  = api://<callee-appId>/.default
```

### `.Client.Web` — brukerinnlogging

Finnes hvis mennesker logger inn.

- **Confidential**: `web.redirectUris` + sertifikat. Koden veksles på serveren.
- `appRoles` — **de samme rollene som på `.Api`**, med samme `appRoleId`.
- `requiredResourceAccess` med `type: "Scope"` mot eget `.Api`.

```
UserAuthentication:ClientId   = <appId>
UserAuthentication:PrivateKey = <PEM>                                  ← secret
UserAuthentication:Scopes     = ["api://<api-appId>/<scopeValue>", ...]
```

### Hvordan de tre henger sammen

```
                    bruker logger inn
                           │
                           ▼
                  ┌─────────────────┐   roles-claim fra gruppemedlemskap
                  │  .Client.Web    │◄──── A-FHI-App-Lmr-<Miljø>-<Rolle>
                  └────────┬────────┘         (sikkerhetsgruppe i AU)
                           │ delegert scope (scp)
                           ▼
                  ┌─────────────────┐
                  │  .Api           │  ← egen tjeneste
                  └─────────────────┘

   .Client.Machine ──── app-rolle (roles) ───► .Api  hos EN ANNEN tjeneste
   (client credentials, sertifikat)
```

**Rolletildeling = medlemskap i sikkerhetsgruppe.** Gruppa tildeles app-rollen på **både**
`.Api` og `.Client.Web`, slik at rollen kommer med i `roles`-claimet i begge tokens.

⚠️ **Rollene deles ikke ved å dele app-registrering.** `roles` beregnes fra tildelinger på den
app-registreringen tokenet er utstedt *for*. Det som gjør rollene felles på tvers av LMR-appene
er at de **samme gruppene** tildeles **samme `appRoleId`** i hver app. Derfor er
`appRoleId`-ene stabile UUID-er som aldri endres.

## Hvilken variant trenger jeg?

| Tjenesten... | Maler |
|---|---|
| eksponerer API, kaller ingen | `bicep/m2m-api.bicep` |
| kaller andre, eksponerer ingenting | `bicep/m2m-client-machine.bicep` |
| begge deler (vanligst) | begge to |
| har brukerinnlogging | `bicep/brukerinnlogging.bicep` |
| er en SPA (public client, PKCE) | `bicep/spa.bicep` — **ingen LMR-tjeneste bruker denne**, kun Grossiststatistikken |

De fleste LMR-tjenestene er ren m2m. Brukerinnlogging med denne malen gjelder Kontroll og
InternStatistikk. Reservasjonsregister har brukerinnlogging med et eget oppsett
(`Microsoft.Identity.Web`), laget før malene.

## Konvensjoner

| | |
|---|---|
| Tenant | `54475f80-1baa-4ea9-9185-c0de5cc603fe` |
| Display name | `Fhi.Lmr.<Tjeneste>.<Rolle> - <Miljø>` |
| `uniqueName` | `fhi-<navn>-<rolle>-<miljo>` fra visningsnavnet, små bokstaver — f.eks. `fhi-lmr-grunndata-api-test`, `fhi-grossiststatistikken-client-web-prod`. **Immutable.** |
| App-rolleverdi (m2m) | `Fhi.Lmr.<Tjeneste>.All` |
| Sikkerhetsgruppe | `A-FHI-App-Lmr-<Miljø>-<Rolle>`, i fagområdets AU for miljøet — LMR: `AU-Legemiddelregisteret-Prod` for Prod, `AU-Legemiddelregisteret-Test` for Dev/Test/QA. Grossiststatistikken tilsvarende (se NHN-OG-ADMIN.md) |
| Token-versjon | v2 på alt nytt |
| Sertifikat | Test 100 år, **Prod 2 år** |

### Miljøregelen — den er ikke kosmetisk

- **M2M: kun `Test` og `Prod`.** AzureDev og QA deler Test-app-registreringen. En klient i Dev
  eller QA kaller derfor callee sin **Test**-app-registrering.
- **Brukerinnlogging: egen app-registrering per miljø** (`Dev`, `Test`, `QA`, `Prod`) — for alle
  tre app-registreringene, også `.Client.Machine`.

Grunnen er `roles`-claimet: det beregnes fra tildelinger på app-regens service principal, og én
app-reg har én SP. Deler to miljøer app-registrering, gir medlemskap i `...-Dev-Godkjenn` også
rollen `godkjenn` i Prod — mens administrasjonsflaten ser isolert ut, fordi hvert miljø
redigerer sine egne grupper.

### Rettigheter før du skriver i Entra

| Du skal | Du trenger |
|---|---|
| **Opprette** en ny app-registrering (Bicep, alle miljøer) | PIM-rollen **`Application Developer`**, aktivert. Den utløper etter noen timer; symptomet er `Authorization_RequestDenied` på `POST /applications` |
| Endre en eksisterende app-registrering i Dev/Test/QA (kant, rolletildeling, redirect-URI, sertifikat) | Ingen PIM — utviklerne er faste eiere |
| Endre **noe som helst i Prod** — også `legg-til-kant.sh` mot `…-prod`, rollegrupper og sertifikatfornyelse | Aktivert **PIM-gruppe** for fagområdet (LMR: `P-AU-Legemiddelregisteret-Prod-GroupsAdministrator`). Krever begrunnelse og godkjenning fra fagpersonen, og varer maks 8 timer |
| Opprette en ny app-registrering **i Prod** | Begge: `Application Developer` for å opprette, deretter NHN-bestilling slik at PIM-gruppen får `Application Administrator` på den nye app-registreringen og SP-en |

Aktiver **før** du starter, ikke når noe feiler. Vent på godkjenningen før du skriver noe i Prod.
Hvelvet med sertifikathemmeligheter slår inn flere minutter etter Entra-rollene. Detaljer, og hva
som gjelder for Grossiststatistikken: [NHN-OG-ADMIN.md](./references/NHN-OG-ADMIN.md).

## Rekkefølgen når du setter opp en ny tjeneste

0. **`/lmr-entraid:entraid-ny-tjeneste <tjeneste> <variant>`** — kopierer malene til
   `entraid/tjenester/<tjeneste>/` i Fhi.Lmr.AI og stilaserer parameterfila.
   Har tjenesten app-registreringer fra før (sjekk `entraid/baseline/`), skal de **ikke**
   deployes på nytt. En ny kant gis med `entraid/scripts/legg-til-kant.sh`.
1. Generér sertifikat (`cert-tooling/`) — kun for klient-app-regene. Rene ressurser trenger det ikke.
2. Generér stabile UUID-er for app-roller og scopes. **Én gang. Endres aldri.**
3. Fyll `.bicepparam`.
4. `bicep/scripts/sjekk-uniquename.sh` — må gi exit 0 (ingen av navnene finnes). Stopper den, **ikke deploy**.
5. `az deployment group create ...`
6. Baseline for hver ny app-registrering i `entraid/baseline/` (kommando i `entraid/README.md`).
7. M2M-kanter fra en ny `.Client.Machine`: `entraid/scripts/legg-til-kant.sh` per callee. Malen
   gir ikke rolletildelingene selv (`giAdminConsent = false`).
8. Legg IDene fra `outputs` inn i appsettings.
9. PEM inn i secret-mekanismen for miljøet. **Aldri i git.** For LMR: legg tjenesten inn i
   `Fhi.Lmr.SertifikatFornyelse`, så sertifikatet fornyes automatisk.
10. Delegerte scopes (brukerinnlogging) krever admin consent fra NHN — se
    [NHN-OG-ADMIN.md](./references/NHN-OG-ADMIN.md).
11. Ved brukerinnlogging: legg medlemmer i rollegruppene. **Uten medlemskap kommer det ingen
    `roles`-claims, og brukeren får «mangler tilgang» selv med korrekt consent.**
    En app som bare **leser** rollene fra tokenet, trenger **ingen** rettigheter på gruppene.
    Bare en app som selv skal **administrere** medlemskap (i LMR: Kontroll) skal være eier av
    gruppene (gir legge til) og ha `Groups Administrator` på AU-en (gir fjerne). Gi aldri en vanlig
    webapp slike rettigheter — de gjelder de felles gruppene, altså tilgangene til alle LMR-appene.
12. **Kun Prod — overlever eierskapet til fagpersonen.** I Prod skal ingen utvikler stå igjen som
    fast eier: eieren kan tildele brukere direkte til app-roller og laste opp sertifikater, altså gi
    seg selv tilgang uten godkjenning.
    1. Fagpersonen står i `eiere` fra steg 3 (LMR: Kari, Grossiststatistikken: Kristine), ved siden
       av deg. Du ble uansett eier da du opprettet app-registreringen med `Application Developer`.
    2. Bestill hos NHN at PIM-gruppen får `Application Administrator` på den nye app-registreringen
       **og** SP-en. Uten den kommer ingen utviklere til appen igjen etter neste punkt.
    3. Når NHN har bekreftet: fjern deg selv som eier av app-registreringen og SP-en, skriv ny
       baseline, og kjør `entraid/scripts/sjekk-prod-eiere.sh` — den skal ikke melde appen.

## Det Bicep ikke gjør

**Sikkerhetsgrupper opprettes ikke av Bicep.** Extensionen har ingen
`Microsoft.Graph/administrativeUnits`, og gruppene må ligge i fagområdets AU.
Bruk `bicep/scripts/opprett-gruppe-i-au.sh` (utleder AU-en av miljøet i gruppenavnet, eller
tar den som tredje argument). Malene refererer gruppene med **object ID** (`gruppeObjektId`), fordi
de eksisterende rollegruppene ikke har `uniqueName`. De felles LMR-rollegruppene
(`A-FHI-App-Lmr-<Miljø>-<Rolle>`) finnes for alle fire miljøer — der trengs bare object ID-en.

### Ny app med NYE rollegrupper

Eieren av en rollegruppe kan legge til medlemmer, og dermed gi tilgang til appen. Eier skal derfor
være **appen som administrerer medlemskapet** (i LMR: Kontrolls `.Client.Machine`), aldri den nye
appen selv når den bare leser rollene fra tokenet (se punkt 11 over). Administrerer den nye appen
medlemskapet selv, er det dens `.Client.Machine`, og da finnes eieren først etter deploy.

1. Deploy med `gruppeObjektId: ''` på rollene som får nye grupper — malen hopper over
   tildelingen for dem.
2. Lag gruppene med `bicep/scripts/opprett-gruppe-i-au.sh <navn> <SP-objectId til gruppeforvalteren>`.
3. Tildel hver gruppe app-rollen på **både** `.Api` og `.Client.Web` — manuelt, ikke ved å deploye
   malen på nytt:
   ```bash
   az rest --method POST      --uri "https://graph.microsoft.com/v1.0/servicePrincipals/<sp-object-id>/appRoleAssignedTo"      --headers "Content-Type=application/json"      --body '{"principalId":"<gruppe-id>","resourceId":"<sp-object-id>","appRoleId":"<appRoleId>"}'
   ```
   (én gang med `apiSpObjectId`, én gang med Client.Web sin SP)
4. Ny baseline for begge app-registreringene.

Full forklaring i [BICEP-OPPSETT.md](./references/BICEP-OPPSETT.md).

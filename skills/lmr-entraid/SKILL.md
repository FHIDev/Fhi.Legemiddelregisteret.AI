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

Bruk **`/lmr:entraid-ny-tjeneste`**, som kopierer riktig variant ut til et repo du velger og
fyller inn det den kan. Eller kopier manuelt.

### Hvor den utfylte fila bor

**Slik er det i dag:** malene kopieres ut, og den utfylte fila legges i et repo teamet
kontrollerer — typisk `infra/entraid/` i tjenestens eget repo. Det finnes **ikke** noe felles
infra-repo for EntraId.

Det er et bevisst mellomsteg, ikke en anbefaling for all framtid. Skal oppsettet samles ett
sted — sammen med kall-grafen og ID-registeret — bør det opprettes et eget repo i DevOps. Ta
den beslutningen når det er flere enn en håndfull tjenester på Bicep.


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

19 av 22 LMR-repoer er ren m2m. Brukerinnlogging gjelder Kontroll og InternStatistikk.

## Konvensjoner

| | |
|---|---|
| Tenant | `54475f80-1baa-4ea9-9185-c0de5cc603fe` |
| Display name | `Fhi.Lmr.<Tjeneste>.<Rolle> - <Miljø>` |
| `uniqueName` | `fhi-lmr-<tjeneste>-<rolle>-<miljo>`, små bokstaver. **Immutable.** |
| App-rolleverdi (m2m) | `Fhi.Lmr.<Tjeneste>.All` |
| Sikkerhetsgruppe | `A-FHI-App-Lmr-<Miljø>-<Rolle>`, i AU `AU-Legemiddelregisteret` |
| Token-versjon | v2 på alt nytt |
| Sertifikat | Test 100 år, **Prod 2 år** |

### Miljøregelen — den er ikke kosmetisk

- **M2M: kun `Test` og `Prod`.** AzureDev og QA deler Test-app-registreringen.
- **Brukerinnlogging: egen app-registrering per miljø** (`Dev`, `Test`, `QA`, `Prod`).

Grunnen er `roles`-claimet: det beregnes fra tildelinger på app-regens service principal, og én
app-reg har én SP. Deler to miljøer app-registrering, gir medlemskap i `...-Dev-Godkjenn` også
rollen `godkjenn` i Prod — mens administrasjonsflaten ser isolert ut, fordi hvert miljø
redigerer sine egne grupper.

## Rekkefølgen når du setter opp en ny tjeneste

0. **`/lmr:entraid-ny-tjeneste <tjeneste> <variant>`** — kopierer malene ut og stilaserer parameterfila.
1. Generér sertifikat (`cert-tooling/`) — kun for klient-app-regene. Rene ressurser trenger det ikke.
2. Generér stabile UUID-er for app-roller og scopes. **Én gang. Endres aldri.**
3. Fyll `.bicepparam`.
4. `bicep/scripts/sjekk-uniquename.sh` — bekreft OPPRETTER vs. OPPDATERER.
5. `az deployment group create ...`
6. `bicep/scripts/verifiser.sh <uniqueName> > baseline.json`
7. Legg IDene fra `outputs` inn i appsettings.
8. PEM inn i secret-mekanismen for miljøet. **Aldri i git.**
9. Admin consent — se [NHN-OG-ADMIN.md](./references/NHN-OG-ADMIN.md). Application permissions
   kan du gi selv; delegerte scopes må bestilles.
10. Ved brukerinnlogging: legg medlemmer i rollegruppene. **Uten medlemskap kommer det ingen
    `roles`-claims, og brukeren får «mangler tilgang» selv med korrekt consent.**

## Det Bicep ikke gjør

**Sikkerhetsgrupper opprettes ikke av Bicep.** Extensionen har ingen
`Microsoft.Graph/administrativeUnits`, og gruppene må ligge i `AU-Legemiddelregisteret`.
Bruk `bicep/scripts/opprett-gruppe-i-au.sh`; malene refererer gruppene med `existing`.

Full forklaring i [BICEP-OPPSETT.md](./references/BICEP-OPPSETT.md).

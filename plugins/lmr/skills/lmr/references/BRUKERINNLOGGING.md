# Brukerinnlogging (OIDC) i LMR-tjenestene

Hvordan en LMR-webapp logger inn mennesker, og fellene som har kostet en feilsøkingsrunde hver.
Pakkene `Fhi.Lmr.Authentication.*` dekker **ikke** brukerinnlogging: den bygges med Microsofts
`OpenIdConnect`-handler + `Duende.AccessTokenManagement.OpenIdConnect`. De gamle `Fhi.HelseId.Web`,
`Fhi.HelseId.Blazor` og `Fhi.AuthControllers` er faset ut og skal ikke tas inn igjen.

For tokenvalidering i API-et og m2m-kall, se [LMR-AUTHENTICATION.md](./LMR-AUTHENTICATION.md).
For app-registreringene i EntraID, se skillen `lmr-entraid`.

## Innhold

- Referanseimplementasjoner
- Konfigurasjon: `UserAuthentication`
- Feller for alle (1–9)
- Kun EntraID (10–12)
- Kun HelseID (13–16)
- Blazor Server (17–18)
- Testing

## Referanseimplementasjoner

Kopier fra den som ligner mest, og les fellene under før du gjør det.

| App | IDP | Frontend | Hvor |
|---|---|---|---|
| Kontroll.Web | EntraID | BFF + Angular-SPA | `Fhi.Lmr.Kontroll.Web/Authentication/` |
| InternStatistikk.Web | EntraID | Blazor Server | `Fhi.Lmr.InternStatistikk.Web/Authentication/` + `Program.cs` |
| Rak.Web | HelseID | MVC + Angular-SPA | `Fhi.Lmr.Rak.Web/Authentication/` + `Controllers/{Account,User}Controller.cs` |
| Krl.Admin | HelseID | Blazor Server | `Fhi.Lmr.Krl.Admin/Authentication/` |

## Konfigurasjon: `UserAuthentication`

LMR har tre config-seksjoner for autentisering. Brukerinnlogging heter **`UserAuthentication`**
(IDP-nøytralt):

| Seksjon | Brukes til |
|---|---|
| `ApiTokenValidation` | innkommende token i et API |
| `OidcClients` + `Apis` | m2m-kall (client credentials) |
| **`UserAuthentication`** | brukerinnlogging |

Felter: `UseAuth`, `Authority`, `ClientId`, **`PrivateKey`** (ikke `ClientSecret` — det er en privat
nøkkel), **`UseDPoP`** (kun HelseID), `Scopes[]` (eksplisitt, ingen skjulte), `RedirectPages`,
`DataProtectionKeysPath`.

Miljøvariabelnavnet følger seksjonsnavnet: `UserAuthentication__PrivateKey`. Et gammelt navn som
`HelseIdWebKonfigurasjon__ClientSecret` blir **ignorert, ikke feilende** — innloggingen brekker
først når appen kjører.

## Feller for alle

### 1. Auth-cookien blir for stor — bruk ticket store fra start

`SaveTokens = true` legger `id_token`, `access_token` og `refresh_token` i cookien (og for HelseID
med DPoP også hele den private DPoP-nøkkelen). Målt på Rak.Web: ~13 KB etter kryptering, fordelt på
fire cookies. Kestrel svarer **400** fra ~20 KB, og IIS/http.sys har 16 KB per header.

**Symptomet er lumsk: hele nettstedet slutter å svare**, også sider som ikke krever innlogging.
Chrome viser `ERR_HTTP2_PROTOCOL_ERROR`. Det går over når cookiene slettes.

Løsning: server-side ticket store (`CookieAuthenticationOptions.SessionStore`, se `TicketStore.cs`).
Cookien blir ~160 byte, og nøkkelmaterialet forlater aldri serveren. In-memory lagring betyr at
alle logges ut ved omstart eller app pool-recycle; den er skrevet mot `IDistributedCache`, så Redis
eller SQL er bare en annen registrering.

### 2. ⚠️ Ticket store-cachen skal ikke ha størrelsesgrense

```csharp
services.AddDistributedMemoryCache(options => options.SizeLimit = null);
```

Med standardinnstillingene har cachen en størrelsesgrense. I Kontroll Prod (bug 123473) ble
størrelsestelleren negativ, og `MemoryCache` tolket det som at grensen var nådd: nye billetter ble
forkastet **uten feilmelding**. Cookien pekte da på en billett som ikke fantes, og innloggingen gikk
i løkke til appen ble startet på nytt. Billettene utløper uansett med cookien, så grensen gir ingen
beskyttelse. Kontroll har en test som vokter innstillingen (`TicketStoreCacheTests`).

### 3. Global `FallbackPolicy` dekker også statiske filer

En global `FallbackPolicy` (krev innlogging) er **ikke** en drop-in for gamle
`UseHelseIdProtectedPaths`. `AuthorizationMiddleware` bruker den på alle forespørsler, også filer i
`wwwroot`. Utloggingen sendte brukeren til `/Loggedout.html`, som selv ble utfordret → SSO logget
brukeren inn igjen → siden sa «Du er nå logget ut» til en innlogget bruker.

Løsning: server feil-, forbudt- og utloggingssidene **før** `UseAuthentication`:

```csharp
app.UseWhen(ctx => anonymeSider.Contains(ctx.Request.Path), a => a.UseStaticFiles());
```

### 4. Utlogging krever `id_token_hint` eksplisitt

`SignOutAsync(OidcScheme, new AuthenticationProperties { RedirectUri = … })` med ferske properties
sender **ingen** `id_token_hint`. Da vet ikke IDP-en hvilken sesjon som skal avsluttes, og viser
innloggingsskjermen. Sett den i `OnRedirectToIdentityProviderForSignOut`:

```csharp
var idToken = await ctx.HttpContext.GetTokenAsync(CookieScheme, "id_token");
ctx.ProtocolMessage.IdTokenHint = idToken;   // på protokollmeldingen, ikke i properties
```

Krever at `id_token` finnes i billetten (`SaveTokens = true`). Bekreft at sesjonen faktisk er
avsluttet: neste besøk skal be om innlogging, ikke slippe brukeren rett inn.

### 5. XHR skal få 401/403, ikke en redirect

En SPA som kaller API-et med XHR kan ikke følge en 302 til IDP-en (CORS), og en 302 til
`Forbidden.html` blir en 200 med HTML som SPA-en prøver å parse som JSON. Skill sidevisning fra XHR:

- `OnRedirectToIdentityProvider`: svar **401** når klienten ikke ber om `text/html`, og fjern
  `Set-Cookie` (ellers legger hvert kall igjen nonce-cookies og bruker opp en PAR).
- `OnRedirectToAccessDenied`: svar **403** på samme vilkår. Manglet i Kontroll og ga en kryptisk
  JSON-feil for brukere uten rolle (bug 120808).
- **`/Account/Login` må unntas** — den betyr «start innlogging». Bruk et flagg i
  `AuthenticationProperties`, ikke sti-matching.

`fetch()` sender `Accept: */*`, ikke `application/json` — test grenene slik klienten faktisk kaller.

### 6. 401/403 fra et API lenger ned skal ikke videreformidles rått

Får backend-en 401 fra et nedstrøms API, betyr det at **appen** ikke fikk autentisert seg, ikke
brukeren. Videreformidlet rått viser SPA-en «du er logget ut» til en innlogget bruker. Oversett til
**502** (se `NedstromsStatus` i Kontroll).

### 7. `Program.cs` som legger appsettings til på nytt, brekker user secrets

```csharp
builder.Configuration.AddJsonFile("appsettings.json")…AddEnvironmentVariables();   // ⚠️ fjern
```

`CreateBuilder` har allerede lagt inn alt i riktig rekkefølge. Legges filene inn på nytt, havner de
**etter** user secrets, og en nøkkel i user secrets kan aldri overstyre fila. Det er harmløst helt
til nøkkelen flyttes ut av fila.

### 8. Pakker som implementerer samme ruter må ut, ikke bare slutte å kalles

`Fhi.AuthControllers` sin `AccountController` ble oppdaget av MVC selv om koden ikke kalte pakken,
og ga `AmbiguousMatchException` (500) på `/Account/Ping`. Fjern pakkereferansen.

### 9. Ticket store og token-store er per prosess

Begge forutsetter **én** worker per app pool (ingen web garden). Med flere workere treffer
forespørslene ulike prosesser, og brukeren mister sesjonen tilfeldig.

## Kun EntraID

### 10. Discovery krever `ValidateEndpoints = false`

EntraIDs authority er `…/{tenant}/v2.0`, mens token-endepunktet er `…/{tenant}/oauth2/v2.0/token`
— utenfor authority-stien. Duendes discovery avviser det som standard. Feilen
(`Invalid base address for endpoint …`) kommer **ved code-vekslingen**, altså etter at brukeren
har logget inn. Registrer en egen `IDiscoveryCache` med
`new DiscoveryPolicy { ValidateEndpoints = false }` (se Kontroll `AuthExtensions.cs` og
InternStatistikk `Program.cs`).

### 11. `RoleClaimType = "roles"` må settes på OIDC-handleren

Uten den leter ASP.NET Core etter `ClaimTypes.Role`, og `IsInRole` treffer aldri — brukeren avvises
selv med riktig rolle. `TokenValidation` gjør det selv for API-et; for webappen må du sette det.
Pseudo-rollen `ingen` («hvilken som helst innlogget bruker») finnes ikke i EntraID og skal ikke bli
en app-rolle eller stå i `Roles =`.

### 12. Kall videre med brukerens token: ikke OBO, men `Scope` **og** `Resource`

En webapp som selv holder refresh-tokenet bruker det direkte — OBO er for et API som kaller videre,
og feiler her med `AADSTS500131`. Med Duende må `UserTokenApis`-oppføringen ha **både** `Scope` og
`Resource`: tokens lagres per resource, og uten `Resource` får du tilbake innloggingstokenet med
feil `aud`. (EntraID v2 ignorerer selv `resource`, men Duende trenger den som nøkkel.)

Bruker appen også m2m (`ConfigureHttpClients`), kolliderer de to `IClientAssertionService`-ene;
se `SammensattClientAssertionService` i Kontroll, som må registreres **etter** `ConfigureHttpClients()`.

## Kun HelseID

HelseID stiller egne krav som skjerpes i 2026–2027. Bygg inn alle nå.

### 13. Client assertion: PS256, `exp` ≤ 10 s, `typ`, PAR

`private_key_jwt` med `alg = PS256` (RS* avvises fra nov 2026 test / jan 2027 prod),
`typ = client-authentication+jwt`, `aud` = issuer, `exp` ≤ 10 sekunder, unik `jti`. Innlogging krever
**PAR**. Gjør assertion i én `IClientAssertionService` — Duende 4.2 bruker den selv for PAR,
code-veksling og fornyelse, så egne event-handlere for det er overflødige.

### 14. DPoP-nøkkelen må ha `alg`

Duende signerer DPoP-beviset med algoritmen som står **i JWK-en**. Mangler `alg`, kastes
`ArgumentNullException` ved **første token-forespørsel**, altså først etter en ekte innlogging.
Sett `alg = PS256` før `DPoPProofKey.Parse` (se `DPoPNokkel.cs`). Nøklene til Rak.Web og Krl.Admin manglet `alg`.

### 15. `CallbackPath = "/signin-callback"`, `SignedOutCallbackPath = "/signout-callback"`

Ikke Microsofts `/signin-oidc`. Begge må være registrert på HelseID-klienten. PAR validerer
redirect-URI-en før brukeren ser noe, så en feil viser seg som `Invalid redirect_uri` med en gang.

### 16. Scopes: `sub` i stedet for `pid_pseudonym`, men behold HPR

`pid_pseudonym`-scopet og -claimet avvikles; standard `sub` har samme verdi og krever ingen scope.
Ingen re-nøkling. **Fjern aldri et scope bare fordi appen selv ikke leser claimet** — Rak.Api avviser
alle brukere uten HPR-nummer, så `helseid://scopes/hpr/hpr_number` må med selv om Krl.Admin bare
leser `name`.

## Blazor Server

### 17. DPoP-nøkkelen må settes to steder (HelseID)

`AddOpenIdConnectAccessTokenManagement(o => o.DPoPJsonWebKey = …)` **og** på `UserToken` som skrives
til token-store-en i `OnTokenValidated`. Mangler den ett sted, går kallene ut som Bearer og avvises av
API-er med `RequireDPoP: true`. InternStatistikk (EntraID) har den ikke, og skal ikke ha den.

### 18. To latente feil i malen

- **Revalideringen gjør ingenting** hvis den bare sjekker `IsAuthenticated` på principalen circuiten
  allerede har — den er per definisjon autentisert. Sjekk at brukeren fortsatt har tokens i store-en
  (`HarToken`). Ikke bruk utløpt access token som kriterium; Duende fornyer det selv.
- **`ClearTokenAsync` må kalles ved utlogging**, før `SignOutAsync`, ellers ligger refresh-tokenet
  igjen i den statiske store-en resten av prosessens levetid.

Krl.Admin har begge rettet. Kontroller InternStatistikk.Web før du kopierer derfra.

## Testing

**Manuell ende-til-ende-test i browser er reell verifisering her, ikke en formalitet.** Flere av
fellene over (14, 3, 4, 5, 10) ble ikke fanget av bygg, enhetstester, curl eller tokentester —
bare av en ekte innlogging. Gå gjennom: innlogging, et kall som krever rolle, et kall uten rolle
(skal gi 403, ikke HTML), utlogging, og at neste besøk ber om innlogging igjen.

- **Sjekk at callee svarer 401 uten token før du tolker en 200 som bevis.** Et API kjørt lokalt med
  `UseAuth: false` svarer 200 på alt.
- Angular-bygg uten hash i filnavnet blir hentet fra nettleserens cache. Tving fersk henting etter
  `npm run build`.

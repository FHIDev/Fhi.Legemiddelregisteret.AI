# Fhi.Lmr.Authentication

Brukerveiledning for `Fhi.Lmr.Authentication.TokenValidation` og `Fhi.Lmr.Authentication.ClientCredentials`. Pakkene publiseres internt via Azure Artifacts (feed: `Legemiddelregisteret`) og brukes av LMR-tjenester for:

- **Validering av innkommende tokens** (`TokenValidation`) — når tjenesten din **mottar** kall beskyttet av HelseId, Entra ID eller Maskinporten.
- **Henting av tokens for utgående kall** (`ClientCredentials`) — når tjenesten din **kaller** et API beskyttet av en av de samme IDP-ene.

De to pakkene er uavhengige. En tjeneste kan bruke én eller begge.

## Utløserkriteria

Aktiver denne skillen når brukeren ber om å:
- Legge til autentisering/token-validering i en LMR-tjeneste
- Konsumere et API beskyttet av HelseId, Entra ID eller Maskinporten fra en LMR-tjeneste
- Bytte IDP eller endre scopes for eksisterende integrasjon
- Feilsøke 401/403-problemer mot LMR-APIer eller tokens fra disse IDP-ene
- Sette opp DPoP-beskyttelse
- Avgjøre om en tjeneste skal ha `Redis`/distribuert cache pga. DPoP
- Forstå hvorfor `UseAuth: false` feiler ved oppstart

## Pakke-referanser

```xml
<PackageReference Include="Fhi.Lmr.Authentication.TokenValidation" Version="10.3.0" />
<PackageReference Include="Fhi.Lmr.Authentication.ClientCredentials" Version="10.3.1" />
```

(Sjekk alltid siste versjon i Azure Artifacts-feeden før du setter inn versjoner.)

---

## Del 1: TokenValidation — validere innkommende tokens

### Konfigurasjon

`appsettings.json`:

```json
{
  "ApiTokenValidation": {
    "Authority": "https://helseid-sts.test.nhn.no/",
    "Audience": "fhi:min.api",
    "DefaultScope": "fhi:min.api/les",
    "Scopes": [
      "fhi:min.api/les",
      "fhi:min.api/skriv",
      "fhi:min.api/admin"
    ],
    "RequireDPoP": false,
    "UseAuth": true
  }
}
```

| Felt | Beskrivelse | Påkrevd | Default |
|---|---|---|---|
| `Authority` | URL til identity provider. IDP detekteres automatisk fra strengen (`helseid`, `windows`, `maskinporten`). | Ja | — |
| `Audience` | Forventet `aud`-claim i innkommende tokens. | Ja | — |
| `DefaultScope` | Scope som kreves på alle endepunkter som fallback-policy (brukes hvis endepunktet ikke har eksplisitt `RequireAuthorization`). | Nei | `null` |
| `Scopes` | Liste over scopes som registreres automatisk som authorization policies med samme navn. | Nei | `[]` |
| `RequireDPoP` | Krev DPoP-proof i tillegg til access token. **Kun HelseId støtter DPoP.** For **EntraID** (og Maskinporten) skal feltet **utelates helt** — det defaulter til `false`, og EntraID støtter ikke DPoP. Ikke sett `RequireDPoP: false` eksplisitt for EntraID; bare la det stå tomt. | Nei | `false` |
| `UseAuth` | Hvis `false`: hopp over all autentisering og autorisering. Se sperre under. | Nei | `true` |
| `AllowedNoAuthEnvironments` | Hvite-liste over miljøer der `UseAuth: false` er lovlig. | Nei | `["Development", "AzureDev", "Docker"]` |

### Registrering i `Program.cs`

```csharp
using Fhi.Lmr.Authentication.TokenValidation.ApiAuthentication;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddApiAuthenticationAndAuthorization(builder.Configuration, builder.Environment);

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.Run();
```

`AddApiAuthenticationAndAuthorization` gjør følgende automatisk:
- Velger Bearer- eller DPoP-oppsett basert på `RequireDPoP`.
- Detekterer IDP fra `Authority` og setter IDP-spesifikke `ValidTypes` (`at+jwt` for HelseId, `JWT` for Entra ID, ingen for Maskinporten).
- For Maskinporten: bruker `/.well-known/oauth-authorization-server` som discovery-endepunkt (ikke `openid-configuration`).
- Registrerer authorization-policies for hvert scope i `Scopes`-lista.

### Endepunktspesifikke scopes

```csharp
// Minimal API
app.MapGet("/data", () => Results.Ok("data"));                            // DefaultScope
app.MapPost("/admin", () => Results.Ok()).RequireAuthorization("fhi:min.api/admin");
app.MapGet("/public", () => Results.Ok()).AllowAnonymous();

// Controllers
[Authorize(Policy = "fhi:min.api/skriv")]
public IActionResult Create() => Ok();
```

### `UseAuth: false` — miljøsperre

Siden versjon 10.2 er `UseAuth: false` kun tillatt i miljøer listet i `AllowedNoAuthEnvironments`. I alle andre miljøer kaster oppstarten `InvalidOperationException`. **Dette er en bevisst sikkerhetssperre — ikke omgå den ved å legge til prod i lista.** Hensikten er at en operatør aldri skal kunne fjerne autentiseringen i et produksjonsmiljø ved en feil-deploy av konfig.

Hvis du trenger "ingen autentisering" lokalt eller i Docker: `Development`, `AzureDev` og `Docker` er allerede lovlige. Legg kun til andre hvis du har en konkret, godkjent grunn.

### Feilrespons

Pakken returnerer detaljerte feilmeldinger i `WWW-Authenticate`-headeren:

| Error | Betyr |
|---|---|
| `invalid_request` | Manglende `Authorization`-header |
| `invalid_token` | Token ugyldig, utløpt, feil signatur, feil audience/issuer, feil type |
| `insufficient_scope` | Token mangler påkrevd scope for endepunktet |

---

## Del 2: ClientCredentials — hente tokens for utgående kall

### Konfigurasjon

`appsettings.json`:

```json
{
  "OidcClients": {
    "HelseIdClient": {
      "Authority": "https://helseid-sts.test.nhn.no",
      "ClientId": "44388132-8028-47a6-ab02-4ab1e0579910",
      "PrivateKey": "{\"d\":\"...\",\"kty\":\"RSA\",\"n\":\"...\"}"
    },
    "EntraIdClient": {
      "Authority": "https://login.microsoftonline.com/{tenant-id}/v2.0",
      "ClientId": "...",
      "PrivateKey": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----",
      "kid": "EDAC21AAF1AAF5DEFFDF6EDE4D4F6029015C6086"
    },
    "MaskinportenClient": {
      "Authority": "https://test.maskinporten.no",
      "ClientId": "...",
      "PrivateKey": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----",
      "kid": "bced5a54-7426-4f4d-a6f5-2ab5e942929e"
    }
  },
  "Apis": {
    "ApiSomBeskyttesAvHelseId": {
      "BaseAddress": "https://helseid-api.example.com/",
      "HttpClientName": "HelseIdApiClient",
      "OidcClientName": "HelseIdClient",
      "Scope": "fhi:lmr.fhirmottak/barum"
    },
    "ApiSomBeskyttesAvEntraId": {
      "BaseAddress": "https://entra-api.example.com/",
      "HttpClientName": "EntraIdApiClient",
      "OidcClientName": "EntraIdClient",
      "Scope": "api://2b0726c5-ef39-4597-bbaf-dddb559c1143/.default"
    },
    "ApiSomBeskyttesAvMaskinporten": {
      "BaseAddress": "https://maskinporten-api.example.com/",
      "HttpClientName": "MaskinportenApiClient",
      "OidcClientName": "MaskinportenClient",
      "Scope": "fhi:lmr/fhirmottak.api",
      "resource": "fhi:lmr.fhirmottak"
    }
  }
}
```

#### OidcClients

| Felt | Beskrivelse | Påkrevd |
|---|---|---|
| `Authority` | URL til IDP (for discovery document) | Ja |
| `ClientId` | Klient-ID registrert hos IDP | Ja |
| `PrivateKey` | Privat nøkkel — **JWK-format** for HelseId, **PEM-format** for Entra ID og Maskinporten | Ja |
| `kid` | Key ID. Påkrevd for Entra ID (hex thumbprint for sertifikat, konverteres automatisk til base64url) og Maskinporten. Ikke relevant for HelseId. | Avhengig av IDP |

#### Apis

| Felt | Beskrivelse | Påkrevd |
|---|---|---|
| `BaseAddress` | Base-URL til API-et | Ja |
| `HttpClientName` | Navn på `HttpClient` som brukes med `IHttpClientFactory.CreateClient(navn)` | Ja |
| `OidcClientName` | Må være `HelseIdClient`, `EntraIdClient` eller `MaskinportenClient`. Valideres ved oppstart. | Ja |
| `Scope` | Scope som forespørres ved token-henting. For Entra ID: bruk `api://{api-client-id}/.default`. | Ja |
| `resource` | Maskinporten `resource`-parameter. Ignoreres for andre IDP-er. | Maskinporten |
| `UseDPoP` | **Dead config.** Leses ikke lenger — HelseId krever nå alltid DPoP, så det slås på automatisk for HelseId-klienter. Beholdt for bakoverkompatibilitet. | Nei |

### Registrering i `Program.cs`

```csharp
using Fhi.Lmr.Authentication.ClientCredentials.ClientCredentials;

var builder = WebApplication.CreateBuilder(args);

builder.Services.ConfigureHttpClients(builder.Configuration);

var app = builder.Build();
app.Run();
```

`ConfigureHttpClients` oppdager hvilke IDP-er som er konfigurert (`HelseIdClient`, `EntraIdClient`, `MaskinportenClient`) og registrerer kun de som er nevnt i `OidcClients`-seksjonen. Deretter bygges HTTP-klienter pr API i `Apis`-seksjonen, koblet til riktig IDP via `OidcClientName`.

### Bruk av registrert HttpClient

```csharp
public class MinService
{
    private readonly IHttpClientFactory _httpClientFactory;

    public MinService(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    public async Task<string> HentDataAsync()
    {
        var client = _httpClientFactory.CreateClient("HelseIdApiClient"); // HttpClientName fra appsettings
        var response = await client.GetAsync("api/data");
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadAsStringAsync();
    }
}
```

Tokens hentes og caches automatisk. DPoP-proof genereres automatisk for HelseId. Discovery-dokumenter caches for ytelse.

---

## Ting som er lett å bomme på

### 1. Feil nøkkelformat pr IDP

- **HelseId** krever **JWK** (JSON-objekt med `kty`, `n`, `d` osv.) lagt inn som streng.
- **Entra ID** og **Maskinporten** krever **PEM** (`-----BEGIN PRIVATE KEY-----\n...`). Linjeskift som `\n` fungerer — pakken håndterer konvertering.

Feil format gir en oppstartsfeil ved første token-henting. **Exception-meldingen er bevisst sanitert og inneholder ikke nøkkelinnholdet** — dette er en sikkerhetsgaranti, ikke en feil.

### 2. Entra ID `Scope` må være `.default`

Entra ID støtter **ikke** at man spesifiserer individuelle scopes i client assertion. Du må bruke `api://{api-client-id}/.default` — da får klienten alle scopes som er registrert på API-et i Entra-tenanten.

### 3. Entra ID `kid` = sertifikat-thumbprint i hex

I Entra-portalen oppgis sertifikatets thumbprint som 40-tegns hex-streng. Legg den inn som den er i `kid`-feltet. Pakken konverterer den til base64url (som Microsoft faktisk forventer) automatisk.

### 4. Maskinporten `resource`

Maskinporten krever `resource`-parameteren i token-requesten for de fleste API-er. Sett den i `Apis:*:resource`. Feltet er lowercase i koden (bevisst — det bindes via konfigurasjon).

### 5. DPoP og multi-instans → trenger distribuert cache

`TokenValidation`-pakken registrerer en in-memory `IDistributedCache` (`AddDistributedMemoryCache`) for `jti`-replay-beskyttelse i DPoP. Navnet er villedende — den er **per-prosess**, ikke delt mellom instanser.

Hvis tjenesten din kjører med flere instanser **og** bruker DPoP, bør du overstyre `IDistributedCache`-registreringen med en ekte delt backing-store (typisk Redis):

```csharp
builder.Services.AddApiAuthenticationAndAuthorization(builder.Configuration, builder.Environment);

// Overstyr den in-memory-cachen pakken registrerte. Siste registrering vinner.
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});
```

Uten dette kan en angriper som snapper opp et DPoP-proof potensielt replay-e det mot en **annen** instans av samme API innenfor proofets gyldighetsvindu (default 60 sek + clock skew), fordi den andre instansen ikke har sett `jti`-en før.

Single-instans-tjenester trenger ikke gjøre noe.

### 6. HelseId `UseDPoP`-flagget gjør ingenting

`Apis:*:UseDPoP` leses ikke av koden. DPoP slås alltid på for HelseId-klienter fordi HelseId krever det. Du trenger ikke sette det, men det skader ikke å la det stå `true` for dokumentasjons-formål.

### 7. `UseAuth: false` ved oppstart i prod → crash

Hvis du må skru av autentisering midlertidig (f.eks. for å feilsøke), gjør det bare i `Development`, `AzureDev` eller `Docker`-miljøet. I ethvert annet miljø kaster pakken `InvalidOperationException` ved oppstart. Det er en bevisst sikkerhetssperre. Ikke legg prod-miljøer til `AllowedNoAuthEnvironments`.

---

## Feilsøking

Feilsøking blir mye enklere hvis du har en mental modell av token-flyten. Les dette avsnittet først — det forklarer **hvor** ting kan gå galt. Deretter kommer konkrete symptomer nedenfor.

### Mental modell: to JWT-er, ikke én

Det er lett å blande sammen to helt forskjellige JWT-er i denne flyten:

1. **Client assertion** — JWT-en klienten signerer med sin privatnøkkel og sender til IDP-en for å bevise identitet. Denne lever bare noen sekunder og brukes kun til å hente et access token. Den validerer *deg* overfor IDP-en.
2. **Access token** — JWT-en IDP-en utsteder som svar, og som du sender med i `Authorization: Bearer`-headeren når du kaller det faktiske API-et. Denne validerer *deg* overfor ressursserveren.

Feilmeldinger handler nesten alltid om den andre — access tokenet — men årsaken ligger ofte i hvordan du ba IDP-en om det.

### Hvor kommer `aud`-claimet i access tokenet fra?

Dette er det folk oftest bommer på. **Du setter ikke audience direkte i client assertion for HelseId/Entra ID.** Client assertion-en har `aud` satt til IDP-ens egen issuer-URL (fra discovery-dokumentet), fordi den sier "denne JWT-en er ment for deg, IDP, som bevis på at jeg er klienten". Den sier ingenting om hvilket API du faktisk skal kalle.

Hvilket API du skal nå bestemmes av **`scope`-parameteren i token-requesten**. IDP-en bruker scopet til å utlede hvilken `audience` som havner i det utstedte access tokenet:

| IDP | Hvordan scope → audience |
|---|---|
| **HelseId** | Scopet (`fhi:lmr.fhirmottak/barum`) mapper til en audience registrert på scopet i HelseId-admin. Du kjenner navnet fordi det er det samme som API-eieren har registrert. |
| **Entra ID** | Scopet `api://{api-client-id}/.default` → `aud: "{api-client-id}"` (selve GUID-en, uten `api://`-prefiks). Vi bruker v2-endepunktet (`login.microsoftonline.com/{tenant}/v2.0`), og v2-tokens har klient-ID-en til target-API-et som audience. Entra støtter **ikke** individuelle scopes i client-credentials-flyt; `.default` er obligatorisk. |
| **Maskinporten** | **Unntaket.** Her legges `scope` og `resource` inn direkte i client assertion-JWT-en (se `CreateClientAssertionJwtMaskinporten`), ikke som egne token-request-parametere. Maskinporten bruker `resource`-feltet til å sette `aud` i det utstedte tokenet. **`Apis:*:resource` må derfor alltid være satt for Maskinporten-klienter** — uten den vil det utstedte tokenet ikke ha en audience som matcher API-et du prøver å kalle, og server-validering vil feile med `invalid_audience`. |

Konsekvensen: hvis du får `invalid audience` på server-siden, er det sjelden en feil i `Audience`-konfigurasjonen alene — det er ofte fordi **klienten ba om feil scope**, **Maskinporten-klienten mangler `resource`**, eller **serverens `Audience` bruker `api://`-prefiks mens v2-tokenet har ren GUID**.

### Hvor registreres scopes?

Scopes blir tilgjengelige via IDP-ens selvbetjeningsportal:

- **HelseId**: `https://selvbetjening.test.nhn.no` (test) — API-eier registrerer scopes på API-et sitt, og klient-eier må be om tilgang til akkurat disse scopene.
- **Entra ID**: Azure Portal → App registrations → API permissions. For client-credentials brukes "Application permissions" (ikke "Delegated"), og det krever admin consent.
- **Maskinporten**: `https://sjolvbetjening.test.samarbeid.digdir.no` (test) — API-eier registrerer scopes, klient-eier ber om tilgang.

Rød E2E-test (`ClientCredentials*Tests`) etter IDP-konfig-endring → start alltid med å verifisere i selvbetjeningsportalen.

---

### Feil som oppstår på klientsiden (ClientCredentials — før tokenet er hentet)

#### Oppstartsfeil: "Kunne ikke parse PrivateKey (JWK/PEM) for {klient}"

**Betyr:** Nøkkelstrengen i `OidcClients:{klient}:PrivateKey` er enten feil format eller korrupt.

**Sjekkliste:**
- HelseId skal ha **JWK** (`{"kty":"RSA","n":"...","d":"..."}` som streng).
- Entra ID og Maskinporten skal ha **PEM** (`-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----`).
- Linjeskift i JSON skal være `\n` (literal backslash-n).
- Exception-meldingen er **bevisst sanitert** og inneholder ikke nøkkelinnholdet. Dette er en sikkerhetsgaranti, ikke en bug. Sjekk kilden (Key Vault, config transform osv.) direkte.

#### Oppstartsfeil: "Invalid OidcClientName: {navn}. Valid names are: HelseIdClient, MaskinportenClient, EntraIdClient"

**Betyr:** En `Apis:*:OidcClientName`-verdi er skrevet feil. Validering skjer i setteren til `OidcHttpClientOption.OidcClientName` og krever eksakt match.

**Fix:** Sjekk stavemåten. Case-sensitiv.

#### Oppstartsfeil: "Error retrieving discovery document for authority {url}: {feil}"

**Betyr:** Pakken kunne ikke hente `/.well-known/openid-configuration` (eller `oauth-authorization-server` for Maskinporten) fra `Authority`-URL-en.

**Vanlige årsaker:**
- `Authority` peker på feil miljø (test vs prod) eller har trailing slash som gjør at URL-en ikke matcher.
- Nettverksproblem / brannmur blokkerer utgående trafikk til IDP-en.
- IDP-en har nede-vindu. Sjekk IDP-ens statusside.

#### 400 / 401 fra IDP ved token-henting (Duende logger typisk dette)

Dette er responsen fra IDP-ens token-endepunkt — altså før klienten får noe access token tilbake.

| Feil fra IDP | Betyr | Hvordan fikse |
|---|---|---|
| `invalid_client` | Klient-ID er ukjent, eller signaturen på client assertion kan ikke verifiseres. | Sjekk at `ClientId` matcher det som står i selvbetjeningsportalen. Sjekk at det er **offentlig** nøkkel som er registrert hos IDP-en, og at den korresponderer med **privat** nøkkel i appsettings. Hvis du nettopp har rotert nøkkel: vent på propagering, eller verifiser at riktig versjon er deployet. |
| `invalid_grant` | Client assertion-en er avvist av andre grunner (utløpt `exp`, klokke ute av synk, feil `aud`/`iss`). | Sjekk serverklokke. Sjekk at `ClientId` brukes både som `iss` og `sub` i client assertion (pakken gjør dette automatisk — hvis det feiler er noe annet galt). |
| `invalid_scope` | Scopet klienten ba om er ikke registrert på klienten i IDP-en, eller eksisterer ikke. | I selvbetjeningsportalen: sjekk at klient-registreringen har tilgang til scopet. For Entra ID: sjekk at admin consent er gitt. |
| `unauthorized_client` | Klienten har ikke lov til å bruke client-credentials grant type. | I selvbetjeningsportalen: sjekk at klienten er registrert som **maskin-klient** / service principal, ikke en bruker-klient. |

---

### Feil som oppstår på serversiden (TokenValidation — etter at tokenet er sendt til API-et)

Alle disse kommer som `401 Unauthorized` med `WWW-Authenticate: Bearer error="{kode}", error_description="{beskrivelse}"`.

#### `invalid_request` — "Authorization header missing or token not provided"

**Betyr:** Requesten kom inn uten `Authorization`-header i det hele tatt.

**Sjekkliste:**
- Glemte klienten å sette tokenet? Bruker du riktig navngitt `HttpClient` fra `IHttpClientFactory.CreateClient("navn")`? Navnet må matche `Apis:*:HttpClientName`.
- Proxy / API Gateway mellom klient og server som stripper headere?

#### `invalid_token` — "The issuer claim is invalid"

**Betyr:** `iss`-claimet i tokenet matcher ikke `Authority` i server-konfigurasjonen.

**Vanlige årsaker:**
- Server står på `https://helseid-sts.nhn.no/` (prod) mens klienten har fått et token fra `https://helseid-sts.test.nhn.no/` (test). Sjekk at begge sider peker på samme miljø.
- Trailing slash-forskjell kan bite — noen IDP-er setter `iss` med trailing slash, andre uten. `JwtBearer` bruker streng lik-sammenligning.
- For Maskinporten: prod vs test bruker forskjellige host-navn.

#### `invalid_token` — "The audience claim is invalid"

**Betyr:** `aud`-claimet i det mottatte tokenet matcher ikke `ApiTokenValidation:Audience` på server-siden.

**Dette er den mest misforståtte feilen.** Se "Hvor kommer `aud`-claimet i access tokenet fra?" over. Framgangsmåte:

1. **Dekod tokenet** på jwt.ms eller jwt.io og se hva `aud` faktisk er. Det er den enkleste måten å finne ut hvor mismatchen ligger.
2. **Sjekk klientens scope-request.** `aud` ble utledet fra scopet klienten ba om. Hvis scopet er feil, er audience feil.
3. **Sjekk serverens `Audience`-konfig.** For Entra (v2): `aud` i tokenet er klient-ID-en (GUID) til target-API-et, uten `api://`-prefiks. Serverens `Audience` må matche denne GUID-en.
4. **For HelseId:** sjekk at API-eier har registrert audience i selvbetjeningsportalen som nøyaktig den samme strengen som du har i `Audience` i appsettings i API-et og at `aud`-claim i utstedt token samsvarer med disse.
5. **For Maskinporten:** `aud` i tokenet utledes fra `resource`-feltet i client assertion-en. Sjekk at `Apis:*:resource` er satt i klientens appsettings, og at verdien matcher `Audience` i API-ets appsettings.

#### `invalid_token` — "The token has expired" / "The token is not yet valid"

**Betyr:** Clock skew mellom IDP og server/klient. Validering bruker default `ClockSkew: 5 sekunder`.

**Sjekkliste:**
- Serverens NTP. Container-miljøer er beryktet for klokkedrift.
- Hvis token caches lenge på klientsiden og sendes etter `exp`: Duende refresher som regel, men sjekk at cachen faktisk brukes riktig.

#### `invalid_token` — "The token signature is invalid"

**Betyr:** Signaturen på tokenet kan ikke verifiseres med noen av issuer signing keys fra discovery-dokumentet.

**Vanlige årsaker:**
- IDP har rotert signing keys og `ConfigurationManager` har cachet det gamle dokumentet. Restart API-et eller vent på refresh (default: 24 timer — men et SecurityTokenSignatureKeyNotFoundException trigger tidligere refresh).
- Klienten sender et token fra et helt annet miljø enn serveren validerer mot.

#### `invalid_token` — "The token type is invalid"

**Betyr:** `typ`-header-claimet i tokenet matcher ikke `ValidTypes`.

- **HelseId** krever `at+jwt` (satt automatisk når `Authority` inneholder `helseid`).
- **Entra ID** krever `JWT` (satt automatisk når `Authority` inneholder `windows`).
- **Maskinporten** setter ingen `typ`, så `ValidTypes` er ikke satt for Maskinporten.

Hvis denne feilen dukker opp med HelseId: sjekk at du ikke ved et uhell validerer et Entra-token (som har `typ: JWT`) mot HelseId-konfig.

#### `insufficient_scope`

**Betyr:** Tokenet er gyldig, men inneholder ikke det scopet som endepunktet krever.

**Sjekkliste:**
1. Dekod tokenet og se `scope`-claimet. Inneholder det scopet som endepunktet krever via `RequireAuthorization("...")` eller `[Authorize(Policy = "...")]`?
2. Hvis ikke: klienten ba om feil scope. Sjekk `Apis:*:Scope` i klientens appsettings.
3. Hvis scopet er riktig spesifisert men ikke er i tokenet: klienten er ikke registrert med tilgang til scopet i IDP-ens selvbetjeningsportal.
4. Husk også at scopet må være listet i `ApiTokenValidation:Scopes` på server-siden — ellers lages det ingen policy med det navnet.

---

### DPoP-spesifikke feil

#### `invalid_request` — "Missing DPoP proof value"

Klienten glemte å sende `DPoP`-headeren i tillegg til `Authorization: DPoP {token}`. I praksis skal Duende sin `ClientCredentialsHttpClient` med DPoP-oppsett aldri glemme dette. Hvis det likevel skjer:
- Sjekk at klienten faktisk kaller `options.DPoPJsonWebKey = ...` i token-oppsettet (pakken gjør dette automatisk for HelseId).
- Sjekk at klienten bruker `AddClientCredentialsHttpClient` og ikke en vanlig `HttpClient`.

#### `invalid_token` — "Invalid 'cnf' value"

**Betyr:** `cnf.jkt`-claimet (thumbprint av klientens DPoP-nøkkel) i access tokenet matcher ikke thumbprinten på nøkkelen som signerte DPoP-proofet.

Dette betyr nesten alltid at **klienten bruker forskjellige nøkler til å hente token og til å signere proof**. Pakken setter samme JWK (`DPoPJsonWebKey` med PS256) for begge sider av flyten, så dette bør ikke skje med mindre du har custom-kode som omgår det.

#### "Detected DPoP proof token replay"

**Betyr:** `jti`-en i proofet er allerede sett av denne serverinstansen.

**Vanlige årsaker:**
- Klienten bruker samme proof til flere requests (feil — hvert HTTP-kall skal ha eget proof).
- Retry-logikk på klientsiden re-sender samme proof etter timeout.
- Angriper prøver å replay-e et fanget proof. Dette er den normale, ønskede blokkeringen.

**Men se også punktet under:**

#### DPoP feiler inkonsistent på multi-instans-deployment

Se punkt 5 under "Ting som er lett å bomme på". Uten distribuert cache er replay-beskyttelsen per-instans, som betyr at samme `jti` kan godtas på én instans og avvises på en annen. Hvis du ser DPoP-problemer som varierer med lastbalansering: du må overstyre `IDistributedCache` med en ekte distribuert backing-store (Redis).

---

### Diagnostisk framgangsmåte når det ikke gir mening

1. **Dekod access tokenet.** Kopier det inn på jwt.ms (Entra) eller jwt.io. Se på `iss`, `aud`, `scope`, `exp`, `typ`. Halvparten av feilene blir åpenbare her.
2. **Sammenlign med server-konfigurasjonen.** `iss` skal være `ApiTokenValidation:Authority`. `aud` skal være `ApiTokenValidation:Audience`. Hvis ikke → du vet hvor feilen er.
3. **Sammenlign med klient-konfigurasjonen.** Hvis scopet klienten ba om ikke er i tokenet: IDP-en avviste scopet stille, eller klienten er ikke registrert med det.
4. **Sjekk IDP-ens selvbetjeningsportal** for siste ord om hvilke scopes, audiences og nøkler som er registrert på klienten.
5. **Kjør E2E-testene lokalt** (`ClientCredentials*Tests`) mot samme test-IDP for å isolere om det er pakken eller tjenestens oppsett som er problemet.
6. **Sjekk serverens log.** `JwtBearer` logger typisk grunnen til avvisning på Debug-nivå. Skru opp logging midlertidig på `Microsoft.AspNetCore.Authentication` hvis du trenger mer detalj.

---

## Referanser

- Kildekode + CLAUDE.md med interne detaljer: `Fhi.Legemiddelregisteret/Fhi.Lmr.Authentication`
- `oppdater-net-10`-skillen: dekker migrering fra `Fhi.ClientCredentialsKeypairs` / `Fhi.HelseId.Api` til disse pakkene

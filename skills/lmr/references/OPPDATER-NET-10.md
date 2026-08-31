# Oppdater til .NET 10

Oppgrader en .NET 8-tjeneste til .NET 10, bytt ut gamle autentiseringspakker med nye Fhi.Lmr.Authentication-pakker, og oppdater pipeline-filer til ny .NET 10-standard.

## Utløserkriteria

Aktiver denne skillen når brukeren ber om å:
- Oppgradere en tjeneste fra .NET 8 til .NET 10
- Bytte ut `Fhi.ClientCredentialsKeypairs` / `Fhi.HelseId.Api` med `Fhi.Lmr.Authentication.*`
- Migrere autentiseringskonfigurasjon fra gammel til ny pakkestruktur

---

## Steg 1: Directory.Build.Props – Oppdater TargetFramework

Finn filen `Directory.Build.Props` i rotkatalogen.

**Før:**
```xml
<TargetFramework>Net8.0</TargetFramework>
```

**Etter:**
```xml
<TargetFramework>net10.0</TargetFramework>
```

> Merk: Bruk `net10.0` (lowercase) – ikke `Net10.0`.

---

## Steg 2: .csproj – Pakkeendringer

### 2a. Fjern PropertyGroup-seksjoner med per-konfigurasjon TargetFramework

**Fjern** eventuelle `<PropertyGroup Condition="...">` som setter `<TargetFramework>net8.0</TargetFramework>` og `<DocumentationFile>` per konfigurasjon (Debug/Release). Erstatt med en enkel `<PropertyGroup>` uten betingelse.

**Før:**
```xml
<PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|AnyCPU'">
  <TargetFramework>net8.0</TargetFramework>
  <DocumentationFile>Fhi.Lmr.*.Api.xml</DocumentationFile>
  <NoWarn>1701;1702;1591</NoWarn>
</PropertyGroup>

<PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|AnyCPU'">
  <TargetFramework>net8.0</TargetFramework>
  <OutputPath></OutputPath>
  <DocumentationFile>Fhi.Lmr.*.Api.xml</DocumentationFile>
  <NoWarn>1701;1702;1591</NoWarn>
</PropertyGroup>
```

**Etter:**
```xml
<PropertyGroup>
  <GenerateDocumentationFile>true</GenerateDocumentationFile>
  <NoWarn>1701;1702;1591</NoWarn>
</PropertyGroup>
```

### 2b. Bytt ut autentiseringspakker

**Fjern:**
```xml
<PackageReference Include="Fhi.ClientCredentialsKeypairs" Version="3.2.0" />
<PackageReference Include="Fhi.HelseId.Api" Version="8.2.0" />
```

**Legg til** (sjekk alltid nyeste versjon i Azure Artifacts-feeden — disse er nyeste per nå):
```xml
<PackageReference Include="Fhi.Lmr.Authentication.TokenValidation" Version="10.3.0" />
<PackageReference Include="Fhi.Lmr.Authentication.ClientCredentials" Version="10.3.1" />
```

> **NU1605 — DependencyInjection.Abstractions:** De nye pakkene drar inn `Microsoft.Extensions.Logging.Abstractions 10.0.5`, som krever `Microsoft.Extensions.DependencyInjection.Abstractions >= 10.0.5`. Hvis et prosjekt (typisk API- eller testprosjekt) har en eksplisitt referanse pinnet til `10.0.1`, bump den til `10.0.5` — ellers feiler restore med NU1605 (downgrade).

### 2c. Bytt ut Swashbuckle med OpenAPI/Scalar – ALLTID ved .NET 10 + Fhi.Lmr.Authentication

> **VIKTIG:** Swashbuckle (alle versjoner) vil alltid feile med .NET 10 + `Fhi.Lmr.Authentication.*`-pakker fordi auth-pakkene drar inn `Microsoft.AspNetCore.OpenApi 10.0.0` → `Microsoft.OpenApi 2.0.0`, som fjernet `Microsoft.OpenApi.Models`-namespacet som Swashbuckle er avhengig av. Gjør alltid dette steget.

**Fjern alle Swashbuckle-pakker:**
```xml
<PackageReference Include="Swashbuckle.AspNetCore.Annotations" Version="6.5.0" />
<PackageReference Include="Swashbuckle.AspNetCore.Swagger" Version="6.5.0" />
<PackageReference Include="Swashbuckle.AspNetCore.SwaggerGen" Version="6.5.0" />
<PackageReference Include="Swashbuckle.AspNetCore.SwaggerUI" Version="6.5.0" />
```

**Legg til Scalar i prosjektet som inneholder Startup.cs / Program.cs:**
```xml
<PackageReference Include="Scalar.AspNetCore" Version="2.3.0" />
```

> `Microsoft.AspNetCore.OpenApi` trenger IKKE legges til eksplisitt – den kommer transitiv fra auth-pakkene.

**Legg til `InterceptorsNamespaces` i `<PropertyGroup>` i prosjektet med Startup.cs/Program.cs:**
```xml
<InterceptorsNamespaces>$(InterceptorsNamespaces);Microsoft.AspNetCore.OpenApi.Generated</InterceptorsNamespaces>
```
Dette er påkrevd av `Microsoft.AspNetCore.OpenApi` sin source generator og gir ellers `CS9137`.

### 2d. Oppdater EF Core til v10.0.1

> **VIKTIG:** Bruk `10.0.1`, IKKE `10.0.0`. `EFCore.BulkExtensions 10.0.0` krever `Microsoft.EntityFrameworkCore.Relational >= 10.0.1` og `SqlServer >= 10.0.1` transitivt, noe som vil gi NU1605-feil med 10.0.0.

```xml
<!-- Fra: -->
<PackageReference Include="Microsoft.EntityFrameworkCore" Version="8.0.2" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.2" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Relational" Version="8.0.2" />
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.2" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Tools" Version="8.0.2" />
<PackageReference Include="Microsoft.EntityFrameworkCore.InMemory" Version="8.0.2" /> <!-- testprosjekter -->

<!-- Til: -->
<PackageReference Include="Microsoft.EntityFrameworkCore" Version="10.0.1" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="10.0.1" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Relational" Version="10.0.1" />
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="10.0.1" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Tools" Version="10.0.1" />
<PackageReference Include="Microsoft.EntityFrameworkCore.InMemory" Version="10.0.1" /> <!-- testprosjekter -->
```

### 2e. Sjekk for SqlBulkCopyOptions-konflikt

Hvis prosjektet bruker `EFCore.BulkExtensions` og `Microsoft.Data.SqlClient` i samme fil, vil `SqlBulkCopyOptions` bli tvetydig i ny versjon. Løsning: fjern `using Microsoft.Data.SqlClient;` fra filen dersom den kun ble brukt for `SqlBulkCopyOptions`. `BulkConfig.SqlBulkCopyOptions` skal bruke `EFCore.BulkExtensions`-varianten.

---

## Steg 3: Slett wrapper-fil for gammel autentisering

Finn og slett filen som wrapper `ClientCredentialsConfiguration` fra den gamle pakken. I Varseltjeneste het denne `ClientCredentialsSetup.cs` under `Hjelpeklasser/`. Den typiske signaturen er:

```csharp
// Indikasjon på at dette er rett fil å slette:
using Fhi.ClientCredentialsKeypairs;
// og/eller
public class ClientCredentialsSetup { ... }
```

Slett filen. Funksjonaliteten erstattes av `services.ConfigureHttpClients(Configuration)` i steg 4.

---

## Steg 4: Startup.cs / Program.cs – Refaktorer autentisering og OpenAPI

### 4a. Bytt ut using-direktiver øverst

**Fjern:**
```csharp
using Fhi.HelseId.Api.ExtensionMethods;
using Microsoft.OpenApi.Models;
```

**Legg til:**
```csharp
using System;
using System.Net.Http;
using Fhi.Lmr.Authentication.TokenValidation.ApiAuthentication;
using Fhi.Lmr.Authentication.ClientCredentials.ClientCredentials;
using Scalar.AspNetCore;
```

### 4b. Fjern privat state fra Startup-klassen

**Fjern** disse feltene og konstruktørlogikk:
```csharp
private readonly ClientCredentialsSetup _clientCredentialsSetup;
private readonly IConfigurationSection _configAuthSection;
private readonly HelseId.Api.HelseIdApiKonfigurasjon _configAuth;
public bool UseAuth => _configAuth.AuthUse;
public bool UseHttps => _configAuth.UseHttps;
```

**Etter** – konstruktøren setter `Configuration` og `Environment`. `IWebHostEnvironment` kreves av `AddApiAuthenticationAndAuthorization` fra og med pakkeversjon 10.2 (env-sperre for `UseAuth: false`):
```csharp
public Startup(IConfiguration configuration, IWebHostEnvironment environment)
{
    Configuration = configuration;
    Environment = environment;
}

public IConfiguration Configuration { get; }
public IWebHostEnvironment Environment { get; }
```

### 4c. Bytt ut autentisering og Swagger i `ConfigureServices`

**Fjern:**
```csharp
if (UseAuth)
    services.AddHelseIdAuthorizationControllers(_configAuth);
else
    services.AddControllers().AddJsonOptions(...);

services.AddHttpClient<IMeldingsmottakKlient, MeldingsmottakKlient>(nameof(MeldingsmottakKlient));
// ... alle AddHttpClient-linjer ...

services.AddSwaggerGen(c => { ... }); // hele blokken
```

**Legg til:**
```csharp
services.AddControllers().AddJsonOptions(opt => opt.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));

services.AddOpenApi();
```

### 4d. Registrer HTTP-klienter via ny konfigurasjon

> **EKSTREMT VIKTIG – TIMEOUT-INNSTILLINGER MÅ BEVARES!**
> Den gamle koden brukte ofte `AddHttpClient<T>()` med eksplisitt `Timeout.InfiniteTimeSpan` eller andre custom timeout-verdier. Når man bytter til `ConfigureHttpClients()` + `IHttpClientFactory.CreateClient()`, følger IKKE timeout-innstillingene med. Alle klienter faller da tilbake til `HttpClient`-standarden på **100 sekunder**.
>
> **Produksjonsbug:** I Individdatauttrekk (PR 36891) førte dette til at store nøkkelfiler som krevde lang prosesseringstid i Pasientregisteret feilet med `TaskCanceledException`. Bakgrunnstjenesten (`ImporterNøkkelfilerBackgroundService`) feiltolket timeout som shutdown og stoppet hele tjenesten.
>
> **Sjekk ALLTID** den eksisterende koden for timeout-innstillinger på `HttpClient` før migrering:
> - Søk etter `Timeout` i alle filer som registrerer HTTP-klienter
> - Søk etter `InfiniteTimeSpan`, `TimeSpan.From` i sammenheng med HTTP-klienter
> - Dersom en klient hadde custom timeout, MÅ dette bevares etter migrering

Etter `KonfigurerAuth(services)`, legg til registrering av HTTP-klienter manuelt via `IHttpClientFactory`. Mønsteret er:

```csharp
var meldingsmottakConfig = Configuration.GetSection("Apis:MeldingsmottakApi").Get<OidcHttpClientOption>()
    ?? throw new InvalidOperationException("MeldingsmottakApi ikke konfigurert i appsettings. Forventet seksjon: Apis:MeldingsmottakApi");
services.AddScoped<IMeldingsmottakKlient>(sp =>
{
    var client = sp.GetRequiredService<IHttpClientFactory>().CreateClient(meldingsmottakConfig.HttpClientName);
    // VIKTIG: Bevar eventuelle timeout-innstillinger fra den gamle konfigurasjonen.
    // Eksempel: Hvis den gamle koden hadde Timeout.InfiniteTimeSpan, sett det her:
    // client.Timeout = Timeout.InfiniteTimeSpan;
    return new MeldingsmottakKlient(client, sp.GetRequiredService<ILogger<MeldingsmottakKlient>>());
});
```

Gjenta for alle HTTP-klienter i tjenesten (hent navnene fra `Apis`-seksjonen i appsettings).

> **Sjekkliste for timeout-migrering:**
> 1. Finn alle `AddHttpClient<T>()` i den gamle koden
> 2. Sjekk om noen av dem setter `.Timeout` i konfigurasjonsblokken
> 3. For hver klient med custom timeout: sett `client.Timeout = ...` etter `CreateClient()`
> 4. Spør brukeren dersom det er uklart om en klient trenger lang timeout (f.eks. klienter som laster opp/ned store filer)

### 4e. Oppdater `KonfigurerAuth`

**Før:**
```csharp
private void KonfigurerAuth(IServiceCollection services)
{
    services.AddSingleton<HelseId.Common.IAutentiseringkonfigurasjon>(_configAuth);
    services.AddHelseIdApiAuthentication(_configAuth);
    services.Configure<HelseId.Api.HelseIdApiKonfigurasjon>(_configAuthSection);
    _clientCredentialsSetup.ConfigureServices(services);
}
```

**Etter:**
```csharp
private void KonfigurerAuth(IServiceCollection services)
{
    services.AddApiAuthenticationAndAuthorization(Configuration, Environment);
    services.ConfigureHttpClients(Configuration);
}
```

### 4f. Bytt ut Swagger-middleware – KUN hvis Swashbuckle ble fjernet

**Fjern:**
```csharp
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "...");
    c.RoutePrefix = "swagger";
});
```

**Fjern** betinget auth og erstatt med ubetinget:
```csharp
// Fjern:
if (UseAuth)
    app.UseAuthentication();

// Legg til:
app.UseAuthentication();
```

**Legg til** OpenAPI/Scalar kun i ikke-prod, inne i `endpoints`-blokken:
```csharp
if (!env.IsProduction())
{
    endpoints.MapOpenApi();
    endpoints.MapScalarApiReference(options =>
        options.WithTitle("API for <TjenestenNavn>").WithTheme(ScalarTheme.Kepler));
}
```

Husk å legge til `.AllowAnonymous()` på helsesjekk-endepunktet:
```csharp
endpoints.MapHealthChecks("/health", new HealthCheckOptions { ... }).AllowAnonymous();
```

### 4g. Oppdater launchUrl i launchSettings.json

I API-prosjektet, finn `Properties/launchSettings.json` og bytt ut `launchUrl` fra `swagger` til `scalar/v1`:

```json
// Før:
"launchUrl": "swagger"

// Etter:
"launchUrl": "scalar/v1"
```

---

## Steg 5: appsettings-filer – Migrer autentiseringskonfigurasjon

Gjør dette i **alle** appsettings-filer (`appsettings.json`, `appsettings.Development.json`, `appsettings.Azure.json`, `appsettings.AzureDev.json`, `appsettings.QA.json`, `appsettings.Test.json`, `appsettings.Docker.json`, osv.).

### 5a. Connection string – legg til TrustServerCertificate

```json
"VarseltjenesteDb": "Data Source=.;Initial Catalog=...;Integrated Security=True; TrustServerCertificate=true"
```

### 5b. Logging – bytt ut Fhi.HelseId med Polly

```json
// Før:
"Fhi.HelseId": "Warning"

// Etter:
"Polly": "Warning"
```

### 5c. Whitelist – oppdater nøkler

> **EKSTREMT VIKTIG:** `OidcClients` skal ALDRI være i whitelisten. Denne seksjonen inneholder private nøkler og klient-IDer som ikke skal eksponeres via whitelist-endepunktet. Fjern den dersom den ble lagt til ved en feil.

```json
// Før:
"WhiteListe": [
  "AutoMigrate",
  "HelseIdWorkerKonfigurasjon:Apis",
  "HelseIdWorkerKonfigurasjon:Authority",
  "HelseIdWorkerKonfigurasjon:AuthUse",
  ...
]

// Etter:
"WhiteListe": [
  "AutoMigrate",
  "ApiTokenValidation",
  "Apis",
  ...
]
```

Nøkler som IKKE skal være i whitelist: `OidcClients`, `ClientCredentialsConfiguration`, `privateJwk`, `PrivateKey`.

### 5d. Bytt ut `HelseIdApiKonfigurasjon` med `ApiTokenValidation`

```json
// Før:
"HelseIdApiKonfigurasjon": {
  "Authority": "https://helseid-sts.nhn.no/",
  "ApiName": "fhi:lmr.varseltjeneste",
  "ApiScope": "fhi:lmr.varseltjeneste/all",
  "AuthUse": "true",
  "RequireDPoPTokens": true,
  "AllowDPoPTokens": true
}

// Etter:
"ApiTokenValidation": {
  "Authority": "https://helseid-sts.nhn.no/",
  "Audience": "fhi:lmr.varseltjeneste",
  "DefaultScope": "fhi:lmr.varseltjeneste/all",
  "Scopes": [],
  "RequireDPoP": true,
  "UseAuth": true
}
```

> Nøkkelendringer: `AuthUse` → `UseAuth`, `ApiName` → `Audience`, `ApiScope` → `DefaultScope`, `RequireDPoPTokens`/`AllowDPoPTokens` → `RequireDPoP`. I development/lokal bør `"UseAuth": false`.

### 5e. Bytt ut `ClientCredentialsConfiguration` med `OidcClients` + `Apis`

**Før:**
```json
"ClientCredentialsConfiguration": {
  "clientName": "...",
  "authority": "https://helseid-sts.nhn.no/connect/token",
  "clientId": "<guid>",
  "grantTypes": ["client_credentials"],
  "scopes": ["fhi:lmr.grunndata/all", ...],
  "privateJwk": "...",
  "Apis": [
    {
      "Name": "MeldingsmottakKlient",
      "Url": "https://api.lmr.fhi.no/meldingsmottak/api/",
      "Scope": "fhi:lmr.meldingsmottak/all",
      "UseDpop": true
    }
  ],
  "refreshTokenAfterMinutes": 8
}
```

**Etter:**
```json
"OidcClients": {
  "HelseIdClient": {
    "Authority": "https://helseid-sts.nhn.no/",
    "ClientId": "<guid>",
    "PrivateKey": "..."
  }
},
"Apis": {
  "MeldingsmottakApi": {
    "BaseAddress": "https://api.lmr.fhi.no/meldingsmottak/api/",
    "HttpClientName": "MeldingsmottakKlient",
    "OidcClientName": "HelseIdClient",
    "Scope": "fhi:lmr.meldingsmottak/all",
    "UseDPoP": true
  }
  // ... legg til alle Apis tjenesten bruker
}
```

> Nøkkelendringer:
> - `clientId` → `ClientId`, `privateJwk` → `PrivateKey`, `authority` → `Authority` (flyttes inn under `OidcClients.HelseIdClient`)
> - `Apis[].Name` → nøkkel i `Apis`-objektet (f.eks. `MeldingsmottakApi`)
> - `Apis[].Url` → `BaseAddress`
> - `UseDpop` → `UseDPoP`
> - Legg til `HttpClientName` (= gammel `Name`) og `OidcClientName` (alltid `"HelseIdClient"`)
> - `scopes`-listen, `grantTypes` og `refreshTokenAfterMinutes` på toppnivå bortfaller

---

## Steg 6: Controllere – Bytt Swagger-attributter med OpenAPI-attributter

> **VIKTIG:** Gjør dette steget KUN hvis Swashbuckle ble fjernet i steg 2c.

### 6a. Bytt using-direktiv

```csharp
// Fjern:
using Swashbuckle.AspNetCore.Annotations;

// Legg til:
using Microsoft.AspNetCore.Http;
```

### 6b. Bytt attributter på hvert endepunkt

**Før:**
```csharp
[SwaggerOperation(Summary = "Henter en liste med varsler.", Description = "Returnerer en paginert liste med varsler som møter de angitte kriteriene.")]
[SwaggerResponse(200, "En liste med alle varsler som møter de angitte kriteriene.", typeof(string))]
public async Task<ActionResult> GetVarselListe(...)
```

**Etter:**
```csharp
[EndpointSummary("Henter en liste med varsler.")]
[EndpointDescription("Returnerer en paginert liste med varsler som møter de angitte kriteriene.")]
public async Task<ActionResult> GetVarselListe(...)
```

> `[SwaggerResponse(...)]` bortfaller helt. `[EndpointSummary("...")]` erstatter `[SwaggerOperation(Summary = "...")]` og `[EndpointDescription("...")]` erstatter `[SwaggerOperation(Description = "...")]`. **VIKTIG:** Bevar alle eksisterende descriptions — ikke utelat dem selv om de ligner på summary. Scalar viser begge.

---

## Steg 7: Pipeline YAML-filer

### 7a. CI-pipeline (f.eks. `<Tjeneste>.CI.yml`)

```yaml
# Før:
- template: templates/restoreandbuild6gv.yaml@FhiLmrDevOps
- template: templates/unittests.yaml@FhiLmrDevOps

# Etter:
- template: templates/restoreandbuild-sdkinstall-net10.yaml@FhiLmrDevOps
- template: templates/unittests-sdkinstall-net10.yaml@FhiLmrDevOps
```

### 7b. Publish-pipelines (f.eks. `<Tjeneste>.AzureDev.Publish.yml`, `<Tjeneste>.Nhn.Publish.yml`, og ALLE andre publish-pipelines)

> **VIKTIG:** GitVersion-blokken skal legges til i **alle** publish-pipelines, ikke bare AzureDev. Dette gjelder Nhn, Integrasjon, L4Integrasjon, Spesielltest, TestDataSeed, Ytelse – alle som har en build stage.

**Legg til `fetchDepth: 0`** på checkout:
```yaml
- checkout: self
  persistCredentials: true
  fetchDepth: 0
```

**Legg til GitVersion-blokk** etter checkout.

> **VIKTIG: Kopier denne blokken NØYAKTIG som vist.** Variabelnavn (`$semver`, `$date`), displayName-tekster og output-verdier skal være identiske i alle pipelines. Spesielt: `GitVersionVal` skal settes til `$semver` (UTEN dato). Build-nummeret inkluderer dato via `${semver}+${date}`, men output-variabelen er BARE semver. Ikke kombiner disse til én variabel.

```yaml
    - task: UseDotNet@2
      displayName: 'Installer .NET SDK 10.0.x'
      inputs:
        version: '10.0.x'

    - task: DotNetCoreCLI@2
      displayName: 'Installer GitVersion'
      inputs:
        command: 'custom'
        custom: 'tool'
        arguments: 'update GitVersion.Tool --tool-path $(Agent.ToolsDirectory)/gitversion/5.12.0 --version 5.12.0 --add-source https://api.nuget.org/v3/index.json --ignore-failed-sources'

    - script: $(Agent.ToolsDirectory)/gitversion/5.12.0/dotnet-gitversion $(Build.Repository.LocalPath) /output buildserver /updateprojectfiles
      displayName: 'Kjør GitVersion'

    - powershell: |
        $semver = $env:GITVERSION_FULLSEMVER
        $date = git log -1 --format=%cd --date=format:'%Y%m%d'
        Write-Host "##vso[build.updatebuildnumber]${semver}+${date}"
        Write-Host "##vso[task.setvariable variable=GitVersionVal;isOutput=true]$semver"
      name: Version
      displayName: 'Sett versjonsnummer'
```

**Bytt templates:**
```yaml
# Før:
- template: templates/restoreandbuild6gv.yaml@FhiLmrDevOps
- template: templates/unittests.yaml@FhiLmrDevOps

# Etter:
- template: templates/restoreandbuild-sdkinstall-net10.yaml@FhiLmrDevOps
  parameters:
    buildConfiguration: $(buildConfiguration)
- template: templates/unittests-sdkinstall-net10.yaml@FhiLmrDevOps
```

> **VIKTIG:** `restoreandbuild-sdkinstall-net10.yaml` MÅ få `buildConfiguration: $(buildConfiguration)` som parameter. Uten denne bruker templaten sin default-konfigurasjon (Debug), mens publish-steget kjører med `--no-build --configuration Release`. Det gir feilen `staticwebassets.build.json not found` fordi build-artefaktene havner i `obj\Debug\` mens publish leter i `obj\Release\`.

**Bytt ut DeployInfo-blokken.**

> **VIKTIG: Kopier denne blokken NØYAKTIG som vist.** DeployInfo skal alltid inneholde alle 6 felter (buildversion, buildconfiguration, buildnumber, branch, commit, buildtime). Ikke bruk den gamle forenklede varianten med bare 2 felter. Alle pipelines skal bruke identisk DeployInfo-blokk.

Fjern alle eksisterende DeployInfo-tasks (enten `powershell:` eller `task: PowerShell@2` med `Set-Content`/`Add-Content`). Erstatt med:

```yaml
    - powershell: |
        $info = @{
          buildversion       = "$(Build.BuildNumber)"
          buildconfiguration = "$(buildConfiguration)"
          buildnumber        = "$(Build.BuildNumber)"
          branch             = "$(Build.SourceBranchName)"
          commit             = "$(Build.SourceVersion)".Substring(0, 8)
          buildtime          = (Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
        }
        $content = $info.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key): $($_.Value)" }
        $content | Out-File "$(Build.SourcesDirectory)/$(prosjektkatalog)/DeployInfo.txt" -Encoding UTF8
        Write-Host "DeployInfo.txt innhold:"
        $content | ForEach-Object { Write-Host "  $_" }
      displayName: 'Generer DeployInfo.txt'
```

**Bytt ut GitVersion-variabelnavn** i git tag-script og stage-avhengigheter:

```yaml
# Før:
git tag $(GitVersionVar.GitVersionVal)
git push origin $(GitVersionVar.GitVersionVal)
GitVersion: $[dependencies.Build.Build.outputs['GitVersionVar.GitVersionVal']]

# Etter:
git tag $(Version.GitVersionVal)
git push origin $(Version.GitVersionVal)
GitVersion: $[dependencies.Build.Build.outputs['Version.GitVersionVal']]
```

---

## Avklarende spørsmål

Spør brukeren om dette er uklart eller varierer:

1. **HTTP-klienter**: Hvilke HTTP-klienter bruker tjenesten mot andre APIer? (Navnene må stemme med `Apis`-seksjonen i appsettings)
1. **Timeout-innstillinger**: Har noen av HTTP-klientene custom timeout (f.eks. `Timeout.InfiniteTimeSpan`)? Disse MÅ bevares ved migrering – standard `HttpClient`-timeout på 100 sekunder kan forårsake `TaskCanceledException` i produksjon for langvarige operasjoner.
2. **Swashbuckle**: Bygg prosjektet etter å ha oppdatert pakker. Gi beskjed om det er build-feil relatert til Swashbuckle – da aktiveres steg 2c, 4f og 6.
3. **Pipeline-navn**: Hvilke YAML-filer har publish-pipelines? (Alle skal ha GitVersion-blokk og nye templates)
4. **Miljøspesifikk auth**: Skal `UseAuth` være `false` i development-miljøet?

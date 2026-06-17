# SystemStatus

## Konfigurasjon i Fhi.Lmr.Kontroll

For å legge til en ny tjeneste i SystemStatus-oversikten i Kontroll-applikasjonen, må du gjøre tre endringer i `appsettings.{miljø}.json`:

### 1. Legg til scope

I `HelseIdWebKonfigurasjon.Scopes`-listen, legg til scopet for tjenesten:

```json
"Scopes": [
  ...
  "fhi:lmr.{tjenestenavn}/all"
]
```

### 2. Legg til API-konfigurasjon

I `HelseIdWebKonfigurasjon.Apis`-listen, legg til API-konfigurasjonen:

```json
{
  "Name": "{Tjenestenavn}Service",
  "Url": "https://{miljø}-api.lmr.fhi.no/{tjenestenavn}",
  "Scope": "fhi:lmr.{tjenestenavn}/all"
}
```

### 3. Legg til i SystemStatusKonfigurasjon

I `SystemStatusKonfigurasjon.Tjenester`-listen, legg til tjenestenavnet (alfabetisk sortert):

```json
"SystemStatusKonfigurasjon": {
  "Tjenester": [
    "Administreringslager",
    "Dataprodukter",
    ...
  ]
}
```

### Eksempel: Administreringslager

For å legge til Administreringslager i Test-miljøet (`appsettings.Test.json`):

**Scope:**
```json
"fhi:lmr.administreringslager/all"
```

**API-konfigurasjon:**
```json
{
  "Name": "AdministreringslagerService",
  "Url": "https://test-api.lmr.fhi.no/administreringslager",
  "Scope": "fhi:lmr.administreringslager/all"
}
```

**Tjenester:**
```json
"Administreringslager"
```

### Miljøer

Husk å gjøre endringene i riktig appsettings-fil for miljøet:

| Miljø | Fil |
|-------|-----|
| AzureDev | `appsettings.AzureDev.json` |
| Test | `appsettings.Test.json` |
| QA | `appsettings.QA.json` |
| Prod | `appsettings.json` |

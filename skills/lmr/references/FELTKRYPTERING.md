# Feltkryptering i LMR

Sensitive felter krypteres før de skrives til databasen. Formålet er å beskytte verdier som kan avsløre pasientens eller rekvirentens identitet indirekte — f.eks. et sjeldent legemiddel koblet til en person. Krypteringen håndteres av pakken `Fhi.Lmr.Felles.Kryptering`.

## Pakken Fhi.Lmr.Felles.Kryptering

Pakken tilbyr tre uavhengige krypteringsmekanismer:

| Tjeneste | Algoritme | Bruksområde |
|---|---|---|
| `Krypteringstjeneste` | Rijndael (symmetrisk) | Feltpersistering i database |
| `ApiKrypteringstjeneste` | RSA-hybrid + AES-GCM | Kryptering av API-meldinger |
| `IdentitetsnummerKryptering` | RSA-hybrid + AES-CBC | Kryptering av identitetsnumre (f.eks. fødselsnummer) |

Metoder for feltpersistering:
- `IKrypteringstjeneste.Krypter(string plainText) → string` — krypterer til Base64
- `IKrypteringstjeneste.Dekrypter(string cipherText) → string` — dekrypterer fra Base64

## Konfigurasjon

Rijndael-tjenesten konfigureres via appsettings-seksjonen `FeltKryptering`:

```json
"FeltKryptering": {
  "KeyPath": "/path/to/key.file",
  "VectorPath": "/path/to/vector.file",
  "UseEmbeddedTestKey": false
}
```

- `KeyPath` og `VectorPath` peker til nøkkel- og vektorfiler på disk (brukes i produksjon)
- `UseEmbeddedTestKey: true` benytter testnøkler kompilert inn i DLL-en — kun for utvikling/test

DI-registrering:
```csharp
services.Configure<KrypteringstjenesteOptions>(configuration.GetSection("FeltKryptering"));
services.AddScoped<IKrypteringstjeneste, Krypteringstjeneste>();
```

## Nøkkelhåndtering

- Nøkkel og vektor lagres som filer på disk på serveren der applikasjonen kjører
- Kun tjenestekontoen applikasjonen kjører som har lesetilgang (NTFS-rettigheter)
- Pakken implementerer ingen egne beskyttelsesmekanismer (DPAPI, Azure Key Vault e.l.) — tilgangskontroll er driftsmiljøets ansvar

## Lagring i database

Krypterte felter lagres i egne SQL-skjemaer, adskilt fra klartekstfelter. Skjemanavn følger mønsteret `Kryptert<kilde>`, f.eks.:
- `KryptertEik` — krypterte felter fra Eik-meldinger
- `KryptertFarmapro` — krypterte felter fra Farmapro-meldinger

EF Core-mønster med `OwnsOne` til separat tabell i kryptert-skjema:
```csharp
builder.OwnsOne(k => k.Kryptert, ba =>
{
    ba.Property(p => p.KryptertVarenavn).HasMaxLength(500).IsRequired();
    ba.ToTable(nameof(Legemiddelblanding_Kryptert), Schema.KryptertEik);
});
```

## Hva som krypteres

Felter som potensielt kan avsløre identitet krypteres. Eksempler:
- Varenavn (Legemiddelblanding, Lokalvare, LegemiddelPakning, LegemiddelMerkevare m.fl.)
- Tilberedningsopplysninger og emballasjeinformasjon (Legemiddelblanding)
- Pakningsstørrelse og NavnFormStyrke (lokale varer og pakninger)
- Bruksveiledninger (UtleveringTilMenneske, UtleveringTilDyr)
- Hele JSON-dokumenter ved mellomlagring under prosessering (UtleveringTilBehandling, RekvisisjonTilBehandling)

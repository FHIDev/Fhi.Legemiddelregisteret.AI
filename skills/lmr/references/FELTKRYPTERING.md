# Feltkryptering i LMR

Sensitive felter krypteres før de skrives til databasen. Formålet er å beskytte verdier som kan avsløre identitet, enten direkte (fødselsnummer, D-nummer og HPR-nummer) eller indirekte (f.eks. et sjeldent legemiddel koblet til en person), og meldingsinnhold som mellomlagres. Krypteringen håndteres av pakken `Fhi.Lmr.Felles.Kryptering`, som flere tjenester bruker (se hvilke `.csproj`-filer som refererer pakken). Hva hver tjeneste krypterer, står i dens repo-skill.

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
- `UseEmbeddedTestKey: true` benytter testnøkler kompilert inn i DLL-en — kun for utvikling/test. Flere miljøfiler bruker den, blant annet AzureDev og Docker. Data kryptert med testnøkkelen kan ikke leses med produksjonsnøkkelen, så et miljø med ekte data må få `KeyPath`/`VectorPath` utenfra.

DI-registrering:
```csharp
services.Configure<KrypteringstjenesteOptions>(configuration.GetSection("FeltKryptering"));
services.AddScoped<IKrypteringstjeneste, Krypteringstjeneste>();
```

## Krypteringen er deterministisk

`Krypteringstjeneste` bruker en fast nøkkel og en fast vektor (IV) fra `KeyPath`/`VectorPath`. Samme klartekst gir derfor alltid samme chiffertekst. Det er utledet av konfigurasjonen og bruken; selve Rijndael-implementasjonen kommer fra pakken `Fhi.Felles.Cryptography` og er ikke i Felles-repoet.

Det er en forutsetning for flere tjenester, ikke en bivirkning:

- Tjenester slår opp rader ved å sammenligne chiffertekster i databasen. Pasientregisteret bruker `KryptertIdentitetsnummer` som primærnøkkel i `Kryptert.Identiteter` og finner pasienter ved å sammenligne chiffertekster. Rak slår opp rekvirenter på kryptert HPR-nummer.
- Innføres tilfeldig IV, eller byttes nøkkelen uten at alt som er kryptert krypteres på nytt, finnes ingen eksisterende rad igjen, og hver ny melding lager nye rader.
- Tjenester som mottar meldingsdeler fra Meldingsformidler dekrypterer med samme nøkkel, så et nøkkelbytte må koordineres med avsenderen.

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

Felter som kan avsløre identitet krypteres. Eksempler:
- Identitetsnumre (fødselsnummer og D-nummer) i Pasientregisteret, og HPR-nummer i Rekvirentregisteret og Rak
- Innhold i institusjonsmeldinger (hele bundlen) i FhirMottak, og meldingsdeler i Meldingsmottak
- Varenavn (Legemiddelblanding, Lokalvare, LegemiddelPakning, LegemiddelMerkevare m.fl.)
- Tilberedningsopplysninger og emballasjeinformasjon (Legemiddelblanding)
- Pakningsstørrelse og NavnFormStyrke (lokale varer og pakninger)
- Bruksveiledninger (UtleveringTilMenneske, UtleveringTilDyr)
- Hele JSON-dokumenter ved mellomlagring under prosessering (UtleveringTilBehandling, RekvisisjonTilBehandling)

# Meldingssplitting — Bærum kommune (CSV)

LMR har **ikke lov** til å lagre identitetsopplysninger (FNR, DNR) i samme database som administreringsdata. Splitteren i Meldingsmottak er den eneste tjenesten som ser ekte identiteter — administreringsmeldingen som sendes til Administreringslager inneholder ingen.

## Splitterklasse

**Klasse:** `BærumKommuneInstitusjonsmeldingSplitter`
**Plassering:** `Fhi.Lmr.Meldingsmottak.Applikasjon/Institusjon/Splitting/`

## Parsing og validering

Splitteren bruker CsvHelper med semikolonseparator. Header valideres mot nøyaktig `ForventetHeader` (15 kolonner, case-insensitive):

```
Id, BirthDate, Personnummer, InstitusjonsId, InstitusjonsNavn,
FestID_PreparatGitt, Preparatnavn_PreparatGitt, Mengde_PreparatGitt, Enhet_PreparatGitt,
Status_Administrering, VedBehov, Tidspunkt_Administrering,
FestId_PreparatRekvirert, Preparatnavn_PreparatRekvirert, Tidspunkt_Opprettet_UTC
```

## Anonymisering

Kolonne-indeks 2 (`Personnummer`) overskrives med `"00000000000"` direkte i rad-arrayet før CSV-raden rekonstrueres til `CsvElement`.

## Kobling mellom delmeldinger

`Administreringsreferanse` = radnummer som streng (`"1"`, `"2"`, `"3"` ...). Ingen FHIR-referanser — enkel heltallskobling. Pasientregister returnerer `PasientlisteFhir` med `Administreringsreferanse = "1"` → `PasientId = <tildelt>`.

`AdministreringsIdFraBærum` i Administreringslager er CSV `Id`-kolonnen (kolonne-indeks 0) og brukes til duplikatdeteksjon — det er et separat felt som ikke er koblingsnøkkelen.

## Datoformat

`Tidspunkt_Administrering` (kolonne-indeks 11) forventes strengt i formatet `"yyyy-MM-dd HH:mm:ss"`. Ugyldig format kaster `InvalidOperationException`.

## To delmeldinger produseres — ingen rekvirentmelding

CSV-formatet inneholder ingen HPR-nummer, så det produseres aldri rekvirentmelding:

| Delmelding | Innhold | Destinasjon |
|---|---|---|
| `PasientmeldingFraInstitusjonsmelding` | FNR + radnummer som `Administreringsreferanse` | Pasientregister |
| `AdministreringsmeldingBærumCsv` | Liste av CSV-rader med personnummer maskert | Administreringslager |

Se [MELDINGSKONTRAKTER-INSTITUSJON.md](./MELDINGSKONTRAKTER-INSTITUSJON.md) for meldingskontraktene og hvordan Administreringslager kobler pasientlisten mot CSV-dataene.

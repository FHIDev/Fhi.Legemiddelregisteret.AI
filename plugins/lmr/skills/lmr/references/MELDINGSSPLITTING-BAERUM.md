# Meldingssplitting — Bærum kommune (CSV)

LMR har **ikke lov** til å lagre identitetsopplysninger (FNR, DNR) i samme database som administreringsdata. Splitteren i Meldingsmottak er den eneste tjenesten som ser identitet og legemiddeldata samtidig og skiller dem: FhirMottak lagrer hele CSV-meldingen, men kryptert, og Pasientregister lagrer bare identitetene. Administreringsmeldingen som sendes til Administreringslager inneholder ingen identiteter.

Denne fila beskriver kontrakten nedstrøms tjenester ser. Implementasjonen står i splitterkoden i Meldingsmottak, og det som gjelder implementasjonen, i repo-skillen `lmr-meldingsmottak`. CSV-formatet (kolonnene) er beskrevet i `MELDINGSFLYT-BAERUM.md`.

## To delmeldinger produseres — ingen rekvirentmelding

CSV-formatet inneholder ingen HPR-nummer, så det produseres aldri rekvirentmelding:

| Delmelding | Innhold | Destinasjon |
|---|---|---|
| `PasientmeldingFraInstitusjonsmelding` | FNR + radnummer som `Administreringsreferanse` | Pasientregister |
| `AdministreringsmeldingBærumCsv` | Liste av CSV-rader med personnummer maskert til `00000000000` | Administreringslager |

## Kobling mellom delmeldinger

`Administreringsreferanse` = radnummer som streng (`"1"`, `"2"`, `"3"` ...). Ingen FHIR-referanser — enkel heltallskobling. Pasientregister returnerer `PasientlisteFhir` med `Administreringsreferanse = "1"` → `PasientId = <tildelt>`.

`AdministreringsIdFraBærum` i Administreringslager er CSV `Id`-kolonnen og brukes til duplikatdeteksjon — det er et separat felt som ikke er koblingsnøkkelen.

Se `MELDINGSKONTRAKTER-INSTITUSJON.md` for meldingskontraktene og hvordan Administreringslager kobler pasientlisten mot CSV-dataene.

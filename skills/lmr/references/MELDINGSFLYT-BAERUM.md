# Meldingsflyt — Bærum kommune (CSV)

Bærum kommune er et pilotprosjekt der kommunen leverer legemiddeladministreringsdata i CSV-format. Flyten skiller seg fra FHIR-flyten ved at det ikke finnes rekvirentdata i CSV-meldingene, og at inngangspunktet er direkte CSV-upload via API.

Av personvernhensyn splittes innkommende meldinger i separate deler som lagres i ulike registre — identitetsopplysninger lagres aldri sammen med administreringsdata.

## Flytdiagram

```
Bærum kommune
  |
  | CSV via API
  v
FhirMottak
  |
  | Meldingsformidler leverer melding
  v
Meldingsmottak (splitter melding)
  |
  ├── Pasientmelding ────→ Pasientregister ──→ Pasientliste ──→ Administreringslager
  └── Administreringsmelding (uten identiteter) ──────────────→ Administreringslager
                                                                        |
                                                                Prosesseres når begge
                                                                er mottatt
```

Alle piler mellom tjenestene er Meldingsformidler som orkestrerer transporten.

## Trinnvis beskrivelse

| Trinn | Beskrivelse |
|---|---|
| 0 | Bærum kommune leverer melding (CSV) via API til FhirMottak |
| 1 | Meldingsformidler leverer melding til Meldingsmottak |
| 2 | Meldingsmottak splitter melding i to: Administreringsmelding og Pasientmelding |
| 3 | Meldingsformidler sender Administreringsmelding til Administreringslager |
| 4 | Meldingsformidler sender Pasientmelding til Pasientregister |
| 5 | Pasientregister lagrer pasientene og tilordner PasientId. Lager en Pasientliste som Meldingsformidler sender til Administreringslager |
| 6 | Når Administreringslager har mottatt Administreringsmelding og Pasientliste, prosesseres meldingen. Administreringslager tilordner AdministreringsId og kobler data via PasientId |

## Meldingsformat (CSV)

FhirMottak mottar CSV innpakket som en `SignertKryptertBundle` — signert og kryptert med AES-GCM.

**API-endepunkt:**
- `POST /fhirmottak/barumKommune`

Meldingen deserialiseres, dekomprimeres (gzip), valideres mot forventet CSV-header og lagres kryptert i FhirMottak-databasen.

**CSV-kolonner (semikolonseparert):**

| Kolonne | Innhold |
|---|---|
| Id | Rad-ID |
| BirthDate | Fødselsdato |
| Personnummer | FNR/DNR — **maskeres** til `00000000000` i Administreringsmelding |
| InstitusjonsId | Institusjonens ID |
| InstitusjonsNavn | Institusjonens navn |
| FestID_PreparatGitt | FEST-kode for legemiddel gitt |
| Preparatnavn_PreparatGitt | Navn på legemiddel gitt |
| Mengde_PreparatGitt | Dose |
| Enhet_PreparatGitt | Enhet (mg, ml e.l.) |
| Status_Administrering | Status |
| VedBehov | Flagg for ved-behov-administrering |
| Tidspunkt_Administrering | Tidspunkt for administrering |
| FestId_PreparatRekvirert | FEST-kode for rekvirert preparat |
| Preparatnavn_PreparatRekvirert | Navn på rekvirert preparat |
| Tidspunkt_Opprettet_UTC | Tidspunkt opprettet (UTC) |

## Splitting i Meldingsmottak

Splitting utføres av `BærumKommuneInstitusjonsmeldingSplitter`. Personnummer (kolonne-indeks 2) maskeres til `00000000000`. `Administreringsreferanse` er radnummeret som streng (`"1"`, `"2"`, `"3"` ...). Ingen rekvirentmelding — CSV-formatet inneholder ingen HPR-nummer.

Se [MELDINGSSPLITTING-BAERUM.md](./MELDINGSSPLITTING-BAERUM.md) for fullstendig teknisk beskrivelse, inkludert datoformat og CsvHelper-konfigurasjon.

Se [MELDINGSKONTRAKTER-INSTITUSJON.md](./MELDINGSKONTRAKTER-INSTITUSJON.md) for meldingskontraktene og hvordan Administreringslager kobler pasientlisten mot CSV-dataene.

## Forskjell fra FHIR-flyten

Bærum kommune-flyten har **ikke** rekvirentmelding — CSV-formatet inneholder ikke rekvirentdata. Administreringslageret kobler derfor kun via PasientId, ikke RekvirentId.

## Tjenester involvert

| Tjeneste | Rolle i Bærum-flyten |
|---|---|
| FhirMottak | Mottar CSV fra Bærum kommune via API (`BarumKommuneRequestHandler`) |
| Meldingsformidler | Orkestrerer all transport mellom tjenestene |
| Meldingsmottak | Mottar og splitter meldinger (`BærumKommuneInstitusjonsmeldingSplitter`) |
| Pasientregister | Lagrer pasientidentiteter, tildeler PasientId, produserer Pasientliste |
| Administreringslager | Lagrer legemiddeldata om administreringer — uten identiteter, kobler via PasientId |

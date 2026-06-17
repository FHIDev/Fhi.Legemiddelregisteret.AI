# Meldingsflyt — øvrige institusjoner (FHIR)

LMR mottar meldinger om legemiddeladministreringer fra sykehus og sykehjem via regionale helseforetak. Meldingene leveres som HL7 FHIR R4 Bundles med MedicationAdministration-ressurser.

Av personvernhensyn splittes innkommende meldinger i separate deler som lagres i ulike registre — identitetsopplysninger lagres aldri sammen med administreringsdata.

## Flytdiagram

```
Regionalt helseforetak (sykehus/sykehjem)
  |
  | FHIR Bundle via API
  v
FhirMottak
  |
  | Meldingsformidler leverer melding
  v
Meldingsmottak (splitter melding)
  |
  ├── Pasientmelding ──────→ Pasientregister ──→ Pasientliste ──→ Administreringslager
  ├── Rekvirentmelding ────→ Rekvirentregister → Rekvirentliste → Administreringslager
  └── Administreringsmelding (uten identiteter) ─────────────────→ Administreringslager
                                                                          |
                                                                  Prosesseres når alle
                                                                  tre er mottatt
```

Alle piler mellom tjenestene er Meldingsformidler som orkestrerer transporten.

## Trinnvis beskrivelse

| Trinn | Beskrivelse |
|---|---|
| 0 | Regionalt helseforetak leverer melding (FHIR Bundle) via API til FhirMottak |
| 1 | Meldingsformidler leverer melding til Meldingsmottak |
| 2 | Meldingsmottak splitter melding i tre: Administreringsmelding, Pasientmelding og Rekvirentmelding |
| 3 | Meldingsformidler sender Administreringsmelding til Administreringslager |
| 4 | Meldingsformidler sender Pasientmelding til Pasientregister |
| 5 | Pasientregister lagrer pasientene og tilordner PasientId. Lager en Pasientliste som Meldingsformidler sender til Administreringslager |
| 6 | Meldingsformidler sender Rekvirentmelding til Rekvirentregister |
| 7 | Rekvirentregister lagrer rekvirentene og tilordner RekvirentId. Lager en Rekvirentliste som Meldingsformidler sender til Administreringslager |
| 8 | Når Administreringslager har mottatt Administreringsmelding, Pasientliste og Rekvirentliste, prosesseres meldingen. Administreringslager tilordner AdministreringsId og kobler data via PasientId og RekvirentId |

## Meldingsformat

FhirMottak mottar **HL7 FHIR R4 Bundles** innpakket som en `SignertKryptertBundle` — kryptert med AES-256-GCM og signert med avsenders virksomhetssertifikat. Autentisering skjer via **Maskinporten** (scope: `fhi:lmr/fhirmottak.api`).

**API-endepunkter:**
- Prod: `https://fhirmottak.lmr.fhi.no/fhirmottak/v1`
- Test: `https://test-fhirmottak.lmr.fhi.no/fhirmottak/v1`

**Ressurser i en FHIR Bundle:**

| Ressurs | Innhold |
|---|---|
| Patient | FNR eller D-nummer, kjønn, fødselsdato, kommune |
| Practitioner | HPR-nummer (rekvirent) |
| MedicationAdministration | Tidspunkt, dose, administrasjonsvei, kategori |
| Medication | Legemiddelkode fra FEST (Merkevare, Pakning, Virkestoff o.l.) |
| Organization | Organisasjonsnummer (ENH/RESH), navn, hierarki |
| Encounter | Episode (innleggelse/poliklinisk), tidsperiode |
| Condition | Diagnose (ICD-10/SNOMED CT) — valgfritt |
| MedicationRequest | Rekvirering med dosering — valgfritt |

Implementasjonsguide for avsendere (eksternt): [LMDI på GitHub](https://github.com/folkehelseinstituttet/LMDI)

## Splitting i Meldingsmottak

Splitting utføres av `FhirBundleInstitusjonsmeldingSplitter` (`Fhi.Lmr.Meldingsmottak.Applikasjon/Institusjon/Splitting/`).

Splittingen skjer i to steg: ekstraher identiteter og `Administreringsreferanse` per `MedicationAdministration` → masker `Identifier.Value` i bundle og serialiser tilbake. Én post per administrering — ingen deduplicering av pasienter eller rekvirenter.

Se [MELDINGSSPLITTING-INSTITUSJON-FHIR.md](./MELDINGSSPLITTING-INSTITUSJON-FHIR.md) for fullstendig teknisk beskrivelse av splitte-steg, OID-konstanter og anonymiseringslogikk.

Se [MELDINGSKONTRAKTER-INSTITUSJON.md](./MELDINGSKONTRAKTER-INSTITUSJON.md) for meldingskontraktene (`PasientmeldingFraInstitusjonsmelding`, `RekvirentmeldingFraInstitusjonsmelding`, `PasientlisteFhir`, `RekvirentlisteFhir`) og hvordan Administreringslager kobler alt sammen.

**Tre delmeldinger produseres:**

| Delmelding | Innhold | Destinasjon |
|---|---|---|
| `PasientmeldingFraInstitusjonsmelding` | FNR/DNR + `Administreringsreferanse` + `Administeringsdato` per administrering | Pasientregister |
| `RekvirentmeldingFraInstitusjonsmelding` | HPR-nummer + `Administreringsreferanse` per administrering | Rekvirentregister |
| `AdministreringsmeldingFhirBundle` | FHIR Bundle med maskerte `Identifier.Value`-felter — struktur og referanser uendret | Administreringslager |

Rekvirentmelding produseres kun dersom bundlen inneholder `Practitioner`-ressurser med HPR-nummer.

## Parallellitet i meldingslevering

Meldingsformidler leverer alle tre delmeldinger uavhengig og parallelt via separate bakgrunnstjenester (`SendMeldingerHostedService<T>`). Det er ingen sekvensering mellom Pasientmelding og Rekvirentmelding — de kjøres simultant. Administreringslager venter internt til alle tre er mottatt før prosessering starter.

## Tjenester involvert

| Tjeneste | Rolle i institusjonsflyt (FHIR) |
|---|---|
| FhirMottak | Inngangsport for FHIR-meldinger fra regionale helseforetak (`V1RequestHandler`) |
| Meldingsformidler | Orkestrerer all transport mellom tjenestene |
| Meldingsmottak | Mottar og splitter meldinger (`FhirBundleInstitusjonsmeldingSplitter`) |
| Pasientregister | Lagrer pasientidentiteter, tildeler PasientId, produserer Pasientliste |
| Rekvirentregister | Lagrer rekvirentidentiteter, tildeler RekvirentId, produserer Rekvirentliste |
| Administreringslager | Lagrer legemiddeldata om administreringer — uten identiteter, kobler via PasientId og RekvirentId |

## Databaseskjema for feilsøking

### FhirMottak-databasen

```sql
-- Finn en melding og se mottaksstatus
SELECT MeldingsId, TidspunktGenerert, TidspunktMottatt,
       TidspunktAllokertForOverføring, Meldingshash
FROM dbo.Institusjonsmeldinger          -- NB: flertall (EF-navnekonvensjon)
WHERE MeldingsId = '<guid>'

-- Logghistorikk for en melding
SELECT CreatedAt, Logghendelsetekst
FROM dbo.Mottakslogg
WHERE MeldingsId = '<guid>'
ORDER BY CreatedAt
```

Bundleinnholdet lagres kryptert i `Kryptert.Institusjonsmeldingsinnhold` som `varbinary(max)` — kan ikke leses direkte.

### Meldingsmottak-databasen

```sql
-- Overordnet status for institusjonsmelding
-- StatusKode: 1=Mottatt, 2=UnderProsessering, 3=Slettet, 4=Stoppet,
--             5=KlarForOverføringAvMeldingsdeler, 6=MeldingsdelerErOverført,
--             7=FerdigBehandlet, 8=AvbruttProsessering
SELECT MeldingsId, StatusKode, AntallGangerPrøvd,
       UnderProsessering, PrøvIgjenTidspunkt,
       MeldingsDelerErKlarForOverføring, FerdigBehandlet,
       Stoppet, StoppetArsakKode, Avbrutt, UpdatedAt
FROM Institusjon.Institusjonsmelding
WHERE MeldingsId = '<guid>'

-- Status på hver meldingsdel (levering til målregistre)
SELECT MeldingsId, AllokertForOverføringTilOgMed, Overført, FerdigBehandlet
FROM Institusjon.Pasientmelding
WHERE MeldingsId = '<guid>'

SELECT 'Administrering' AS Del, MeldingsId, AllokertForOverføringTilOgMed, Overført, FerdigBehandlet
FROM Institusjon.Administreringsmelding
WHERE MeldingsId = '<guid>'
UNION ALL
SELECT 'Rekvirent', MeldingsId, AllokertForOverføringTilOgMed, Overført, FerdigBehandlet
FROM Institusjon.Rekvirentmelding
WHERE MeldingsId = '<guid>'
```

Meldingsdelinnhold lagres kryptert i `KryptertInstitusjon.Pasientmeldingsinnhold`, `.Administreringsmeldingsinnhold`, `.Rekvirentmeldingsinnhold`.

### Pasientregister-databasen

```sql
-- Er pasientmeldingen lagret (staging-tabell)?
-- PK: (MeldingsId, Administreringsreferanse) — én rad per administrering per melding
SELECT *
FROM Kryptert.PasientadministreringTilBehandling
WHERE MeldingsId = '<guid>'
```

### Rekvirentregister-databasen

```sql
-- Er rekvirentmeldingen lagret (staging-tabell)?
-- PK: (MeldingsId, Administreringsreferanse) — én rad per administrering per melding
SELECT *
FROM Kryptert.RekvirentadministreringTilBehandling
WHERE MeldingsId = '<guid>'
```

## Tolkning av meldingsstatus

| Observasjon | Mulig årsak |
|---|---|
| `Pasientmelding.Overført = NULL` og `AllokertForOverføringTilOgMed` oppdateres jevnlig | Pasientregisteret returnerer 500 — meldingen sitter fast i retry-løkke |
| `Kryptert.PasientadministreringTilBehandling` er tom for meldingsId | Transaksjonen i Pasientregisteret rullet tilbake — ingen data committed |
| `Administrering.Overført` er satt men `FerdigBehandlet = NULL` | Administreringslager venter på Pasientliste og/eller Rekvirentliste |
| `StatusKode = 5` og `FerdigBehandlet = NULL` etter lang tid | Minst én meldingsdel klarer ikke å leveres — se logg i Meldingsformidler |


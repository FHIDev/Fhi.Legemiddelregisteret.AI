# Meldingssplitting — øvrige institusjoner (FHIR)

LMR har **ikke lov** til å lagre identitetsopplysninger (FNR, DNR, HPR-nummer) i samme database som administreringsdata. Splitteren i Meldingsmottak er den eneste tjenesten som ser ekte identiteter — administreringsmeldingen som sendes til Administreringslager inneholder ingen.

## Splitterklasse

**Klasse:** `FhirBundleInstitusjonsmeldingSplitter`
**Plassering:** `Fhi.Lmr.Meldingsmottak.Applikasjon/Institusjon/Splitting/`
**Interface:** `IInstitusjonsmeldingSplitter` — `Meldingstype` + `Splitt(melding, originaltInnhold)`

## To steg

### Steg 1 — Ekstraher identiteter per administrering

For **hver** `MedicationAdministration`-entry i bundlen (én post per administrering — ikke per unik pasient/rekvirent):

- **Pasient:** følg `Subject.Reference` → `Patient` → les FNR/DNR fra `Identifier` med OID `urn:oid:2.16.578.1.12.4.1.4.1` (FNR) eller `...4.2` (DNR)
- **Rekvirent:** følg `Request.Reference` → `MedicationRequest` → `Requester.Reference` → `Practitioner` → les HPR-nummer fra `Identifier` med OID `urn:oid:2.16.578.1.12.4.1.4.4`
- **Administeringsdato:** les `effectiveDateTime`, eller `effectivePeriod.start` hvis `effectiveDateTime` mangler
- **Administreringsreferanse:** `entry.FullUrl ?? $"MedicationAdministration/{medAdmin.Id}"`

Tvetydig pasient (har BÅDE FNR og DNR) behandles som "ingen gyldig identitet" og hoppes over.

Det er ingen deduplicering — bundler med mange administreringer for samme pasient eller rekvirent gir mange poster i Pasientmelding og Rekvirentmelding. Pasientregister deduplicerer bostedsoppslag på `(kryptertIdentitetsnummer, dato)` for å unngå redundante kall mot Folkeregisteret.

### Steg 2 — Masker `Identifier.Value`

Det eneste anonymiseringstiltaket splitteren gjør med bundlen:

- `Patient.Identifier.Value` → `00000000000` (11 nuller, beholder format for gyldig FHIR)
- `Practitioner.Identifier.Value` → `0000000` (7 nuller, beholder format for gyldig FHIR)

Alle andre felter, IDer, referanser og struktur beholdes uendret. Bundlen serialiseres tilbake til originalformat (JSON eller XML — oppdages automatisk).

## Tre delmeldinger produseres

| Delmelding | Innhold | Destinasjon |
|---|---|---|
| `PasientmeldingFraInstitusjonsmelding` | FNR/DNR + `Administreringsreferanse` + `Administeringsdato` per administrering | Pasientregister |
| `RekvirentmeldingFraInstitusjonsmelding` | HPR-nummer + `Administreringsreferanse` per administrering | Rekvirentregister |
| `AdministreringsmeldingFhirBundle` | FHIR Bundle med maskerte `Identifier.Value`-felter — struktur og referanser uendret | Administreringslager |

Rekvirentmelding produseres kun hvis bundlen inneholder `Practitioner`-ressurser med gyldig HPR-nummer.

## Begrensning: contained resources

Contained resources støttes ikke og kaster `InvalidOperationException`. Contained resources har egne referanseregler (`#`-prefiks) som kompliserer ekstraksjon, og brukes ikke i LMDI-profilen.

## Felles interface og resultattype

```csharp
public interface IInstitusjonsmeldingSplitter
{
    Institusjonsmeldingstype Meldingstype { get; }
    SplittetInstitusjonsmelding Splitt(Institusjonsmelding melding, string originaltInnhold);
}

public class SplittetInstitusjonsmelding
{
    public required string AdministreringsmeldingInnhold { get; init; }
    public required string PasientmeldingInnhold { get; init; }
    public string? RekvirentmeldingInnhold { get; init; }  // null for Bærum CSV
}
```

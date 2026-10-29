# Meldingssplitting — øvrige institusjoner (FHIR)

LMR har **ikke lov** til å lagre identitetsopplysninger (FNR, DNR, HPR-nummer) i samme database som administreringsdata. Splitteren i Meldingsmottak er den eneste tjenesten som ser identitet og legemiddeldata samtidig og skiller dem: FhirMottak lagrer hele bundlen, men kryptert, og registrene lagrer bare identitetene. Administreringsmeldingen som sendes til Administreringslager inneholder ingen identiteter.

Denne fila eier kontrakten avsendere og nedstrøms tjenester ser. Implementasjonen står i splitterkoden i Meldingsmottak (`FhirBundleInstitusjonsmeldingSplitter.cs`), og det som gjelder implementasjonen, i repo-skillen `lmr-meldingsmottak`.

## Tre delmeldinger produseres

Én post per `MedicationAdministration` i bundlen — ingen deduplicering av pasienter eller rekvirenter. Bundler med mange administreringer for samme pasient gir derfor mange poster i Pasientmelding og Rekvirentmelding (Pasientregister deduplicerer selv bostedsoppslag mot Folkeregisteret).

| Delmelding | Innhold | Destinasjon |
|---|---|---|
| `PasientmeldingFraInstitusjonsmelding` | FNR/DNR + `Administreringsreferanse` + administreringsdato per administrering | Pasientregister |
| `RekvirentmeldingFraInstitusjonsmelding` | HPR-nummer + `Administreringsreferanse` per administrering | Rekvirentregister |
| `AdministreringsmeldingFhirBundle` | FHIR Bundle med maskerte `Identifier.Value`-felter — struktur og referanser uendret | Administreringslager |

Rekvirentmelding lages alltid, også når bundlen ikke har noen `Practitioner` med gyldig HPR-nummer. Da er listen over rekvirenter tom. Pasientmeldingen og rekvirentmeldingen har bare poster for administreringer der identiteten kunne løses; se «Begrensninger».

Koblingsnøkkelen `Administreringsreferanse` er FHIR-referansen til administreringen (entry `fullUrl`, eller `MedicationAdministration/{id}`).

## Maskering (det nedstrøms ser)

Det eneste anonymiseringstiltaket i bundlen som sendes videre:

- `Patient.Identifier.Value` → `00000000000` (11 nuller, beholder format for gyldig FHIR)
- `Practitioner.Identifier.Value` → `0000000` (7 nuller, beholder format for gyldig FHIR)

Alle andre felter, IDer, referanser og struktur beholdes uendret. Bundlen serialiseres tilbake til originalformat (JSON eller XML).

## Begrensninger avsendere må kjenne til

- **Contained resources støttes ikke** — splittingen feiler. Contained resources har egne referanseregler (`#`-prefiks) og brukes ikke i LMDI-profilen.
- **Tvetydig pasient** (har både FNR og DNR) behandles som «ingen gyldig identitet» og hoppes over.
- **Stille tap av koblingsposter:** administreringen står alltid i administreringsmeldingen, men posten i pasient- eller rekvirentmeldingen mangler når pasienten ikke har entydig identitet, når en referanse mangler eller ikke kan løses, eller når Practitioner mangler gyldig HPR-nummer. Meldingen feiler ikke.

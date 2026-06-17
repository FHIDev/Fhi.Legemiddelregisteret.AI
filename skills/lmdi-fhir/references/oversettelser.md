# Tospråklighet — norsk IG med engelsk oversettelseslag

Kilder: `LMDI/input/fsh/**/*.fsh` (translation-extensions), `LMDI/input/pagecontent/en-*.md`, `scripts/lag-en-doklag.py`, `scripts/sjekk-oversettelser.py`, `C:\dev\LMDI\CLAUDE.md` (§ Tospråklighet).

## Prinsipp

IG-en er **norsk** (`language: no` i `sushi-config.yaml`). Engelsk er et oversettelseslag:

1. **FHIR-artefakter**: engelske oversettelser ligger inline i FSH som `translation`-extensions på metadata-elementer.
2. **Dokumentasjonssider**: engelske paralleller som `en-*.md` i `input/pagecontent/`.
3. **HTML-flate**: `scripts/lag-en-doklag.py` etterprosesserer IG Publisher-output til en engelsk speiling under `LMDI/output/en/`. IG Publisher sin innebygde flerspråksmekanisme brukes **ikke** (forsøkt og revertert, se commit `0539a38db`).

## Translation-extension-mønsteret i FSH

Alle oversettbare metadata-felter (`^title`, `^description`, `^short`, `^definition`, `^comment`, `^binding.description`) får en standard FHIR `translation`-extension med `lang = #en`:

```fsh
* ^title.extension[+].url = "http://hl7.org/fhir/StructureDefinition/translation"
* ^title.extension[=].extension[+].url = "lang"
* ^title.extension[=].extension[=].valueCode = #en
* ^title.extension[=].extension[+].url = "content"
* ^title.extension[=].extension[=].valueString = "Patient"
```

Samme mønster på elementnivå, f.eks. `* birthDate ^short.extension[+].url = ...` (se `lmdi-Patient.fsh` for komplette eksempler). Det finnes **ingen separate oversettelsesfiler** (XLIFF/JSON) — `LMDI/translations/` var en forlatt mekanisme og er slettet.

## Regler ved endring av FSH-tekster

- Endres en norsk `^short`/`^definition`/`^description`/`Title`, **skal den engelske translation-extensionen oppdateres tilsvarende** i samme endring.
- Egennavn oversettes ikke: «Legemiddelregisteret», «Folkehelseinstituttet», FEST, NPR, Volven-kodeverksnavn m.fl. beholdes på norsk i engelsk tekst (se commit `434aad41a`).
- Eksempel-**dataverdier** (stedsnavn, organisasjonsnavn, display-tekster i instanser) oversettes ikke.

## Verktøy i LMDI-repoet

| Skript | Formål |
|---|---|
| `scripts/lag-en-doklag.py` | Bygger engelsk speiling under `LMDI/output/en/` ved ordrett substring-erstatning norsk → engelsk i HTML, basert på translation-parene i `LMDI/fsh-generated/resources/*.json`. Krever fullført IG-bygg. |
| `scripts/sjekk-oversettelser.py` | Kun lesende revisjon: lister felter som mangler engelsk oversettelse, og MS-definisjoner der oversettelsen ikke slår inn. |
| `scripts/sjekk-en-output.py` | Kontroll av generert engelsk output. |

**Kjent begrensning**: substring-erstatningen krever eksakt treff. IG Publisher dropper siste punktum og legger til «(this element must be supported)» i mustSupport-tooltips, så lange `definition`-oversettelser slår ikke alltid inn der.

## Engelske dokumentasjonssider

`input/pagecontent/` har engelske paralleller med `en-`-prefiks: `en-index.md`, `en-informasjonsmodell.md`, `en-integrasjon.md`, `en-protokoll.md`, `en-SignertKryptertBundle.md`, `en-eksempelkode_cs.md`, `en-eksempelkode_ps1.md`, `en-profiler.md`, `en-nedlastinger.md`. Ny norsk side → vurder tilsvarende `en-`-side. Header-en i IG-en har språkvelger (norsk/engelsk).

`_glossary-no-en.md` i samme katalog er arbeidsflaten for norsk–engelsk terminologi.

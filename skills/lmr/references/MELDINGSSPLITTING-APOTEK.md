# Meldingssplitting — apotek (Farmapro og Eik)

LMR har **ikke lov** til å lagre identitetsopplysninger (FNR, DNR, HPR-nummer) i samme database som utleveringsdata. Splitteren i Meldingsmottak er den eneste tjenesten som ser ekte identiteter — utleveringsmeldingen som sendes til Utleveringslager inneholder ingen.

## Farmapro (XML)

**Splitterklasse:** `ReseptmeldingSplitter`
**Plassering:** `Fhi.Lmr.Meldingsmottak.Applikasjon/Farmapro/Reseptmelding/Splitt/`

Farmapro sender krypterte XML-meldinger. Splitteren dekrypterer (RSA + symmetrisk nøkkel fra KeyVault) og parser XML via tre generatorer:

| Generator | Produserer | Innhold |
|---|---|---|
| `PasientmeldingGenerator` | `PasientmeldingFarmapro` | FNR/DNR + `UtleveringsnummerIMelding` |
| `UtleveringsmeldingGenerator` | `UtleveringsmeldingFarmapro` | Anonymisert XML + `UtleveringsnummerIMelding` |
| `RekvirentmeldingGenerator` | `RekvirentmeldingFarmapro` | HPR-nummer + `UtleveringsnummerIMelding` |

**Anonymisering:** regex-masking direkte på XML-strengen:
```
<FodselsNr>          → 99999999999  (11 niere)
<HelsePersonellNr>   → 999999999   (9 niere)
<DummyFodselsNr>     → 99999999999
<DummyHelsepersonellNr> → 999999999
```
For dyreresepter maskes også `<FodselsAr>`, `<Kjonn>` og `<Kommune>`.

**Kobling mellom delmeldinger:** `UtleveringsnummerIMelding` — sekvensielt heltall (1, 2, 3 ...) tildelt per utlevering i meldingen. Alle tre delmeldinger bruker samme nummer som kobling.

**Resepttyper:** `TilMenneskeUtenRefusjon`, `TilMenneskeMedRefusjon`, `TilDyr`
**Rekvisisjonstyper:** `SykehusRekvisisjon`, `EgenPraksisRekvisisjon`, `ForskrivingTilSkipRekvisisjon`

Farmasøytiske tjenestemeldinger fra Eik splittes i kun **to** delmeldinger: Pasientmelding + Tjenestemelding — ingen rekvirentmelding.

---

## Eik (JSON)

**Splitterklasse:** `ReseptmeldingSplittetjeneste` (dispatcher) + versjonsspesifikke implementasjoner
**Plassering:** `Fhi.Lmr.Meldingsmottak.Applikasjon/Eik/Melding/Splitt/`

Eik sender JSON-meldinger. Splittingen er versjonsstyrt via strategy-pattern:

| Versjon | Implementasjon |
|---|---|
| V1.06 | `GenererSplittetEikReseptmeldingV106Tjeneste` |
| V1.07 | `GenererSplittetEikReseptmeldingV107Tjeneste` |
| V2.0  | `GenererSplittetEikReseptmeldingV20Tjeneste`  |

**Anonymisering:** feltmanipulasjon på deserialisert objekt FØR re-serialisering:
- `PasientMedIdent.Id` → `EikAnonymisering.FodselsnummerFjernet = "00000000000"` (11 nuller)
- `norskRekvirent.Helsepersonellnummer` → `0`

Rekvirentdata ekstraheres til rekvirentmeldingen _før_ HPR-nummeret nullstilles i utleveringsobjektet.

**Kobling mellom delmeldinger:**
- `UtleveringsnummerIMelding` (sekvensielt heltall) for pasient/utlevering-koblingen
- `RekvisisjonsId` (GUID) for rekvisisjoner og ordinasjoner

**Utleveringstyper:** `UtleveringTilMenneske`, `UtleveringTilDyr`, `UtleveringTilRekvirent`

---

## Sammenligning Farmapro vs. Eik

| | Farmapro | Eik |
|---|---|---|
| **Format** | XML | JSON |
| **Anonymisering** | Regex på XML-streng | Feltmanipulasjon på objekt |
| **Maskeringsverdi FNR** | `99999999999` (niere) | `00000000000` (nuller) |
| **Maskeringsverdi HPR** | `999999999` (niere) | `0` (null) |
| **Kobling** | `UtleveringsnummerIMelding` | `UtleveringsnummerIMelding` + `RekvisisjonsId` |
| **Rekvirentmelding** | Ja | Ja |
| **Antall delmeldinger** | 3 | 3 |

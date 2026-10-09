# Meldingssplitting — apotek (Farmapro og Eik)

LMR har **ikke lov** til å lagre identitetsopplysninger (FNR, DNR, HPR-nummer) i samme database som utleveringsdata. Splitteren i Meldingsmottak er den eneste tjenesten som ser identitet og legemiddeldata samtidig og skiller dem: Meldingsmottak lagrer originalmeldingen bare til den er splittet, og registrene lagrer bare identitetene. Utleveringsmeldingen som sendes til Utleveringslager inneholder ingen identiteter.

Denne fila beskriver kontrakten nedstrøms tjenester ser. Implementasjonen står i splitterkoden i Meldingsmottak, og det som gjelder implementasjonen, i repo-skillen `lmr-meldingsmottak`.

## Hva som splittes

| Meldingstype | Delmeldinger |
|---|---|
| Reseptmelding (Farmapro XML og Eik JSON) | Pasientmelding + Rekvirentmelding + Utleveringsmelding |
| Rekvisisjonsmelding (Eik) | Pasientmelding + Rekvirentmelding + Utleveringsmelding |
| Farmasøytisk tjenestemelding (Eik) | Pasientmelding + Tjenestemelding — ingen rekvirentmelding |
| Lokalvaremelding (Farmapro) | Splittes ikke — lagres kun kryptert |

## Kobling mellom delmeldinger

- `UtleveringsnummerIMelding` — sekvensielt heltall (1, 2, 3 ...) tildelt per utlevering i meldingen. Alle delmeldinger bruker samme nummer som kobling.
- Eik bruker i tillegg `RekvisisjonsId` (GUID) for rekvisisjoner og ordinasjoner.

## Maskerte verdier nedstrøms

Utleveringsmeldingen inneholder maskerte identiteter, og maskeringsverdiene skiller seg per kilde — nyttig å kjenne igjen ved feilsøking nedstrøms:

| | Farmapro | Eik |
|---|---|---|
| **Maskeringsverdi FNR** | `99999999999` (niere) | `00000000000` (nuller) |
| **Maskeringsverdi HPR** | `999999999` (niere) | `0` (null) |

For dyreresepter maskeres flere felter (fødselsår, kjønn, kommune m.m.) — se splitterkoden i Meldingsmottak.

## Datoen 0001-01-01

Apotekene sender dato-minimum (`0001-01-01`) når de mangler en verdi. Splitteren normaliserer den ikke, så verdien går uendret nedstrøms. Hvordan Utleveringslager kontrollerer og flagger den (feltstatus og kontroller), står i repo-skillen `lmr-utleveringslager` (`references/apotekkilder.md` og `references/datamodell.md`).

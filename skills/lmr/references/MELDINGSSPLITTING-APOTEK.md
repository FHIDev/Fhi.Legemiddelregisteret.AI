# Meldingssplitting — apotek (Farmapro og Eik)

LMR har **ikke lov** til å lagre identitetsopplysninger (FNR, DNR, HPR-nummer) i samme database som utleveringsdata. Splitteren i Meldingsmottak er den eneste tjenesten som ser ekte identiteter — utleveringsmeldingen som sendes til Utleveringslager inneholder ingen.

Denne fila beskriver kontrakten nedstrøms tjenester ser. Implementasjonsdetaljer (splitterklasser, skjemaversjoner, maskeringslogikk) er dokumentert i repo-skillen `lmr-meldingsmottak` i Meldingsmottak-repoet og i splitterkoden der.

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

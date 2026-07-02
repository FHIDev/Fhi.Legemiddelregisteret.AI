# Meldingsflyt — apotek (utlevering)

LMR mottar meldinger om legemiddelutleveringer fra apotek via EIK-plattformen. Av personvernhensyn splittes innkommende meldinger i separate deler som lagres i ulike registre — identitetsopplysninger lagres aldri sammen med legemiddeldata.

## Flytdiagram

```
EIK Filedrop (filedrop.eikplatform.io)
  |
  | Meldingsformidler henter melding
  v
Meldingsmottak (splitter melding)
  |
  ├── Pasientmelding ──→ Pasientregister ──→ Pasientliste ──→ Utleveringslager
  ├── Rekvirentmelding ─→ Rekvirentregister → Rekvirentliste → Utleveringslager
  └── Utleveringsmelding (uten identiteter) ───────────────→ Utleveringslager
                                                                    |
                                                            Prosesseres når alle
                                                            tre er mottatt
```

Alle piler mellom tjenestene er Meldingsformidler som orkestrerer transporten.

## Trinnvis beskrivelse

| Trinn | Beskrivelse |
|---|---|
| 0 | EIK lagrer meldinger for apotekene i en Filedrop (`filedrop.eikplatform.io`) |
| 1 | Meldingsformidler henter melding fra Filedrop og leverer til Meldingsmottak |
| 2 | Meldingsmottak splitter melding i tre: Utleveringsmelding, Pasientmelding og Rekvirentmelding |
| 3 | Meldingsformidler sender Utleveringsmelding til Utleveringslager |
| 4 | Meldingsformidler sender Pasientmelding til Pasientregister |
| 5 | Meldingsformidler sender Rekvirentmelding til Rekvirentregister |
| 6 | Pasientregister lagrer pasientene og tilordner PasientId. Lager en Pasientliste som Meldingsformidler sender til Utleveringslager |
| 7 | Rekvirentregister lagrer rekvirentene og tilordner RekvirentId. Lager en Rekvirentliste som Meldingsformidler sender til Utleveringslager |
| 8 | Når Utleveringslager har mottatt Utleveringsmelding, Pasientliste og Rekvirentliste, prosesseres meldingen. Utleveringslager tilordner UtleveringsId og kobler data via PasientId og RekvirentId |

## Meldingsformater

| Kilde | Format | Splitting |
|---|---|---|
| **Farmapro** | XML | Reseptmelding → Pasientmelding, Rekvirentmelding, Utleveringsmelding |
| **Eik** | JSON | Reseptmelding → Pasientmelding, Rekvirentmelding, Utleveringsmelding. Farmasøytisk tjenestemelding → Pasientmelding, Tjenestemelding |

## Splitting

Se [MELDINGSSPLITTING-APOTEK.md](./MELDINGSSPLITTING-APOTEK.md) for kontrakten — hvilke delmeldinger som produseres, kobling mellom dem og maskeringsverdiene nedstrøms ser. Implementasjonsdetaljer: repo-skillen `lmr-meldingsmottak` i Meldingsmottak-repoet.

## Tjenester involvert

| Tjeneste | Rolle i apotekflyten |
|---|---|
| Meldingsformidler | Henter fra EIK Filedrop, orkestrerer all transport mellom tjenestene |
| Meldingsmottak | Mottar og splitter meldinger fra apotek |
| Pasientregister | Lagrer pasientidentiteter, tildeler PasientId, produserer Pasientliste |
| Rekvirentregister | Lagrer rekvirentidentiteter (leger), tildeler RekvirentId, produserer Rekvirentliste |
| Utleveringslager | Lagrer legemiddeldata om utleveringer — uten identiteter, kobler via PasientId/RekvirentId |

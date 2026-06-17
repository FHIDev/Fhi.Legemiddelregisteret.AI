# Domenemodell – lese og skrive

## Hva er en domenemodell her?

Domenemodeller er `.docx`-filer lagret på SharePoint under:

- **Site:** `https://folkehelse.sharepoint.com/sites/1221`
- **Sti:** `Delte dokumenter/7 - Gjennomføringsfase/02 - Løsningsbeskrivelse/Domenemodell/`

Filene beskriver databasetabeller for et domene. Hver tabell er representert som en 4-kolonne tabell i dokumentet:

| Rad | Innhold |
|-----|---------|
| 1 | Tabellnavn (flettede celler) |
| 2 | Tabellbeskrivelse (flettede celler) |
| 3 | Header: `Navn \| Type \| K \| Beskrivelse` |
| 4+ | En rad per kolonne i databasetabellen |

`K`-kolonnen angir nøkkeltype (f.eks. `1` = primærnøkkel).

## Finne filnavnet

Filnavnet til domenemodellen er **ikke** hardkodet her. Finn det i:
1. Repoets `CLAUDE.md` — se etter en linje som refererer til domenemodell-filen
2. En skill i repoet som inneholder filnavnet

Eksempel: `Domenemodell - Uttrekksdatabase.docx`

---

## Autentisering (gjør dette én gang per arbeidsøkt)

```bash
TOKEN=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv)
```

Brukeren er allerede innlogget i Azure CLI. Ikke spør om credentials.

---

## Hente domenemodellen fra SharePoint

```python
import requests, urllib.parse

SITE_HOST = "folkehelse.sharepoint.com"
SITE_PATH = "/sites/1221"
DOC_ROOT  = "7 - Gjennomføringsfase/02 - Løsningsbeskrivelse/Domenemodell"

# 1. Finn site-ID
site = requests.get(
    f"https://graph.microsoft.com/v1.0/sites/{SITE_HOST}:{SITE_PATH}",
    headers={"Authorization": f"Bearer {TOKEN}"}
).json()
site_id = site["id"]

# 2. Slå opp filen via sti (URL-enkod hele stien — viktig for ø/å)
file_path = f"{DOC_ROOT}/{filnavn}"  # filnavn fra CLAUDE.md/skill
encoded   = urllib.parse.quote(file_path)
item = requests.get(
    f"https://graph.microsoft.com/v1.0/sites/{site_id}/drive/root:/{encoded}",
    headers={"Authorization": f"Bearer {TOKEN}"}
).json()
item_id      = item["id"]
download_url = item["@microsoft.graph.downloadUrl"]

# 3. Last ned lokalt
with open("domenemodell_lokal.docx", "wb") as f:
    f.write(requests.get(download_url).content)
```

---

## Lese og tolke tabellene

```python
from docx import Document
from docx.table import Table

doc = Document("domenemodell_lokal.docx")

def parse_domenemodell(doc):
    """Returnerer dict: {tabellnavn: {beskrivelse, kolonner: [{navn, type, nokkel, beskrivelse}]}}"""
    tabeller = {}
    current_heading = ""
    
    for block in doc.element.body:
        tag = block.tag.split("}")[-1]
        if tag == "p":
            from docx.text.paragraph import Paragraph
            p = Paragraph(block, doc)
            if p.style.name.startswith("Heading"):
                current_heading = p.text.strip()
        elif tag == "tbl":
            tbl = Table(block, doc)
            rows = tbl.rows
            if len(rows) < 3:
                continue
            tabellnavn   = rows[0].cells[0].text.strip()
            tabbeskr     = rows[1].cells[0].text.strip()
            kolonner = []
            for row in rows[3:]:  # Hopp over header-raden (rad 3)
                celler = [c.text.strip() for c in row.cells]
                if len(celler) >= 4 and celler[0]:
                    kolonner.append({
                        "navn":      celler[0],
                        "type":      celler[1],
                        "nokkel":    celler[2],
                        "beskrivelse": celler[3]
                    })
            if tabellnavn:
                tabeller[tabellnavn] = {
                    "seksjon":    current_heading,
                    "beskrivelse": tabbeskr,
                    "kolonner":   kolonner
                }
    return tabeller
```

---

## Sammenligne med kode

Når du sammenligner domenemodellen med kildekode, se etter:

- **EF Core / Entity Framework:** klasser med `DbSet<>`, `[Table(...)]`, `[Column(...)]`
- **SQL-migreringsscript:** `CREATE TABLE`, `ALTER TABLE`
- **DTO-er / modeller:** klasser som matcher tabellnavn
- **CLAUDE.md / skills:** beskrivelser av entiteter og felter

### Hva utgjør et avvik?

| Type avvik | Eksempel |
|------------|---------|
| Tabell i kode, mangler i domenemodell | Ny EF-entitet uten tilhørende tabellbeskrivelse |
| Kolonne i kode, mangler i domenemodell | Nytt felt i entitet ikke dokumentert |
| Kolonne i domenemodell, fjernet fra kode | Utdatert rad i tabellen |
| Type-mismatch | `int` i kode, `Tekst` i domenemodell |
| Navn-mismatch | `CustomerId` vs `KundeId` |
| Beskrivelse mangler | Tom `Beskrivelse`-celle for felt som finnes i kode |

---

## Rapportere avvik

Presenter avvik strukturert. Grupper per tabell:

```
## Avvik: Domenemodell vs kode

### Tabell: Jobber
- ⚠️  Kolonne `RetryCount` finnes i kode (int), mangler i domenemodell
- ⚠️  Kolonne `ExternalRef` finnes i domenemodell, ikke i kode (slettet?)

### Tabell: JobbLogger
- ✅ Ingen avvik
```

Spør alltid brukeren hva som er kilden til sannhet:
- **Koden er riktig** → oppdater domenemodellen
- **Domenemodellen er riktig** → informer om at koden bør oppdateres
- **Begge er utdaterte** → avklar med brukeren

---

## Oppdatere og laste opp domenemodellen

Endre `.docx` lokalt med `python-docx` (`pip install python-docx` om nødvendig), og last deretter opp til **samme `item_id`** for å bevare versjonshistorikken:

```python
# Lagre endret dokument
doc.save("domenemodell_lokal.docx")

# Last opp (overskriv eksisterende — bevarer versjonshistorikk)
with open("domenemodell_lokal.docx", "rb") as f:
    resp = requests.put(
        f"https://graph.microsoft.com/v1.0/sites/{site_id}/drive/items/{item_id}/content",
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        },
        data=f
    )
resp.raise_for_status()

# Verifiser at item_id er uendret (ingen ny fil ble opprettet)
oppdatert = requests.get(
    f"https://graph.microsoft.com/v1.0/sites/{site_id}/drive/items/{item_id}",
    headers={"Authorization": f"Bearer {TOKEN}"}
).json()
assert oppdatert["id"] == item_id, "Advarsel: item_id har endret seg!"
```

---

## Rydd opp

Slett lokale filer etter at opplasting er bekreftet:

```python
import os
os.remove("domenemodell_lokal.docx")
```

---

## Typisk arbeidsflyt

1. **Finn filnavn** fra repoets `CLAUDE.md` eller skill
2. **Hent token** med `az account get-access-token`
3. **Last ned** `.docx` fra SharePoint
4. **Les tabellene** med `parse_domenemodell()`
5. **Sammenlign** med kode/CLAUDE.md
6. **Rapporter avvik** strukturert til brukeren
7. **Avklar** hva som er kilden til sannhet
8. **Oppdater** `.docx` om nødvendig og last opp
9. **Rydd opp** lokale filer

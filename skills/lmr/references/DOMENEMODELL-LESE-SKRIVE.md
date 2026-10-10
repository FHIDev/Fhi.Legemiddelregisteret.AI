# Domenemodell – lese og skrive

## Innhold

- Hva er en domenemodell her?
- Finne filnavnet
- Forutsetninger
- Arbeidsflyt (steg 1–6)
- Hva er kilden til sannhet?
- Hva utgjør et avvik?
- Rapportere avvik
- Når noe går galt

## Hva er en domenemodell her?

Domenemodeller er `.docx`-filer som eies av fagavdelingen og ligger på SharePoint:

- **Site:** `https://folkehelse.sharepoint.com/sites/1221`
- **Mappe:** `Delte dokumenter/7 - Gjennomføringsfase/02 - Løsningsbeskrivelse/Domenemodell/`

Filene beskriver databasetabellene for ett domene. Hver tabell er en tabell med fire kolonner i dokumentet:

| Rad | Innhold |
|-----|---------|
| 1 | Tabellnavn (flettede celler) |
| 2 | Tabellbeskrivelse (flettede celler) |
| 3 | Overskrift: `Navn \| Type \| K \| Beskrivelse` (noen tabeller bruker `Feltnavn` og `Kardinalitet`) |
| 4+ | Én rad per kolonne i databasetabellen |

`K` er **kardinalitet**: `1` = obligatorisk, `0..1` = valgfri, `0..*` = liste. Dokumentene beskriver ikke
fysiske nøkler eller indekser, så primærnøkler og indekser er ikke avvik i seg selv.

Gyldige verdier for en enum står ofte i en egen tabell inne i beskrivelsescellen, og beskrivelsescellen kan være
vertikalt flettet over flere rader. Tabellene har ikke egne overskrifter; de står under seksjonsoverskrifter
(f.eks. «Eik-tabeller») og skilles med tomme avsnitt.

## Finne filnavnet

Filnavnet er ikke hardkodet her. Det står i repoets `CLAUDE.md` eller repo-skill, for eksempel
`Domenemodell - Meldingsmottak.docx`.

## Forutsetninger

- PowerShell 7 og innlogget `az` CLI. Funksjonene henter Graph-token selv i hvert kall.
- Word på Windows for å verifisere før opplasting. Mangler Word, lastes ingenting opp.
- Funksjonene ligger i [scripts/Domenemodell.ps1](../scripts/Domenemodell.ps1). Variabler overlever ikke
  mellom kall i Claude Code, så skriptet dot-sources i hvert kall, og tilstanden mellom stegene (item-ID,
  eTag, hasher) ligger i `tilstand.json` i arbeidsmappen.

Graph-gotchas som skriptet håndterer:

- `GET .../content` (v1.0) svarer med 302 til SharePoints `download.aspx`, som avviser Azure CLI-tokenet
  («App is not allowed to call SPO with user_impersonation scope»). Skriptet laster ned med beta
  `.../contentStream`, som leverer innholdet direkte fra Graph.
- Stien URL-enkodes segment for segment, ellers feiler den på mellomrom og æ/ø/å.

## Arbeidsflyt

Steg 1 og 5 (`Get-`/`Publish-Domenemodell`) virker ikke mot SharePoint, se merknaden i steg 5. Alle eksemplene starter slik. `$skill` er katalogen Claude Code oppgir som «Base directory for this skill»
for lmr-skillen, og arbeidsmappen bør ligge i scratchpad:

```powershell
$skill = '<Base directory for this skill>'
$arbeid = '<scratchpad>/domenemodell-meldingsmottak'
. "$skill/scripts/Domenemodell.ps1"
```

### 1. Last ned

```powershell
Get-Domenemodell -Filnavn 'Domenemodell - Meldingsmottak.docx' -Arbeidsmappe $arbeid
```

Gir `original.docx` (skrivebeskyttet backup), `endret.docx` (arbeidskopi) og `tilstand.json` med item-ID,
`eTag` og `lastModifiedDateTime`. Metadata hentes før innholdet, slik at en samtidig endring alltid stopper
opplastingen i steg 5.

### 2. Les tabellene

```powershell
Get-DomenemodellTabeller -Sti "$arbeid/endret.docx" | ConvertTo-Json -Depth 6
```

Standardtabeller har `Kolonner` med `Navn`, `Type`, `Kardinalitet` og `Beskrivelse`. `HarUndertabell` og
`FlettetVertikalt` viser celler med gyldige verdier eller fletting. Andre tabeller (forside, versjonslogg,
enum-tabeller i annet format) har bare `Rader`.

### 3. Sammenlign med koden og bestem hva som skal endres

Se [Hva er kilden til sannhet?](#hva-er-kilden-til-sannhet) og [Hva utgjør et avvik?](#hva-utgjør-et-avvik).

### 4. Gjør endringene

Endringene gjøres bare i `word/document.xml`, med minimale endringer. Øvrige deler og rekkefølgen i pakken
beholdes. Hvert kall kontrollerer først at XML-en kan skrives tilbake uten andre forskjeller enn endringen.

```powershell
$e = "$arbeid/endret.docx"
Set-DomenemodellCelle -Sti $e -Tabell 'Avsendersystem' -Rad 'Versjon' -Kolonne K -Verdi '1'
Add-DomenemodellRad -Sti $e -Tabell 'Avsendersystem' -EtterRad 'Versjon' -Navn 'Kanal' -Type 'tekst' -K '0..1' -Beskrivelse ''
Remove-DomenemodellRad -Sti $e -Tabell 'Avsendersystem' -Rad 'Leverandor'
Add-DomenemodellTabell -Sti $e -EtterTabell 'Avsendersystem' -Navn 'Kanal' -Beskrivelse 'Kanaler meldingen kan komme fra' `
    -Kolonner @(@{ Navn = 'Id'; Type = 'heltall'; K = '1'; Beskrivelse = '' })
```

`-Kolonne` er `Navn`, `Type`, `K` eller `Beskrivelse`. Funksjonene stopper med en feilmelding i stedet for å
gjette når en celle har undertabell, er vertikalt flettet eller har tekst i flere avsnitt. Et avsnitt endres
bare hvis det kun har vanlige tekstløp med nøyaktig én tekstnode hver (hviteliste). Tabulator, linjeskift,
felt, lenker, sporede endringer og bokmerker i avsnittet gir stopp. Slike avvik listes i rapporten.
`Test-Domenemodell.ps1` (`pwsh -File skills/lmr/scripts/Test-Domenemodell.ps1`) tester dette på en syntetisk
.docx og skal kjøres etter endringer i `Domenemodell.ps1`.

`python-docx` kan brukes til å *lese* dokumentet, men aldri til å lagre det. `doc.save` reserialiserer hele
`document.xml`: prefiksene døpes om til `ns1..nsN` og ubrukte `xmlns:`-deklarasjoner droppes, mens
`mc:Ignorable` beholder de gamle prefiksene. XML-en er velformet, men Word nekter å åpne filen.

### 5. Verifiser i Word og last opp

```powershell
Test-DomenemodellIWord -Arbeidsmappe $arbeid
Publish-Domenemodell -Arbeidsmappe $arbeid
```

`Test-DomenemodellIWord` åpner original og endret kopi skrivebeskyttet i Word og viser avsnitt, tabeller og
sider for begge. En ødelagt fil gir «Filen ser ut til å være ødelagt». Sjekk at forskjellene stemmer med
endringene: én ny rad gir flere avsnitt, én ny tabell gir én tabell mer. Funksjonen avslutter bare en
Word-instans den selv startet. Velformet XML er ikke bevis på at filen åpner.

`Publish-Domenemodell` laster bare opp en fil som er verifisert i Word etter siste endring. Rett før
opplasting henter den eTag på nytt og stopper hvis den er endret siden nedlastingen. Graph-dokumentasjonen
for `PUT .../content` nevner ikke `If-Match`, så det er ikke sikkert at Graph svarer 412. Funksjonen laster
opp til samme item (versjonshistorikken beholdes) med `If-Match: <eTag fra nedlastingen>` i tillegg,
kontrollerer at item-ID er uendret, laster ned filen på nytt og sammenligner SHA-256 med den lokale filen.
HTTP 200 er ikke bevis på at riktig innhold er lagret.

> **Virker ikke mot SharePoint (testet 2026-10-09):** `Get-Domenemodell` og `Publish-Domenemodell` henter Graph-token med
> `az account get-access-token --resource https://graph.microsoft.com`. Tokenet tilhører appen Microsoft Azure CLI og har
> ikke `Files.*`- eller `Sites.*`-scopes (bare blant annet `User.Read.All`, `Group.ReadWrite.All` og
> `Directory.AccessAsUser.All`). Graph finner brukerens OneDrive-site, men lister 0 disker på den, og oppslag av
> drive gir `itemNotFound`. Nedlasting og opplasting fra SharePoint/OneDrive virker derfor ikke slik skriptet er skrevet.
> Oppslaget mot teamets site er ikke verifisert. `If-Match`/412 og tilbakelesing er heller ikke testet.
>
> **Agenter skal ikke forsøke `Get-Domenemodell` eller `Publish-Domenemodell`.** Arbeid med lokale filer (en kopi som
> en person har lagt i arbeidsmappen), gjør endringene og verifiser i Word, og lever den endrede filen til en person for
> manuell opplasting. Rapporter at opplastingen ikke er gjort. Endringsfunksjonene (`Set-`/`Add-`/`Remove-`
> `Domenemodell*`) og `Test-DomenemodellIWord` bruker ikke Graph og er upåvirket. Valg av ny innlogging er ikke gjort;
> se work item for innlogging med Files/Sites-tilgang.

### 6. Rapporter

Rapporter avvikene og hva som ble gjort med hvert av dem (se under). Behold arbeidsmappen til rapporten er
skrevet; `original.docx` er backupen.

## Hva er kilden til sannhet?

**Interaktiv bruk:** vis avvikene og spør brukeren for hvert avvik om koden eller dokumentet er riktig, eller
om begge er utdatert.

**Selvstendig kjøring** (for eksempel når en agent løser en user story uten bruker tilgjengelig):

- For struktur – tabeller, kolonner, datatyper, kardinalitet, relasjoner og enum-verdier – er koden fasit,
  og dokumentet oppdateres. To unntak listes i stedet:
  - Kolonner og tabeller som står i dokumentet, men mangler i koden. Det kan være feil i koden, og
    radfjerning sletter eksisterende faglig beskrivelse.
  - Enum-verdier. De står i undertabeller i beskrivelsescellen eller i egne tabeller med et annet format
    (`Id | Navn | Beskrivelse`), og skriptet endrer bare tabeller i standardformatet.
- Tomme beskrivelser kan fylles ut med det som kan utledes sikkert fra koden.
- Eksisterende faglige beskrivelser og domenelogikk skrives ikke om. Motsigelser mellom dem og koden listes.
- Avvik som kan tyde på feil i koden (for eksempel en regel i dokumentet som koden ikke følger) rettes ikke,
  verken i koden eller i dokumentet. De listes.
- `Remove-DomenemodellRad` brukes bare ved interaktiv bruk, når brukeren har bekreftet at raden skal bort.
- Alle avvik og hva som ble gjort med hvert av dem, rapporteres i PR-beskrivelsen og som kommentar på
  storyen. Fag gjennomgår endringene i dokumentet etterpå.

## Hva utgjør et avvik?

Se etter EF Core-entiteter og -konfigurasjon (`DbSet<>`, `[Table]`, `[Column]`, `HasMaxLength`, `IsRequired`),
migreringer og SQL-skript (`CREATE TABLE`, `ALTER TABLE`) og enumer som lagres i databasen.

| Type avvik | Eksempel | Selvstendig kjøring |
|------------|----------|---------------------|
| Tabell i kode, mangler i dokumentet | Ny EF-entitet | Legg til tabell |
| Kolonne i kode, mangler i dokumentet | Nytt felt i entitet | Legg til rad |
| Kolonne eller tabell i dokumentet, mangler i kode | Utdatert rad, eller kolonne koden burde hatt | List, ikke fjern |
| Type-avvik | `int` i kode, `tekst` i dokumentet | Rett typen |
| Kardinalitet-avvik | Påkrevd i kode (`IsRequired`, ikke-nullbar), `0..1` i dokumentet | Rett `K` |
| Navneavvik | `CustomerId` i kode, `KundeId` i dokumentet | Rett navnet |
| Enum-verdi mangler eller er utdatert | Ny verdi i enum som lagres | List |
| Beskrivelse mangler | Tom `Beskrivelse`-celle | Fyll ut hvis det kan utledes sikkert, ellers list |
| Beskrivelse motsier koden | Regel i dokumentet koden ikke følger | List, ikke endre |

## Rapportere avvik

Grupper per tabell og si hva som ble gjort med hvert avvik:

```
## Avvik: Domenemodell vs kode

### Tabell: Avsendersystem
- Kolonne `Kanal` finnes i kode (string?), manglet i dokumentet – lagt til med K 0..1
- `Versjon` er påkrevd i kode, K var 0..1 – rettet til 1
- Beskrivelsen av `Navn` sier maks 100 tegn, koden har HasMaxLength(50) – listet, ikke endret

### Tabell: EikMelding
- Ingen avvik
```

## Når noe går galt

- **HTTP 412 eller endret eTag** ved opplasting: dokumentet er endret av andre siden det ble hentet. Ikke last opp. Rapporter det.
  Skal endringen likevel gjøres, starter du på nytt fra steg 1 i en ny arbeidsmappe.
- **HTTP 423**: dokumentet er låst (åpent for redigering eller sjekket ut). Ikke last opp. Rapporter det.
- **Word mangler eller kan ikke åpne filen:** ikke last opp. Rapporter at verifiseringen ikke kunne gjøres
  eller feilet.
- **«document.xml kan ikke skrives tilbake uten utilsiktede endringer»:** dokumentet inneholder XML som ikke
  kan skrives tilbake identisk. Ikke endre dokumentet; list avvikene.
- **Tilbakelest fil har annen hash:** rapporter det. Meldingen sier om `word/document.xml` er lik; SharePoint kan
  skrive biblioteksmetadata inn i `docProps`/`customXml` ved opplasting.
- **En fil Word ikke vil åpne etter en manuell XML-endring:** sjekk at alle prefikser i `mc:Ignorable` og i
  dokumentet er deklarert med `xmlns:` på rotelementet. Legg manglende deklarasjoner tilbake; riktige URI-er
  finnes i `word/settings.xml` eller `word/header1.xml` i samme fil.
- `[trash]/*.dat` i pakken er et OneDrive/SharePoint-artefakt og finnes også i friske dokumenter. Ikke fjern dem.

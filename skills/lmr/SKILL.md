---
name: lmr
description: Legemiddelregisteret (LMR) system knowledge; use when asked about LMR repositories, services, ownership, cloning LMR repos, message flows, Meldingsformidler architecture, health checks, or integrations.
---

# Legemiddelregisteret (LMR)

## Scope

- Svar på spørsmål om LMR-systemet og hvilke repoer som inngår.
- Peker til riktig repo basert på navn eller ansvarsområde.
- Ved kloning, bruk git clone med riktig URL og be om målmappe om den ikke er oppgitt.
- Forklar meldingsflyter, arkitektur og integrasjoner i LMR.

## Related Documentation

Tverrgående dokumentasjon (gjelder på tvers av mikrotjenestene):
- Meldingsflyt — Meldinger fra apotek (legemiddelutleveringer): [MELDINGSFLYT-APOTEK.md](./references/MELDINGSFLYT-APOTEK.md)
- Meldingsflyt — Meldinger fra Bærum kommune (administrering av legemidler i institusjoner i Bærum kommune): [MELDINGSFLYT-BAERUM.md](./references/MELDINGSFLYT-BAERUM.md)
- Meldingsflyt — Meldinger fra institusjoner: [MELDINGSFLYT-INSTITUSJON-FHIR.md](./references/MELDINGSFLYT-INSTITUSJON-FHIR.md)
- Meldingssplitting — Meldinger fra apotek (legemiddelutleveringer): [MELDINGSSPLITTING-APOTEK.md](./references/MELDINGSSPLITTING-APOTEK.md)
- Meldingssplitting — Meldinger fra Bærum kommune, CSV: [MELDINGSSPLITTING-BAERUM.md](./references/MELDINGSSPLITTING-BAERUM.md)
- Meldingssplitting — Meldinger fra institusjoner, FHIR: [MELDINGSSPLITTING-INSTITUSJON-FHIR.md](./references/MELDINGSSPLITTING-INSTITUSJON-FHIR.md)
- Meldingskontrakter — institusjonsflyt (splitting → Administreringslager): [MELDINGSKONTRAKTER-INSTITUSJON.md](./references/MELDINGSKONTRAKTER-INSTITUSJON.md)
- Hendelser, varsler og handlinger (kildetjenester → Varseltjeneste → Kontroll): [HENDELSER-VARSLER.md](./references/HENDELSER-VARSLER.md)
- Feltkryptering og nøkkelhåndtering: [FELTKRYPTERING.md](./references/FELTKRYPTERING.md)
- Kodeverksynkronisering mot Grunndata: [KODEVERKSYNKRONISERING.md](./references/KODEVERKSYNKRONISERING.md)
- Helsesjekker, systemstatus og monitoring i Kontroll: [SYSTEMSTATUS.md](./references/SYSTEMSTATUS.md)
- Meldingsformidler AzureFilestore-slot (testmiljø-bro mot Azure Files): [MELDINGSFORMIDLER-AZUREFILESTORE.md](./references/MELDINGSFORMIDLER-AZUREFILESTORE.md)

Teknisk veiledning (last inn ved behov for den aktuelle oppgaven):
- Autentisering — bruk av Fhi.Lmr.Authentication-pakkene (TokenValidation og ClientCredentials): konfigurasjon, IDP-er (HelseId, Entra ID, Maskinporten), DPoP, UseAuth-sperre og feilsøking. Bruk ved oppsett/endring av autentisering eller feilsøking av 401/403: [LMR-AUTHENTICATION.md](./references/LMR-AUTHENTICATION.md)
- Oppgradering til .NET 10 — migrer en tjeneste fra .NET 8, bytt gamle autentiseringspakker (Fhi.ClientCredentialsKeypairs, Fhi.HelseId.Api) til Fhi.Lmr.Authentication, og oppdater pipeline-filer. Bruk ved .NET 10-oppgradering: [OPPDATER-NET-10.md](./references/OPPDATER-NET-10.md)
- Domenemodell — lese/skrive domenemodeller (.docx) på SharePoint via Microsoft Graph, sammenligne med kode og rapportere avvik. Bruk når brukeren nevner «domenemodell», vil sjekke om dokumentasjonen stemmer med koden, eller vil oppdatere modellen: [DOMENEMODELL-LESE-SKRIVE.md](./references/DOMENEMODELL-LESE-SKRIVE.md)

Repo-spesifikk dokumentasjon (finnes i de enkelte repoene):
- Meldingsformidler: `Fhi.Lmr.Meldingsformidler/.claude/skills/lmr-meldingsformidler/SKILL.md`
- Administreringslager: `Fhi.Lmr.Administreringslager/.claude/skills/lmr-administreringslager/skill.md`

Ekstern dokumentasjon:
- LMDI — FHIR R4 implementasjonsguide for de som sender data til FhirMottak: https://github.com/folkehelseinstituttet/LMDI

## Wiki

Legemiddelregisterets wiki inneholder prosjektdokumentasjon, prosesser og retningslinjer.

Repository: https://fhi.visualstudio.com/Fhi.Legemiddelregisteret/_git/Fhi.Legemiddelregisteret.wiki

## Arkitekturoversikt

LMR er en mikrotjenestearkitektur som mottar meldinger om legemiddelutleveringer fra apotek og legemiddeladministreringer fra institusjoner. Av personvernhensyn har LMR **ikke lov** til å lagre identitetsopplysninger sammen med legemiddeldata. Innkommende meldinger splittes i separate deler som lagres i ulike registre.

Se [MELDINGSFLYT-APOTEK.md](./references/MELDINGSFLYT-APOTEK.md), [MELDINGSFLYT-BAERUM.md](./references/MELDINGSFLYT-BAERUM.md) og [MELDINGSFLYT-INSTITUSJON-FHIR.md](./references/MELDINGSFLYT-INSTITUSJON-FHIR.md) for detaljerte flytdiagrammer.

## Repositories

Alle repos: `https://fhi.visualstudio.com/DefaultCollection/Fhi.Legemiddelregisteret/_git/<repo>`

### Fhi.Lmr.Meldingsmottak

Ansvar: Mottak og splitting av meldinger fra apotek og institusjoner.

- Mottar Farmapro-meldinger (XML) og Eik-meldinger (JSON)
- Splitter reseptmeldinger i 3 deler: pasientmelding, rekvirentmelding, utleveringsmelding
- Splitter Eik farmasøytiske tjenestemeldinger i 2 deler: pasientmelding, tjenestemelding
- Mottar også lokalvaremeldinger (informasjon om apoteks lokalvarer)

### Fhi.Lmr.Meldingsformidler

Ansvar: Transport- og orkestreringstjeneste for meldinger mellom LMR sine tjenester og eksterne systemer.

Se repo-skillen `lmr-meldingsformidler` for fullstendig dokumentasjon av flyter, klienter, helsesjekker og integrasjoner.

### Fhi.Lmr.FhirMottak

Ansvar: Motta FHIR Bundle-meldinger fra institusjoner (sykehus/sykehjem) og videresende til Meldingsformidler.

- Inngangspunktet for administreringsdata fra institusjoner
- Mottar HL7 FHIR R4 Bundles via API
- Videresender til Meldingsformidler for splitting og distribusjon

### Fhi.Lmr.Pasientregister

Ansvar: Lagre og vedlikeholde informasjon om pasienter.

- Har informasjon om identiteten til pasientene
- En pasient kan ha flere identiteter, registeret kobler en pasientid til flere identiteter
- Behandler en Pasientmelding og lagrer informasjon om pasientene
- Genererer en pasientliste som overføres til Utleveringslageret (av Meldingsformidler)

### Fhi.Lmr.Rekvirentregister

Ansvar: Lagre og vedlikeholde informasjon om rekvirenter (leger).

- Har informasjon om identiteten til rekvirenten
- Behandler en Rekvirentmelding og lagrer informasjon om rekvirentene
- Genererer en rekvirentliste som overføres til Utleveringslageret (av Meldingsformidler)

### Fhi.Lmr.Utleveringslager

Ansvar: Lagre og behandle opplysninger om legemiddelutleveringer fra apotek.

- Lager for alle utleveringene til pasienter
- Har ikke pasient- og rekvirent-identiteter, men kobler data via pasientid og rekvirentid
- Prosesserer en utleveringsmelding sammen med en pasientliste og en rekvirentliste

### Fhi.Lmr.Administreringslager

Ansvar: Lagre og behandle opplysninger om legemiddeladministreringer fra institusjoner (sykehus/sykehjem).

- Parallell til Utleveringslager, men for institusjonsdata i stedet for apotekdata
- Mottar FHIR Bundles med MedicationAdministration-ressurser
- Kobler data via anonyme pasientid-er og rekvirentid-er (ingen identiteter)
- Bakgrunnstjeneste prosesserer meldinger med retry-logikk
- Støtter også CSV-data fra Bærum kommune (pilot)

Se repo-skillen `lmr-administreringslager` for fullstendig domenekunnskap.

### Fhi.Lmr.Grunndata

Ansvar: Grunnlagsdata i LMR — vedlikeholder kodeverk synkronisert fra FHI-kodeverk.

Se [KODEVERKSYNKRONISERING.md](./references/KODEVERKSYNKRONISERING.md) for detaljer om synkroniseringsmekanismen.

### Fhi.Lmr.Kontroll

Ansvar: Frontend/administrasjonsløsning for Legemiddelregisteret, brukt av både fag og utviklere.
Alias: Kontroll-siden

- Se rapporter og rapporteringsoversikt fra Eik
- Bestille retransmittering fra Farmapro
- Se status på behandlingen av meldinger
- Se resultat av helsesjekker

### Fhi.Lmr.Logging

Ansvar: Lagre logg fra alle LMR-tjenester.

### Fhi.Lmr.Varseltjeneste

Ansvar: Samle inn hendelser fra andre tjenester og håndtere varsler.

Poller kildetjenestene for hendelser, grupperer dem til varsler og utfører handlinger (f.eks. reprosessering) på vegne av Kontroll-siden. Se [HENDELSER-VARSLER.md](./references/HENDELSER-VARSLER.md).

### Fhi.Lmr.Tilganger

Ansvar: Tilgangsstyring — holder oversikt over hvilke brukere som skal ha tilgang til løsningen, integrert med HelseId.

### Fhi.Lmr.Individdatauttrekk

Ansvar: Uttrekk av individdata fra LMR. Mottar forespørsler via Ratatosk-meldingsbussen og produserer krypterte filuttrekk (CSV med RSA-signatur).

### Fhi.Lmr.Innbyggertjenester

Ansvar: Tjenester rettet mot innbyggere.

### Fhi.Lmr.InternStatistikk

Ansvar: Intern statistikk og rapportering for LMR.

### Fhi.Lmr.Dataprodukter

Ansvar: Dataprodukter fra LMR.

### Fhi.Lmr.Uttrekksdatabase

Ansvar: Database for uttrekk av data fra LMR.

### Fhi.Lmr.Apoteksimulator

Ansvar: Simulerer apotek for test og utvikling. Sender meldinger til LMR som om de kom fra et ekte apotek.

### Fhi.Lmr.Institusjonsimulator

Ansvar: Simulerer institusjoner (sykehus/sykehjem) for test og utvikling.

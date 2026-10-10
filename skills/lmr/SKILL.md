---
name: lmr
description: Tverrgående kunnskap om Legemiddelregisteret (LMR). Dekker hvilke repoer og tjenester som finnes og hvor repo-skillene ligger, meldingsflyt og meldingssplitting for apotek (Eik, Farmapro) og institusjoner (FHIR, Bærum-CSV), meldingskontrakter, hendelser og varsler, kodeverksynkronisering mot Grunndata, feltkryptering, helsesjekker og systemstatus i Kontroll, autentisering med Fhi.Lmr.Authentication (Entra ID, HelseId, Maskinporten, 401/403, DefaultScope), oppgradering til .NET 10, domenemodell-dokumenter på SharePoint og gjennomgang av agentoppsettet (CLAUDE.md og repo-skiller). Brukes ved spørsmål om hvordan tjenestene henger sammen, kloning av LMR-repoer og oppgaver som berører flere tjenester. Kunnskap om én tjeneste ligger i repo-skillen lmr-<tjeneste>.
---

# Legemiddelregisteret (LMR)

## Scope

- Svar på spørsmål om LMR-systemet og hvilke repoer som inngår.
- Peker til riktig repo og repo-skill basert på navn eller ansvarsområde.
- Ved kloning, bruk git clone med riktig URL og be om målmappe om den ikke er oppgitt.
- Forklar meldingsflyter og kunnskap som gjelder flere tjenester: kontrakter mellom dem, felles pakker, autentisering og domenemodell-prosessen.

## Hvor kunnskapen hører hjemme

- **Denne skillen:** det som gjelder flere tjenester (flyt mellom tjenestene, meldingskontrakter, felles pakker, autentisering, domenemodell-prosedyren).
- **Repo-skillen** (`lmr-<navn>` i hvert repo): regler, gotchas og begrunnelser som gjelder én tjeneste. Arkitektur, bygg og miljøer står i repoets `CLAUDE.md`.
- Gjentas noe fra en repo-skill her, eller omvendt, skal det erstattes med en peker. Kontrakten mellom to tjenester eies av denne skillen.

## Related Documentation

Tverrgående dokumentasjon (gjelder på tvers av mikrotjenestene):
- Meldingsflyt — Meldinger fra apotek (legemiddelutleveringer). Les for flyten fra Eik til Utleveringslager: [MELDINGSFLYT-APOTEK.md](./references/MELDINGSFLYT-APOTEK.md)
- Meldingsflyt — Meldinger fra Bærum kommune (administrering av legemidler i institusjoner i Bærum kommune). Les for CSV-flyten: [MELDINGSFLYT-BAERUM.md](./references/MELDINGSFLYT-BAERUM.md)
- Meldingsflyt — Meldinger fra institusjoner. Les for FHIR-flyten fra FhirMottak til Administreringslager og for feilsøking med SQL: [MELDINGSFLYT-INSTITUSJON-FHIR.md](./references/MELDINGSFLYT-INSTITUSJON-FHIR.md)
- Meldingssplitting — Meldinger fra apotek (legemiddelutleveringer). Les for delmeldinger, koblingsnøkler og maskeringsverdier: [MELDINGSSPLITTING-APOTEK.md](./references/MELDINGSSPLITTING-APOTEK.md)
- Meldingssplitting — Meldinger fra Bærum kommune, CSV. Les for kontrakten for CSV-flyten: [MELDINGSSPLITTING-BAERUM.md](./references/MELDINGSSPLITTING-BAERUM.md)
- Meldingssplitting — Meldinger fra institusjoner, FHIR. Les for kontrakten og begrensningene avsendere må kjenne: [MELDINGSSPLITTING-INSTITUSJON-FHIR.md](./references/MELDINGSSPLITTING-INSTITUSJON-FHIR.md)
- Meldingskontrakter — institusjonsflyt (splitting → Administreringslager). Les for meldingstypene mellom Meldingsmottak, registrene og Administreringslager: [MELDINGSKONTRAKTER-INSTITUSJON.md](./references/MELDINGSKONTRAKTER-INSTITUSJON.md)
- Hendelser, varsler og handlinger (kildetjenester → Varseltjeneste → Kontroll). Les når en ny kilde eller varseltype skal inn, eller et varsel ikke dukker opp: [HENDELSER-VARSLER.md](./references/HENDELSER-VARSLER.md)
- Feltkryptering og nøkkelhåndtering. Les for `Fhi.Lmr.Felles.Kryptering`, at krypteringen er deterministisk og hva et nøkkelbytte betyr: [FELTKRYPTERING.md](./references/FELTKRYPTERING.md)
- Kodeverksynkronisering mot Grunndata. Les for pakken `TilgangKodeverk`, OID-konfigurasjon og feilsøking av kodeverkkontroll: [KODEVERKSYNKRONISERING.md](./references/KODEVERKSYNKRONISERING.md)
- Helsesjekker og systemstatus (mønsteret i tjenestene og koblingen til Kontroll). Les når en tjeneste skal inn i systemstatus-oversikten: [SYSTEMSTATUS.md](./references/SYSTEMSTATUS.md)
- Meldingsformidler AzureFilestore-slot (testmiljø-bro mot Azure Files). Les når meldinger skal legges inn via Azure Files i et testmiljø: [MELDINGSFORMIDLER-AZUREFILESTORE.md](./references/MELDINGSFORMIDLER-AZUREFILESTORE.md)

Teknisk veiledning (last inn ved behov for den aktuelle oppgaven):
- Autentisering — bruk av Fhi.Lmr.Authentication-pakkene (TokenValidation og ClientCredentials): IDP-kart for LMR, konfigurasjon, scopes og roller, `[Authorize]`-fella med `DefaultScope`, DPoP, UseAuth-sperre og feilsøking. Bruk ved oppsett/endring av autentisering eller feilsøking av 401/403: [LMR-AUTHENTICATION.md](./references/LMR-AUTHENTICATION.md)
- Oppgradering til .NET 10 — migrer en tjeneste fra .NET 8, bytt gamle autentiseringspakker (Fhi.ClientCredentialsKeypairs, Fhi.HelseId.Api) til Fhi.Lmr.Authentication, og oppdater pipeline-filer. Bruk ved .NET 10-oppgradering: [OPPDATER-NET-10.md](./references/OPPDATER-NET-10.md)
- Domenemodell — lese/skrive domenemodeller (.docx) på SharePoint via Microsoft Graph, sammenligne med kode, rapportere avvik og oppdatere dokumentet uten å ødelegge det eller overskrive andres endringer (funksjoner i [scripts/Domenemodell.ps1](./scripts/Domenemodell.ps1)). Har regler for hva som er kilden til sannhet ved selvstendig kjøring. Bruk når brukeren nevner «domenemodell», vil sjekke om dokumentasjonen stemmer med koden, eller vil oppdatere modellen: [DOMENEMODELL-LESE-SKRIVE.md](./references/DOMENEMODELL-LESE-SKRIVE.md)

Repo-spesifikk dokumentasjon (finnes i de enkelte repoene, `<repo>/.claude/skills/<skill>/SKILL.md`):
- Administreringslager: `Fhi.Lmr.Administreringslager/.claude/skills/lmr-administreringslager/SKILL.md`
- Dataprodukter: `Fhi.Lmr.Dataprodukter/.claude/skills/lmr-dataprodukter/SKILL.md`
- DataproduktFormidler: `Fhi.Lmr.DataproduktFormidler/.claude/skills/lmr-dataproduktformidler/SKILL.md`
- FhirMottak: `Fhi.Lmr.FhirMottak/.claude/skills/lmr-fhirmottak/SKILL.md`
- Grunndata: `Fhi.Lmr.Grunndata/.claude/skills/lmr-grunndata/SKILL.md`
- Individdatauttrekk: `Fhi.Lmr.Individdatauttrekk/.claude/skills/lmr-individdatauttrekk/SKILL.md`
- Innbyggertjenester: `Fhi.Lmr.Innbyggertjenester/.claude/skills/lmr-innbyggertjenester/SKILL.md`
- InternStatistikk: `Fhi.Lmr.InternStatistikk/.claude/skills/lmr-internstatistikk/SKILL.md`
- Kontroll: `Fhi.Lmr.Kontroll/.claude/skills/lmr-kontroll/SKILL.md`
- Krl.Admin: `Fhi.Lmr.Krl.Admin/.claude/skills/lmr-krladmin/SKILL.md`
- Logging: `Fhi.Lmr.Logging/.claude/skills/lmr-logging/SKILL.md`
- Meldingsformidler: `Fhi.Lmr.Meldingsformidler/.claude/skills/lmr-meldingsformidler/SKILL.md`
- Meldingsmottak: `Fhi.Lmr.Meldingsmottak/.claude/skills/lmr-meldingsmottak/SKILL.md`
- Pasientregister: `Fhi.Lmr.Pasientregister/.claude/skills/lmr-pasientregister/SKILL.md`
- Rak: `Fhi.Lmr.Rak/.claude/skills/lmr-rak/SKILL.md`
- Rekvirentregister: `Fhi.Lmr.Rekvirentregister/.claude/skills/lmr-rekvirentregister/SKILL.md`
- Tilganger: `Fhi.Lmr.Tilganger/.claude/skills/lmr-tilganger/SKILL.md`
- Utleveringslager: `Fhi.Lmr.Utleveringslager/.claude/skills/lmr-utleveringslager/SKILL.md`
- Uttrekksdatabase: `Fhi.Lmr.Uttrekksdatabase/.claude/skills/lmr-uttrekksdatabase/SKILL.md`, og `Fhi.Lmr.Uttrekksdatabase/.claude/skills/leggtil-variabler/SKILL.md` for nye variabler i uttrekkstabellene
- Varseltjeneste: `Fhi.Lmr.Varseltjeneste/.claude/skills/lmr-varseltjeneste/SKILL.md`

Søsterskiller i samme plugin:
- `lmr-entraid` — app-registreringer, sertifikater og admin consent i Entra ID, med Bicep. Bruk ved nye m2m-kanter, brukerinnlogging eller tomt `roles`-claim.
- `lmdi-fhir` — implementasjonsguiden for LMDI (profiler, bundle-struktur, validering, signert og kryptert innsending til FhirMottak). Bruk ved spørsmål om hva en FHIR-bundle fra en institusjon skal inneholde.

## Agentoppsett i repoene

Hvert tjeneste-repo har `CLAUDE.md` og en repo-skill under `.claude/skills/lmr-<navn>/`. Regelen
om å oppdatere dem i samme commit som koden fanger ikke endringer som går på tvers av repoene.
Kommandoen `/lmr:gjennomga-agentoppsett` kontrollerer agentfilene i ett repo mot koden og endrer
ingen filer. Les [gjennomga-agentoppsett.md](../../commands/gjennomga-agentoppsett.md) når du
skal kjøre gjennomgangen eller svare på hva den kontrollerer, hvordan rapporten ser ut og hva den
ikke gjør. Kjør den:

- etter tverrgående endringer som berører flere tjenester, for eksempel ny autentisering,
  .NET-oppgradering eller endrede meldingskontrakter, i hvert berørte repo
- minst én gang per kvartal per repo
- før et repo tas i bruk av nye utviklere eller agenter

Veiledninger for tverrgående endringer i denne skillen (som
[OPPDATER-NET-10.md](./references/OPPDATER-NET-10.md) og
[LMR-AUTHENTICATION.md](./references/LMR-AUTHENTICATION.md)) skal ha som siste steg: oppdater
`CLAUDE.md` og repo-skillen i hvert berørte repo, og kjør `/lmr:gjennomga-agentoppsett`. Nye
veiledninger av samme type skal ha det samme steget.

## Wiki

Legemiddelregisterets wiki inneholder prosjektdokumentasjon, prosesser og retningslinjer.

Repository: https://fhi.visualstudio.com/Fhi.Legemiddelregisteret/_git/Fhi.Legemiddelregisteret.wiki

## Arkitekturoversikt

LMR er en mikrotjenestearkitektur som mottar meldinger om legemiddelutleveringer fra apotek og legemiddeladministreringer fra institusjoner. Av personvernhensyn har LMR **ikke lov** til å lagre identitetsopplysninger sammen med legemiddeldata. Innkommende meldinger splittes i separate deler av Meldingsmottak, og delene lagres i ulike registre.

Se [MELDINGSFLYT-APOTEK.md](./references/MELDINGSFLYT-APOTEK.md), [MELDINGSFLYT-BAERUM.md](./references/MELDINGSFLYT-BAERUM.md) og [MELDINGSFLYT-INSTITUSJON-FHIR.md](./references/MELDINGSFLYT-INSTITUSJON-FHIR.md) for detaljerte flytdiagrammer.

Kort om rollene i flyten:

- **Meldingsformidler** flytter alt mellom tjenestene: den henter fra Eik og fra FhirMottak, leverer til Meldingsmottak, sender meldingsdelene videre og synkroniserer status. Den splitter ikke.
- **Meldingsmottak** splitter. Det er eneste sted som ser identitet og legemiddeldata samtidig.
- **Pasientregister og Rekvirentregister** kjenner identitetene og leverer lister med PasientId og RekvirentId til lagrene (Utleveringslager og Administreringslager).
- **FhirMottak** er inngangen for institusjoner og sender ikke videre selv: Meldingsformidler henter fra det.

Hvilke bakgrunnstjenester i Meldingsformidler som kjører, styres per miljø i appsettings. En flyt som er beskrevet her, kan derfor være avslått i et miljø.

## Repositories

Alle repos: `https://fhi.visualstudio.com/DefaultCollection/Fhi.Legemiddelregisteret/_git/<repo>`

Hver tjeneste under har en repo-skill (se «Repo-spesifikk dokumentasjon») med domenekunnskap, og en `CLAUDE.md` med arkitektur og bygg.

### Tverrgående repoer

#### Fhi.Lmr.Felles

Felles NuGet-pakker som tjenestene bruker, blant annet `Fhi.Lmr.Felles.Meldinger` (meldingskontraktene), `Fhi.Lmr.Felles.Kryptering` (se [FELTKRYPTERING.md](./references/FELTKRYPTERING.md)), `Fhi.Lmr.Felles.TilgangKodeverk` (se [KODEVERKSYNKRONISERING.md](./references/KODEVERKSYNKRONISERING.md)), `Fhi.Lmr.Felles.Status` (se [SYSTEMSTATUS.md](./references/SYSTEMSTATUS.md)), og pakker for Eik, Farmapro, Ratatosk og bakgrunnsjobber. Alle pakkene versjoneres med én felles GitVersion.

#### Fhi.Lmr.Authentication

NuGet-pakkene `Fhi.Lmr.Authentication.TokenValidation` og `Fhi.Lmr.Authentication.ClientCredentials`. Se [LMR-AUTHENTICATION.md](./references/LMR-AUTHENTICATION.md).

#### Fhi.Lmr.DevOps

Pipeline-maler (`templates/`) som tjenestenes CI- og publish-pipelines bruker via ressursen `FhiLmrDevOps`, og skript og Bicep for testmiljøer. Agentfil-sjekken (`templates/agentfiler-sjekk.yaml` og `script/powershell/Test-Agentfiler.ps1`) kontrollerer `CLAUDE.md` og repo-skillene i PR-validering.

#### Fhi.Lmr.Docker

Docker Compose-oppsett for å kjøre LMR-tjenestene sammen, og Bicep og pipelines for Azure-testmiljøer.

### Tjenester

#### Fhi.Lmr.Administreringslager

Ansvar: Lagre og behandle opplysninger om legemiddeladministreringer fra institusjoner (sykehus/sykehjem).

- Parallell til Utleveringslager, men for institusjonsdata i stedet for apotekdata
- Mottar FHIR Bundles med MedicationAdministration-ressurser
- Kobler data via anonyme pasientid-er og rekvirentid-er (ingen identiteter)
- Bakgrunnstjeneste prosesserer meldinger med retry-logikk
- Støtter også CSV-data fra Bærum kommune (pilot)

Se repo-skillen `lmr-administreringslager`.

#### Fhi.Lmr.Apoteksimulator

Ansvar: Simulerer apotek for test og utvikling. Sender meldinger til LMR som om de kom fra et ekte apotek.

#### Fhi.Lmr.Dataprodukter

Ansvar: Lage og levere dataprodukter fra LMR til mottakere: krypterte filer til Sikker Sone via Ratatosk, API-leveranser og databaseleveranse.

Se repo-skillen `lmr-dataprodukter`.

#### Fhi.Lmr.FhirMottak

Ansvar: Motta signerte og krypterte meldinger fra institusjoner (sykehus/sykehjem): FHIR Bundles etter LMDI-profilen, og CSV fra Bærum kommune.

- Inngangspunktet for administreringsdata fra institusjoner (Maskinporten)
- Validerer og lagrer meldingen kryptert. Splitter ikke og sender ikke videre selv
- Eksponerer `/institusjonsmeldinger/allokerneste` og `/institusjonsmeldinger/merksomoverfort`, og Meldingsformidler henter meldingene derfra og leverer dem til Meldingsmottak, som splitter dem
- Bærum-CSV mottas på `POST /fhirmottak/barumKommune`

Se repo-skillen `lmr-fhirmottak`, og `lmdi-fhir` for innholdet i meldingene.

#### Fhi.Lmr.Grunndata

Ansvar: Grunnlagsdata i LMR. Henter referansedata fra eksterne kilder, lagrer dem med historikk og gir dem til de andre tjenestene og Kontroll.

- Kodeverk synkronisert fra FHI-kodeverk (se [KODEVERKSYNKRONISERING.md](./references/KODEVERKSYNKRONISERING.md))
- Apotekregister, vareregister (FEST) med ATC/DDD-endringer, og kommuner, geografi og befolkning
- Sertifikatregister fra Adresseregisteret og Reseptregister-historikk
- Vareregisteret sender hendelser til Varseltjenesten

Se repo-skillen `lmr-grunndata`.

#### Fhi.Lmr.Individdatauttrekk

Ansvar: Uttrekk av individdata fra LMR. Fagbrukere styrer tjenesten fra Kontroll (REST). Den leser fra Uttrekksdatabasen og lager passordbeskyttede zip-filer (AES-256) som krypteres med Ratatosk-krypteringen (RSA-OAEP for AES-nøkkelen og AES-GCM for innholdet, Fhi.Lmr.Felles.Ratatosk/FilKryptering.cs) og overføres til sikker sone.

Se repo-skillen `lmr-individdatauttrekk`.

#### Fhi.Lmr.Innbyggertjenester

Ansvar: Gi innbyggere innsyn i egne legemiddelutleveringer via Helsenorge. Tar imot innsynsforespørsler (HelseId), slår opp PasientId i Pasientregisteret og har en nattlig lastejobb fra Uttrekksdatabasen.

Se repo-skillen `lmr-innbyggertjenester`.

#### Fhi.Lmr.Institusjonsimulator

Ansvar: Simulerer institusjoner (sykehus/sykehjem) for test og utvikling.

#### Fhi.Lmr.InternStatistikk

Ansvar: LISA, den interne statistikkapplikasjonen. Aggregerte tall fra LMR til ansatte i FHI, beregnet i en SSAS-modell på data fra Uttrekksdatabasen og Grunndata.

Se repo-skillen `lmr-internstatistikk`.

#### Fhi.Lmr.Kontroll

Ansvar: Frontend/administrasjonsløsning for Legemiddelregisteret, brukt av både fag og utviklere. Har ingen egen database; alt hentes fra og skrives til andre LMR-tjenester.
Alias: Kontroll-siden

- Se meldingsstatus, rapporter, varsler og resultat av helsesjekker (systemstatus)
- Se rapporter og rapporteringsoversikt fra Eik, og bestille retransmittering fra Farmapro (legacy)
- Vedlikeholde grunndata, administrere individdatauttrekk og dataprodukter
- Administrere brukernes roller

Se repo-skillen `lmr-kontroll`.

#### Fhi.Lmr.Krl.Admin

Ansvar: Webapplikasjon - Administrasjonsside for KRL (Antibiotikarapporten, RAK). Har ingen egen database; all tilstand ligger i Rak.Api (`Fhi.Lmr.Rak`).

Se repo-skillen `lmr-krladmin`.

#### Fhi.Lmr.Logging

Ansvar: Lagre logg fra alle LMR-tjenester. Alle tjenester sender Serilog-hendelser dit, og Kontroll leser dem. Hver tjeneste må sette `Tjeneste`-propertyen (den blir `Kilde`) og feltene som er `[JsonRequired]`; kravene står i repo-skillen.

Se repo-skillen `lmr-logging`.

#### Fhi.Lmr.Meldingsformidler

Ansvar: Transport- og orkestreringstjeneste for meldinger mellom LMR sine tjenester og eksterne systemer.

Se repo-skillen `lmr-meldingsformidler` for fullstendig dokumentasjon av flyter, klienter, helsesjekker og integrasjoner.

#### Fhi.Lmr.Meldingsmottak

Ansvar: Mottak, kvalitetskontroll og splitting av meldinger fra apotek (Eik, og Farmapro som legacy) og fra institusjoner.

Se repo-skillen `lmr-meldingsmottak` for fullstendig domenekunnskap (kilder, splitting, statusmodell, forretningsregler).

#### Fhi.Lmr.Pasientregister

Ansvar: Lagre og vedlikeholde informasjon om pasienter.

- Har informasjon om identiteten til pasientene
- En pasient kan ha flere identiteter, registeret kobler en pasientid til flere identiteter
- Behandler en Pasientmelding, slår opp personen i Folkeregisteret (herunder bosted) og lagrer informasjon om pasientene
- Genererer en pasientliste som overføres til Utleveringslageret og til Administreringslageret (av Meldingsformidler)
- Har Kobling- og Oppslag-API-er for Individdatauttrekk og Dataprodukter

Se repo-skillen `lmr-pasientregister`.

#### Fhi.Lmr.Rak

Ansvar: Backend-API for RAK-rapporten, der fastleger får oversikt over egen antibiotikaforskrivning sammenlignet med fylket og landet. Frontend er webappen `Fhi.Lmr.Rak.Web` i et eget repo, og administrasjonen er `Fhi.Lmr.Krl.Admin`.

Se repo-skillen `lmr-rak`.

#### Fhi.Lmr.Rak.Web

Ansvar: Webapplikasjonen for fastleger (frontend til RAK-API-et i `Fhi.Lmr.Rak`). Har ikke repo-skill.

#### Fhi.Lmr.Rekvirentregister

Ansvar: Lagre og vedlikeholde informasjon om rekvirenter (leger).

- Har informasjon om identiteten til rekvirenten (HPR-nummer, feltkryptert)
- Behandler en Rekvirentmelding, slår opp i Helsepersonellregisteret (HPR) og lagrer informasjon om rekvirentene
- Genererer en rekvirentliste som overføres til Utleveringslageret og til Administreringslageret (av Meldingsformidler)

Se repo-skillen `lmr-rekvirentregister`.

#### Fhi.Lmr.Tilganger

Ansvar: LMRs felles identitetskatalog for brukere (BrukerId koblet til Entra ID-identiteten) og felles lager for tilgangssøknader og tilgangslogg. Validerer Entra ID. Rollene ligger i Entra-grupper som Kontroll administrerer, og lagres ikke her.

Se repo-skillen `lmr-tilganger`.

#### Fhi.Lmr.Utleveringslager

Ansvar: Lagre og behandle opplysninger om legemiddelutleveringer fra apotek.

- Lager for alle utleveringene til pasienter
- Har ikke pasient- og rekvirent-identiteter, men kobler data via pasientid og rekvirentid
- Prosesserer en utleveringsmelding sammen med en pasientliste og en rekvirentliste

Se repo-skillen `lmr-utleveringslager`.

#### Fhi.Lmr.Uttrekksdatabase

Ansvar: Database for uttrekk av data fra LMR: én flat tabell med én rad per utlevering, med kvalitetssikring. Kilde for uttrekk, dataprodukter, intern statistikk og innbyggertjenester.

Se repo-skillene `lmr-uttrekksdatabase` og `leggtil-variabler`.

#### Fhi.Lmr.Varseltjeneste

Ansvar: Samle inn hendelser fra andre tjenester og håndtere varsler.

Poller kildetjenestene for hendelser, grupperer dem til varsler og utfører handlinger (f.eks. reprosessering) på vegne av Kontroll-siden. Se [HENDELSER-VARSLER.md](./references/HENDELSER-VARSLER.md) og repo-skillen `lmr-varseltjeneste`.

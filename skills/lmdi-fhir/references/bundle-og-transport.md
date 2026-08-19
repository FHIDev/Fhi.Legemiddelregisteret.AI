# Bundle, referanser og transport

Kilder: `LMDI/input/fsh/profiles/LegemiddelregisterBundle.fsh`, `LMDI/input/pagecontent/SignertKryptertBundle.md`, `protokoll.md`, `integrasjon.md`.

## 1. LegemiddelregisterBundle (FHIR-nivå)

### Kjerneregler
- `type = "transaction"`.
- Alle `entry.request.method = "POST"`.
- `entry.request.url` er påkrevd av FHIR-spec, men **verdien har ingen funksjonell betydning** hos mottaker. Bruk typisk ressurstypenavn (`Patient`, `Encounter`, ...).
- Tillatt ressurstyper håndheves av invariant `lr-allowed-resources` (ni LMDI-profiler).

### Minste komplette bundle for én administrering
Følgende ressurser trengs for en tolkbar `MedicationAdministration`:

```
Pasient  ──────────────────────┐
                               │ subject
Helsepersonell ── requester ──►│
                               ▼
Organisasjon(er) ── serviceProvider ──► Episode ── context ──► MedicationAdministration
  (med partOf-hierarki)                             ▲
                                                    │ request
Legemiddel  ──── medicationReference ──► MedicationRequest
(klassifisert med ATC-extension)
```

Helsepersonell, Diagnose og Virkestoff er valgfrie. Helsepersonell tas med når rekvirenten er kjent; Diagnose og Virkestoff tas med når indikasjon eller rent virkestoff er relevant.

### Referanseform
Fra `Bundle-Scenario-Sykehjem-Oksykodon` i `LegemiddelregisterBundle.fsh`:

```json
{
  "fullUrl": "urn:uuid:11111111-1111-4111-8111-111111111111",
  "resource": { "resourceType": "Patient", ... },
  "request": { "method": "POST", "url": "Patient" }
}
```

Og i en annen entry:

```json
"subject": { "reference": "urn:uuid:11111111-1111-4111-8111-111111111111" }
```

UUID-versjon 4 anbefales (13. siffer = `4`, 17. siffer = `8|9|a|b`).

### Bundle-identifikator
```
"identifier": {
  "system": "urn:oid:2.16.578.1.34.10.3",
  "value": "bundle-001"
}
```
(Eksempel-OID fra bundle-eksemplet; brukes som meldings-id på bundle-nivå.)

### `timestamp`
ISO 8601 med tidssone, f.eks. `"2024-02-07T13:28:17.239+02:00"`.

---

## 2. Referansetopologi — detaljert

| Kilde-ressurs | Felt | Mål-profil | Kardinalitet | Kommentar |
|---|---|---|---|---|
| MedicationAdministration | `subject` | Pasient | 1..1 | Påkrevd i FHIR-standard |
| MedicationAdministration | `medication[x]` | Legemiddel | 1..1 | Reference-only (ikke CodeableConcept) |
| MedicationAdministration | `context` | Episode | 0..1 MS | Hvilken episode |
| MedicationAdministration | `request` | Legemiddelrekvirering | 0..1 MS | Rekvireringen administrering er basert på |
| MedicationAdministration | `reasonReference` | Diagnose | 0..* | Indikasjon |
| MedicationRequest | `subject` | Pasient | 1..1 MS | |
| MedicationRequest | `requester` | Helsepersonell | 0..1 MS | Oppgis når rekvirenten er kjent |
| MedicationRequest | `medication[x]` | Legemiddel | 1..1 MS | |
| MedicationRequest | `encounter` | Episode | 0..1 | |
| MedicationRequest | `reasonReference` | Diagnose | 0..* | |
| MedicationRequest | `priorPrescription` | Legemiddelrekvirering | 0..1 | |
| Encounter (Episode) | `serviceProvider` | Organisasjon | 0..1 | Sted |
| Condition (Diagnose) | `subject` | Pasient | 1..1 | |
| Organization | `partOf` | Organisasjon | 0..1 MS | Hierarki |
| Medication | `ingredient.itemReference` | Virkestoff \| Legemiddel | 0..* | Valgfri; kan alternativt være `itemCodeableConcept` |

### Sjekkliste for referansekonsistens
1. Hver `Reference.reference` som starter med `urn:uuid:` må finnes som `entry.fullUrl` i samme bundle.
2. Ressursen referert til må ha `meta.profile` som matcher `only Reference(...)`-kravet.
3. Ingen sirkulære referanser (bortsett fra Organization.partOf hierarki, som alltid peker oppover).
4. `MedicationAdministration.request` og `MedicationRequest` bør gjelde samme `Pasient` og samme `Legemiddel`.

---

## 3. SignertKryptertBundle (transport-konvolutt)

**Ikke en FHIR-ressurs.** Et JSON-objekt som omslutter en GZip-komprimert, AES-kryptert `LegemiddelregisterBundle`.

### Feltene (i denne rekkefølgen — kilde: `SignertKryptertBundle.md`)

| Felt | Type | Beskrivelse |
|---|---|---|
| `messageId` | string | Unik ID (typisk UUID) |
| `senderOrganizationIdentifier` | string | Avsenders org-ID (OID eller org.nr) — må samsvare med signeringssertifikatet |
| `messageFormatVersion` | string | `"1.0"` |
| `rapporteringFra` | string | ISO-8601 starttidspunkt for dataene |
| `rapporteringTil` | string | ISO-8601 sluttidspunkt |
| `encryptedContent` | string | Base64 av AES-GCM-ciphertext |
| `encryptionCertificateThumbprint` | string | Thumbprint for LMRs sertifikat brukt til kryptering |
| `encryptedKey` | string | Base64 av RSA-OAEP-SHA256-kryptert AES-nøkkel |
| `nonce` | string | Base64, 12 bytes |
| `authenticationTag` | string | Base64, 16 bytes (AES-GCM-tag) |
| `signatureCertificateThumbprint` | string | Avsenders sertifikat |
| `signature` | string | Base64, RSA-PKCS1-v1.5 over SHA-256 av `encryptedContent` |
| `generatedAt` | string | ISO-8601, norsk lokaltid |

### Kryptografi-kjedet
1. **FHIR-bundle** → JSON.
2. **GZip-komprimer** (DEFLATE) bundlens JSON-string.
3. **AES-256-GCM**: generer 32-byte nøkkel og 12-byte nonce. Krypter den komprimerte byte-arrayen. Ut: `encryptedContent` + `authenticationTag` (16 bytes).
4. **RSA-OAEP-SHA256**: krypter AES-nøkkelen med LMRs offentlige nøkkel. Ut: `encryptedKey`.
5. **SHA-256** av `encryptedContent`.
6. **RSA-PKCS1-v1.5**: signer hashen med avsenders private nøkkel. Ut: `signature`.
7. Binære felter kodes til Base64.

---

## 4. Autentisering og API

Kilde: `integrasjon.md`, `protokoll.md`.

### Endepunkter
| Formål | URL |
|---|---|
| Produksjon | `https://fhirmottak.lmr.fhi.no/fhirmottak/v1` |
| Test | `https://test-fhirmottak.lmr.fhi.no/fhirmottak/v1` |
| Validering bundle (ukryptert, test) | `POST /fhirmottak/v1/validateLegemiddelregisterBundle` |
| Validering konvolutt (test) | `POST /fhirmottak/v1/validate` |

### Maskinporten
- Scope: `fhi:lmr/fhirmottak.api`
- Resource-claim i JWT: `fhi:lmr/fhirmottak`
- OAuth2 Client Credentials flow med JWT bearer assertion
- Anbefalt bibliotek: `https://github.com/Altinn/altinn-apiclient-maskinporten`
- Selvbetjeningsportal test: `https://sjolvbetjening.test.samarbeid.digdir.no/`

### Nettverk
- Produksjonsmiljøet krever at avsenders IP er **hvitelistet** av LMR.
- Testmiljøet har ikke IP-hvitelisting, men det krypterte endepunktet krever Maskinporten-token.

---

## 5. Protokoll

Kilde: `protokoll.md`.

- **Frekvens**: daglig.
- **Innhold**: nye eller endrede data siden siste vellykkede overføring. Ved første overføring: fra avtalt startdato.
- **Retry ved kommunikasjonsfeil**: opptil 3 forsøk, ca. 1 time mellom.
- **Valideringsfeil**: rettes manuelt hos avsender og sendes på nytt i senere overføring (ingen automatisk retry).

### HTTP-statuskoder (fra `integrasjon.md`)
- `200 OK` — validert (ikke lagret ved `/validate`).
- `400 Bad Request` — valideringsfeil, ugyldig JSON, ukjent avsender, signatur- eller dekrypteringsfeil.
- `401 Unauthorized` — manglende/utløpt/ugyldig token.
- `403 Forbidden` — gyldig token, men feil scope.
- `500 Internal Server Error` — serverfeil (rapportér til FHI).

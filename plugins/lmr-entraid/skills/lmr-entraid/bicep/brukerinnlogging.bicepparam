using 'brukerinnlogging.bicep'

param tjenesteNavn = 'Lmr.MinTjeneste'
param miljo = 'Test'

// ⚠️ Generér ÉN gang og endre den ALDRI — Client.Web sin requiredResourceAccess peker på den.
param apiScopeId = '00000000-0000-0000-0000-000000000000'
param apiScopeValue = 'Fhi.Lmr.MinTjeneste.All'

/*
  DET FELLES LMR-ROLLESETTET - appRoleId-ene under er de EKTE UUID-ene som allerede er i
  bruk i EntraID i dag. De er bevisst like på tvers av BÅDE miljøer og apper (Kontroll og
  InternStatistikk bruker de samme), og det er nettopp det som gjør rollene felles: én
  gruppe tildeles matchende app-rolle i hver app.

  Bruker du dette rollesettet, KOPIER UUID-ene som de er. Genererer du nye, blir rollene
  appspesifikke og en bruker mister tilgang i den andre appen.

  ⚠️ Pseudo-rollen 'ingen' i Kontroll skal IKKE med — den betyr «hvilken som helst
  innlogget bruker» og finnes verken i databasen eller som app-rolle.

  gruppeObjektId er object ID-en til gruppa FOR DET MILJØET DU DEPLOYER. Gruppene finnes for
  Dev/Test/QA/Prod med samme navn bortsett fra miljøet, så en ID fra feil miljø gir roller på tvers
  av miljøer. Slå opp og kontroller navnet før deploy:
    az ad group show --group 'A-FHI-App-Lmr-<Miljø>-<Rolle>' --query "{id:id, navn:displayName}"
  La feltet stå tomt ("") for en rolle med en NY gruppe som ikke finnes ennå — den tildeles etterpå.
*/
param roller = [
  {
    nokkel: 'lesogskriv'
    visningsnavn: 'Les og skriv'
    beskrivelse: 'Basistilgang. Tilgang til å se og endre alt utenom å behandle godkjenninger og gjøre endringer på individdatauttrekk.'
    appRoleId: '97590f02-045f-4b4d-a965-9f338c15160f'
    gruppeObjektId: '<object ID til A-FHI-App-Lmr-<Miljø>-LesOgSkriv>'
  }
  {
    nokkel: 'endreatc'
    visningsnavn: 'Endre ATC'
    beskrivelse: 'Tilgang til å se alt, men kun editere ATC-koder.'
    appRoleId: '6750f1e6-6c4d-4e56-859e-c3a1ae7f08fe'
    gruppeObjektId: '<object ID til A-FHI-App-Lmr-<Miljø>-EndreAtc>'
  }
  {
    nokkel: 'godkjenn'
    visningsnavn: 'Godkjenn'
    beskrivelse: 'Tilgang til å godkjenne endring av rettigheter.'
    appRoleId: '0142c73c-3089-4888-875a-dc0ebcd76be4'
    gruppeObjektId: '<object ID til A-FHI-App-Lmr-<Miljø>-Godkjenn>'
  }
  {
    nokkel: 'individdatauttrekk'
    visningsnavn: 'Individdatauttrekk'
    beskrivelse: 'Tilgang til å se og bruke individdatauttrekk og dataprodukt.'
    appRoleId: 'e396de96-7305-47ed-9a66-f3a4bd665382'
    gruppeObjektId: '<object ID til A-FHI-App-Lmr-<Miljø>-Individdatauttrekk>'
  }
  {
    nokkel: 'internstatistikk'
    visningsnavn: 'Intern statistikkløsning'
    beskrivelse: 'Tilgang til intern statistikkløsning for LMR.'
    appRoleId: 'bfb0f358-6e89-4e3d-ad15-005a75b740e0'
    gruppeObjektId: '<object ID til A-FHI-App-Lmr-<Miljø>-InternStatistikk>'
  }
]

/*
  ⚠️ Post-logout-stien MÅ stå her også. EntraID krever at post_logout_redirect_uri er
  registrert blant redirectUris, ellers feiler utloggingen.
*/
param webRedirectUris = [
  'https://mintjeneste-test.fhi.no/signin-oidc'
  'https://mintjeneste-test.fhi.no/signout-callback-oidc'
  'https://localhost:7105/signin-oidc'
  'https://localhost:7105/signout-callback-oidc'
]

param logoutUrl = 'https://mintjeneste-test.fhi.no/signout-oidc'

// base64 av de OFFENTLIGE .cer-filene:  base64 -w0 <navn>.cer
param clientWebSertifikatBase64 = 'PLACEHOLDER_BASE64_AV_CLIENT_WEB_CER'
param clientMachineSertifikatBase64 = 'PLACEHOLDER_BASE64_AV_CLIENT_MACHINE_CER'

// Object-IDer til de som skal eie app-registreringen. Finn din egen med:
//   az ad signed-in-user show --query id -o tsv
// ⚠️ I Prod skal fagpersonen også stå her: LMR Kari 'b53747d8-b2a0-4297-b430-5bfb3919f4bd',
// Grossiststatistikken Kristine 'af7e2f5c-58c1-4a7d-b675-d9a312bb431e'. Du fjerner deg selv
// etterpå — se «Rekkefølgen» steg 12 i SKILL.md.
param eiere = [
  '00000000-0000-0000-0000-000000000000'
]

// M2M-kanter: apiAppId, apiSpObjectId (= spObjectId) og appRoleId (appRoller[].id) står i
// entraid/baseline/<callee>.json i Fhi.Lmr.AI.
param callees = []

// Delegerte kanter (webappen kaller med brukerens eget token, ikke OBO) — kun når kallet må bære
// sluttbrukerens identitet. Krever admin consent fra NHN.
param delegerteKanter = []

// true kun for appen som administrerer rolletildelinger via Graph (i LMR: Kontroll).
param krevGraph = false

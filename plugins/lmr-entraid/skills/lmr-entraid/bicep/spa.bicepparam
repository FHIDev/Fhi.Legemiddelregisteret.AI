using 'spa.bicep'

param tjenesteNavn = 'MinSpaTjeneste'
param miljo = 'Test'

param apiScopeId = '00000000-0000-0000-0000-000000000000'
param apiScopeValue = 'access_as_user'

param roller = [
  {
    nokkel: 'Admin'
    visningsnavn: 'Admin'
    beskrivelse: 'Administrerer tilganger til tjenesten.'
    appRoleId: '00000000-0000-0000-0000-000000000000'
    gruppeObjektId: '<object ID til A-FHI-App-MinSpaTjeneste-Test-Admin>'
  }
  {
    nokkel: 'Bruker'
    visningsnavn: 'Bruker'
    beskrivelse: 'Vanlig bruker av tjenesten.'
    appRoleId: '00000000-0000-0000-0000-000000000000'
    gruppeObjektId: '<object ID til A-FHI-App-MinSpaTjeneste-Test-Bruker>'
  }
]

// SPA-plattformen. Public client — ingen client secret, PKCE brukes i stedet.
param spaRedirectUris = [
  'https://minspatjeneste-test.fhi.no'
  'http://localhost:4200'
]

param clientMachineSertifikatBase64 = 'PLACEHOLDER_BASE64_AV_CLIENT_MACHINE_CER'

// Object-IDer til de som skal eie app-registreringen. Finn din egen med:
//   az ad signed-in-user show --query id -o tsv
// ⚠️ I Prod skal fagpersonen også stå her: LMR Kari 'b53747d8-b2a0-4297-b430-5bfb3919f4bd',
// Grossiststatistikken Kristine 'af7e2f5c-58c1-4a7d-b675-d9a312bb431e'. Du fjerner deg selv
// etterpå — se «Rekkefølgen» steg 12 i SKILL.md.
param eiere = [
  '00000000-0000-0000-0000-000000000000'
]

param krevGraph = true

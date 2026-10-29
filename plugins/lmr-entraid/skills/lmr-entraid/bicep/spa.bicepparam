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
    gruppeUniktNavn: 'a-fhi-app-minspatjeneste-test-admin'
  }
  {
    nokkel: 'Bruker'
    visningsnavn: 'Bruker'
    beskrivelse: 'Vanlig bruker av tjenesten.'
    appRoleId: '00000000-0000-0000-0000-000000000000'
    gruppeUniktNavn: 'a-fhi-app-minspatjeneste-test-bruker'
  }
]

// SPA-plattformen. Public client — ingen client secret, PKCE brukes i stedet.
param spaRedirectUris = [
  'https://minspatjeneste-test.fhi.no'
  'http://localhost:4200'
]

param clientMachineSertifikatBase64 = 'PLACEHOLDER_BASE64_AV_CLIENT_MACHINE_CER'

param eiere = [
  '00000000-0000-0000-0000-000000000000'
]

param krevGraph = true

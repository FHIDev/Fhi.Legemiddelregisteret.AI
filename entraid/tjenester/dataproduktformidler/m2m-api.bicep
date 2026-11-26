// ⛔ KUN FOR Å OPPRETTE. Test-registreringen finnes — deploy ikke denne malen mot den.
// Tilstanden nå: entraid/baseline/fhi-lmr-dataproduktformidler-api-test.json. Prosess: entraid/README.md.

extension microsoftGraphV1

param tjenesteNavn string
@allowed(['Test', 'Prod'])
param miljo string
param apiAppRoleId string
param apiAppRoleValue string
param eiere string[]

var visningsnavn = 'Fhi.${tjenesteNavn}.Api - ${miljo}'
var uniktNavn = toLower('fhi-${replace(tjenesteNavn, '.', '-')}-api-${miljo}')
var appRoller = [
  {
    id: apiAppRoleId
    allowedMemberTypes: ['Application']
    displayName: apiAppRoleValue
    value: apiAppRoleValue
    description: 'Application-tilgang (client credentials) til ${tjenesteNavn}-API-et.'
    isEnabled: true
  }
]

// Graph tildeler appId ved opprettelse. Et andre pass setter api://<appId> på samme uniqueName.
module apiPass1 'moduler/api-applikasjon.bicep' = {
  name: 'api-pass1-${uniktNavn}'
  params: {
    uniktNavn: uniktNavn
    visningsnavn: visningsnavn
    appRoller: appRoller
    eiere: eiere
  }
}

module apiPass2 'moduler/api-applikasjon.bicep' = {
  name: 'api-pass2-${uniktNavn}'
  params: {
    uniktNavn: uniktNavn
    visningsnavn: visningsnavn
    appRoller: appRoller
    eiere: eiere
    identifierUris: ['api://${apiPass1.outputs.appId}']
  }
}

resource apiSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: apiPass2.outputs.appId
  owners: {
    relationships: eiere
    relationshipSemantics: 'append'
  }
}

output apiAppId string = apiPass2.outputs.appId
output apiSpObjectId string = apiSp.id
output defaultScope string = apiAppRoleValue
output klientScope string = 'api://${apiPass2.outputs.appId}/.default'

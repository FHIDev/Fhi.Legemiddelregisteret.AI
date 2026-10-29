/*
  VARIANT 4 av 4 — SPA-VARIANTEN (.Api + .Client.Web som SPA + .Client.Machine)

  Varianten Fhi.Grossiststatistikken bruker. Tas med for fullstendighet -
  LMR-tjenestene bruker IKKE denne.

  OBS: FORSKJELLEN FRA brukerinnlogging.bicep, og hvorfor den betyr noe:
  her er Client.Web en PUBLIC client (spa.redirectUris + PKCE). Den har ingen
  keyCredentials, fordi en SPA ikke kan holde på en hemmelighet — koden veksles i
  nettleseren. LMR-appene veksler koden på serveren med private_key_jwt, og skal
  derfor bruke web.redirectUris + sertifikat. Velger du feil her, får du enten
  "AADSTS9002327: Tokens issued for the Single-Page Application client-type may only
  be redeemed via cross-origin requests" eller en klient uten autentisering.

  OBS: Gruppene opprettes ikke her — se brukerinnlogging.bicep.
*/
extension microsoftGraphV1

@description('Tjenestenavn uten Fhi.-prefiks, f.eks. "Grossiststatistikken".')
param tjenesteNavn string

@allowed(['Dev', 'Test', 'QA', 'Prod'])
param miljo string

@description('Stabil UUID for det delegerte scopet.')
param apiScopeId string

@description('Scope-verdi, f.eks. access_as_user.')
param apiScopeValue string

@description('Rollesettet: { nokkel, visningsnavn, beskrivelse, appRoleId, gruppeUniktNavn }. Typisk Admin + Bruker.')
param roller object[]

@description('Redirect-URI-er på SPA-plattformen. Public client — ingen client secret.')
param spaRedirectUris string[]

@description('base64 av det offentlige .cer for Client.Machine.')
param clientMachineSertifikatBase64 string

@description('Object-IDer som skal eie app-registreringene.')
param eiere string[] = []

@description('Om Client.Machine skal be om Graph User.ReadBasic.All (brukersøk ved rolletildeling).')
param krevGraph bool = true

var graphAppId = '00000003-0000-0000-c000-000000000000'
var graphUserReadBasicAll = '97235f07-e226-4f63-ace3-39588e11d3a1'

var apiVisningsnavn = 'Fhi.${tjenesteNavn}.Api - ${miljo}'
var apiUniktNavn = toLower('fhi-${replace(tjenesteNavn, '.', '-')}-api-${miljo}')
var webUniktNavn = toLower('fhi-${replace(tjenesteNavn, '.', '-')}-client-web-${miljo}')
var maskinUniktNavn = toLower('fhi-${replace(tjenesteNavn, '.', '-')}-client-machine-${miljo}')

var appRoller = [
  for r in roller: {
    id: r.appRoleId
    allowedMemberTypes: ['User']
    displayName: r.visningsnavn
    value: r.nokkel
    description: r.beskrivelse
    isEnabled: true
  }
]

var delegertScope = [
  {
    id: apiScopeId
    value: apiScopeValue
    type: 'Admin'
    adminConsentDisplayName: 'Bruk ${tjenesteNavn} på vegne av innlogget bruker'
    adminConsentDescription: 'Lar applikasjonen kalle ${tjenesteNavn}-API-et på vegne av innlogget bruker.'
    userConsentDisplayName: 'Bruk ${tjenesteNavn}'
    userConsentDescription: 'Lar applikasjonen kalle ${tjenesteNavn}-API-et på dine vegne.'
    isEnabled: true
  }
]

var graphAccess = krevGraph
  ? [
      {
        resourceAppId: graphAppId
        resourceAccess: [
          {
            id: graphUserReadBasicAll
            type: 'Role'
          }
        ]
      }
    ]
  : []

// To pass fordi identifierUris trenger appId — se m2m-api.bicep.
module apiPass1 'moduler/api-applikasjon.bicep' = {
  name: 'api-pass1-${apiUniktNavn}'
  params: {
    uniktNavn: apiUniktNavn
    visningsnavn: apiVisningsnavn
    appRoller: appRoller
    delegerteScopes: delegertScope
    eiere: eiere
  }
}

module apiPass2 'moduler/api-applikasjon.bicep' = {
  name: 'api-pass2-${apiUniktNavn}'
  params: {
    uniktNavn: apiUniktNavn
    visningsnavn: apiVisningsnavn
    appRoller: appRoller
    delegerteScopes: delegertScope
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

// PUBLIC client: spa.redirectUris, ingen keyCredentials. Dette er hele forskjellen.
resource clientWeb 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: webUniktNavn
  displayName: 'Fhi.${tjenesteNavn}.Client.Web - ${miljo}'
  signInAudience: 'AzureADMyOrg'
  spa: {
    redirectUris: spaRedirectUris
  }
  appRoles: appRoller
  requiredResourceAccess: [
    {
      resourceAppId: apiPass2.outputs.appId
      resourceAccess: [
        {
          id: apiScopeId
          type: 'Scope'
        }
      ]
    }
  ]
  owners: {
    relationships: eiere
    relationshipSemantics: 'append'
  }
}

resource clientWebSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: clientWeb.appId
  owners: {
    relationships: eiere
    relationshipSemantics: 'append'
  }
}

resource clientMachine 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: maskinUniktNavn
  displayName: 'Fhi.${tjenesteNavn}.Client.Machine - ${miljo}'
  signInAudience: 'AzureADMyOrg'
  web: {}
  keyCredentials: [
    {
      type: 'AsymmetricX509Cert'
      usage: 'Verify'
      key: clientMachineSertifikatBase64
    }
  ]
  requiredResourceAccess: graphAccess
  owners: {
    relationships: eiere
    relationshipSemantics: 'append'
  }
}

resource clientMachineSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: clientMachine.appId
  owners: {
    relationships: eiere
    relationshipSemantics: 'append'
  }
}

resource rolleGrupper 'Microsoft.Graph/groups@v1.0' existing = [
  for r in roller: {
    uniqueName: r.gruppeUniktNavn
  }
]

resource tildelingApi 'Microsoft.Graph/appRoleAssignedTo@v1.0' = [
  for (r, i) in roller: {
    appRoleId: r.appRoleId
    principalId: rolleGrupper[i].id
    resourceId: apiSp.id
  }
]

resource tildelingWeb 'Microsoft.Graph/appRoleAssignedTo@v1.0' = [
  for (r, i) in roller: {
    appRoleId: r.appRoleId
    principalId: rolleGrupper[i].id
    resourceId: clientWebSp.id
  }
]

output apiAppId string = apiPass2.outputs.appId
output apiSpObjectId string = apiSp.id
output clientWebAppId string = clientWeb.appId
output clientMachineAppId string = clientMachine.appId
output clientMachineSpObjectId string = clientMachineSp.id
output delegertScopeStreng string = 'api://${apiPass2.outputs.appId}/${apiScopeValue}'

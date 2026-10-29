/*
  VARIANT 3 av 4 — BRUKERINNLOGGING (.Api + .Client.Web + .Client.Machine)

  Tjenesten har pålogging av mennesker, og rolletildelingen ligger i EntraID i stedet for
  i en database. Oppretter alle tre app-registreringene og knytter rollegruppene til
  app-rollene på både .Api og .Client.Web.

  OBS: SIKKERHETSGRUPPENE OPPRETTES IKKE HER. Extensionen har ingen
  Microsoft.Graph/administrativeUnits, og gruppene MÅ ligge i AU-Legemiddelregisteret.
  Kjør scripts/opprett-gruppe-i-au.sh først; denne malen refererer dem med 'existing'.
  Se references/BICEP-OPPSETT.md.

  OBS: MILJØREGEL: her brukes egen app-registrering PER miljø (Dev/Test/QA/Prod).
  'roles'-claimet beregnes fra tildelinger på app-regens service principal, så deler to
  miljøer app-reg, gir medlemskap i Dev-gruppa også rollen i Prod.

  Deploy:
    az deployment group create -g <rg> \
      --template-file brukerinnlogging.bicep --parameters brukerinnlogging.bicepparam
*/
extension microsoftGraphV1

@description('Tjenestenavn uten Fhi.-prefiks, f.eks. "Lmr.InternStatistikk".')
param tjenesteNavn string

@allowed(['Dev', 'Test', 'QA', 'Prod'])
param miljo string

@description('Stabil UUID for det delegerte scopet. Client.Web sin requiredResourceAccess peker på den. Endres ALDRI.')
param apiScopeId string

@description('Scope-verdi (havner i scp-claimet). MÅ matche ApiTokenValidation:DefaultScope.')
param apiScopeValue string

@description('Rollesettet. Delt mellom LMR-appene: det som gjør rollene felles er at de SAMME gruppene tildeles matchende app-roller i hver app — derfor må appRoleId være lik på tvers av appene. Felt: nokkel, visningsnavn, beskrivelse, appRoleId, gruppeUniktNavn.')
param roller object[]

@description('Redirect-URI-er på Client.Web sin WEB-plattform (confidential client, ikke SPA).')
param webRedirectUris string[]

@description('Front-channel logout URL for Client.Web. Tom streng = ikke satt.')
param logoutUrl string = ''

@description('base64 av det offentlige .cer for Client.Web (client assertion ved code-veksling).')
param clientWebSertifikatBase64 string

@description('base64 av det offentlige .cer for Client.Machine.')
param clientMachineSertifikatBase64 string

@description('Object-IDer som skal eie app-registreringene.')
param eiere string[] = []

@description('M2M-kanter for Client.Machine: { navn, apiAppId, apiSpObjectId, appRoleId }.')
param callees object[] = []

@description('DELEGERTE kanter for Client.Web (On-Behalf-Of): { navn, apiAppId, scopeId }. Brukes når kallet må bære sluttbrukerens identitet, ikke appens.')
param delegerteKanter object[] = []

@description('Om Client.Machine skal be om Graph User.ReadBasic.All. Trengs kun av appen som administrerer rolletildelinger.')
param krevGraph bool = false

var graphAppId = '00000003-0000-0000-c000-000000000000'
var graphUserReadBasicAll = '97235f07-e226-4f63-ace3-39588e11d3a1'

var apiVisningsnavn = 'Fhi.${tjenesteNavn}.Api - ${miljo}'
var apiUniktNavn = toLower('fhi-${replace(tjenesteNavn, '.', '-')}-api-${miljo}')
var webUniktNavn = toLower('fhi-${replace(tjenesteNavn, '.', '-')}-client-web-${miljo}')
var maskinUniktNavn = toLower('fhi-${replace(tjenesteNavn, '.', '-')}-client-machine-${miljo}')

// allowedMemberTypes: User => tildeles til brukere/grupper, ikke til andre apper.
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
    // 'Admin' = admin consent required. Brukere kan ikke selv samtykke.
    type: 'Admin'
    adminConsentDisplayName: 'Bruk ${tjenesteNavn} på vegne av innlogget bruker'
    adminConsentDescription: 'Lar applikasjonen kalle ${tjenesteNavn}-API-et på vegne av innlogget bruker.'
    userConsentDisplayName: 'Bruk ${tjenesteNavn}'
    userConsentDescription: 'Lar applikasjonen kalle ${tjenesteNavn}-API-et på dine vegne.'
    isEnabled: true
  }
]

// For-uttrykk kan ikke stå inne i concat() (BCP138) — hoistes til variabler.
var delegertKantAccess = [
  for k in delegerteKanter: {
    resourceAppId: k.apiAppId
    resourceAccess: [
      {
        id: k.scopeId
        type: 'Scope'
      }
    ]
  }
]

var calleeAccess = [
  for c in callees: {
    resourceAppId: c.apiAppId
    resourceAccess: [
      {
        id: c.appRoleId
        type: 'Role'
      }
    ]
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

// To pass fordi identifierUris trenger appId — se m2m-api.bicep for full forklaring.
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

/*
  Client.Web er CONFIDENTIAL: koden veksles på serveren med private_key_jwt.
  Derfor web.redirectUris + keyCredentials — ikke spa.redirectUris (jf. spa.bicep).

  OBS: post_logout_redirect_uri må stå BLANT redirectUris; EntraID krever at den er registrert.
*/
resource clientWeb 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: webUniktNavn
  displayName: 'Fhi.${tjenesteNavn}.Client.Web - ${miljo}'
  signInAudience: 'AzureADMyOrg'
  web: {
    redirectUris: webRedirectUris
    logoutUrl: empty(logoutUrl) ? null : logoutUrl
  }
  keyCredentials: [
    {
      type: 'AsymmetricX509Cert'
      usage: 'Verify'
      key: clientWebSertifikatBase64
    }
  ]
  // Samme app-roller som på Api: rollen må ligge på app-regen tokenet utstedes FOR.
  appRoles: appRoller
  requiredResourceAccess: concat(
    [
      {
        resourceAppId: apiPass2.outputs.appId
        resourceAccess: [
          {
            id: apiScopeId
            type: 'Scope'
          }
        ]
      }
    ],
    delegertKantAccess
  )
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
  requiredResourceAccess: concat(calleeAccess, graphAccess)
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

/*
  Sikkerhetsgruppene refereres, ikke opprettes — de ligger i AU-Legemiddelregisteret og
  lages av scripts/opprett-gruppe-i-au.sh. 'existing' slår opp på uniqueName, som må være
  etterfylt på gruppa (scriptet gjør det).
*/
resource rolleGrupper 'Microsoft.Graph/groups@v1.0' existing = [
  for r in roller: {
    uniqueName: r.gruppeUniktNavn
  }
]

/*
  Rolletildeling = gruppemedlemskap. Gruppa tildeles app-rollen på BÅDE Api og Client.Web,
  slik at rollen kommer med i 'roles'-claimet i begge tokens.
*/
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

@description('ApiTokenValidation:Audience')
output apiAppId string = apiPass2.outputs.appId

@description('Trengs når andre klienter skal få consent mot dette API-et.')
output apiSpObjectId string = apiSp.id

@description('UserAuthentication:ClientId')
output clientWebAppId string = clientWeb.appId

@description('OidcClients:EntraIdClient:ClientId')
output clientMachineAppId string = clientMachine.appId

@description('Eier av sikkerhetsgruppene — settes av opprett-gruppe-i-au.sh.')
output clientMachineSpObjectId string = clientMachineSp.id

@description('Full scope-streng til UserAuthentication:Scopes.')
output delegertScopeStreng string = 'api://${apiPass2.outputs.appId}/${apiScopeValue}'

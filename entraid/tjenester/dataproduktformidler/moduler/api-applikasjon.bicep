extension microsoftGraphV1

param uniktNavn string
param visningsnavn string
param identifierUris string[] = []
param appRoller object[]
param eiere string[]

resource api 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: uniktNavn
  displayName: visningsnavn
  signInAudience: 'AzureADMyOrg'
  identifierUris: identifierUris
  api: {
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: []
  }
  appRoles: appRoller
  owners: {
    relationships: eiere
    relationshipSemantics: 'append'
  }
}

output appId string = api.appId

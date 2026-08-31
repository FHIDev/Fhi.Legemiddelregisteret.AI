// Én .Api-app-registrering (ressursen). Ligger i egen modul fordi identifierUris
// må settes i et andre pass — se kommentaren i kallende fil.
extension microsoftGraphV1

@description('uniqueName — idempotensnøkkelen. Immutable etter opprettelse.')
param uniktNavn string

@description('displayName, konvensjon: Fhi.<Tjeneste>.Api - <Miljø>')
param visningsnavn string

@description('Application ID URI-ene. Tomt i pass 1 (appId er ikke tildelt ennå), api://<appId> i pass 2.')
param identifierUris string[] = []

@description('Application-app-roller (m2m). allowedMemberTypes: Application -> havner i roles-claimet i client-credentials-token.')
param appRoller object[] = []

@description('Delegerte scopes (brukerinnlogging). Havner i scp-claimet i brukertoken.')
param delegerteScopes object[] = []

@description('Object-IDer (ikke appId) som skal stå som eiere av app-registreringen.')
param eiere string[] = []

resource api 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: uniktNavn
  displayName: visningsnavn
  signInAudience: 'AzureADMyOrg'
  identifierUris: identifierUris
  api: {
    // v2 => aud i access tokenet er ren appId-GUID UTEN api://-prefiks.
    // Backend setter ApiTokenValidation:Audience til nettopp den GUID-en.
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: delegerteScopes
  }
  appRoles: appRoller
  owners: {
    // NB: relationships er string[] med OBJECT-IDer i extension 1.0.0 — ikke [{ id: ... }],
    // som Learn-referansen viser. Målt med bicep build; objektformen gir BCP036.
    relationships: eiere
    // 'append' lar eiere satt utenfor malen stå. 'replace' ville fjernet dem.
    relationshipSemantics: 'append'
  }
}

output appId string = api.appId
output objectId string = api.id

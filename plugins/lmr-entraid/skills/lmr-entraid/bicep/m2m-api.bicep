/*
  VARIANT 1 av 4 — REN M2M, RESSURSSIDEN (.Api)

  Tjenesten eksponerer et API som andre LMR-tjenester kaller maskin-til-maskin med
  client credentials. Oppretter .Api-app-registreringen, dens service principal, og
  application-app-rollen kallerne får tildelt.

  Deploy:
    az deployment group create -g <rg> \
      --template-file m2m-api.bicep --parameters m2m-api.bicepparam

  Kjør scripts/sjekk-uniquename.sh FØR deploy, og scripts/verifiser.sh ETTER.
*/
extension microsoftGraphV1

@description('Tjenestenavn uten Fhi.-prefiks, f.eks. "Lmr.Grunndata".')
param tjenesteNavn string

@description('Miljø. M2M-konvensjonen i LMR er kun Test og Prod; AzureDev/QA deler Test-app-regen.')
@allowed(['Dev', 'Test', 'QA', 'Prod'])
param miljo string

@description('Stabil UUID for application-app-rollen. Generér ÉN gang og endre den ALDRI — rolletildelinger peker på den.')
param apiAppRoleId string

@description('App-rolleverdi. Konvensjon Fhi.<Tjeneste>.All. MÅ matche ApiTokenValidation:DefaultScope i backend.')
param apiAppRoleValue string

@description('Object-IDer (ikke appId) som skal eie app-registreringen. Uten eier kan ingen utvikler forvalte den etterpå.')
param eiere string[] = []

var visningsnavn = 'Fhi.${tjenesteNavn}.Api - ${miljo}'
var uniktNavn = toLower('fhi-${replace(tjenesteNavn, '.', '-')}-api-${miljo}')

var appRoller = [
  {
    id: apiAppRoleId
    // Application (ikke User) => dette er en application permission som gis med admin consent
    // og havner i 'roles'-claimet i et client-credentials-token.
    allowedMemberTypes: ['Application']
    displayName: apiAppRoleValue
    value: apiAppRoleValue
    description: 'Application-tilgang (client credentials) til ${tjenesteNavn}-API-et.'
    isEnabled: true
  }
]

/*
  OBS: TO PASS er nødvendig for identifierUris.

  appId tildeles av Graph først ved opprettelse, og Bicep tillater ikke at en ressurs
  refererer sin egen appId (BCP079 — målt). Pass 1 oppretter appen, pass 2 setter
  identifierUris = api://<appId>. Pass 2 er en FULLSTENDIG deklarasjon, så den er trygg
  uansett om extensionen har merge- eller erstatt-semantikk.

  uniqueName er lik i begge pass, så pass 2 oppdaterer den samme appen — den oppretter ikke en ny.
*/
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

// Service principal (Enterprise Application). Uten den kan ingen få tildelt app-rollen,
// og API-et kan ikke være mål for et token.
resource apiSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: apiPass2.outputs.appId
  owners: {
    relationships: eiere
    relationshipSemantics: 'append'
  }
}

@description('ApiTokenValidation:Audience i backend — ren GUID, UTEN api://-prefiks (fordi v2-tokens).')
output apiAppId string = apiPass2.outputs.appId

@description('Trengs som resourceId når en klient skal få admin consent mot dette API-et.')
output apiSpObjectId string = apiSp.id

@description('ApiTokenValidation:DefaultScope i backend.')
output defaultScope string = apiAppRoleValue

@description('Verdien kallende tjenester setter i Apis:<Klient>:Scope.')
output klientScope string = 'api://${apiPass2.outputs.appId}/.default'

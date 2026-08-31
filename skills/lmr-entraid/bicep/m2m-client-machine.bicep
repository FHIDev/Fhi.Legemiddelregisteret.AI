/*
  VARIANT 2 av 4 — REN M2M, KLIENTSIDEN (.Client.Machine)

  Tjenesten gjør utgående maskin-til-maskin-kall mot andre LMR-API-er. Autentiserer med
  sertifikat (client assertion / private_key_jwt). Oppretter klient-app-registreringen,
  dens service principal, og consent-tildelingen mot hvert callee-API.

  Deploy:
    az deployment group create -g <rg> \
      --template-file m2m-client-machine.bicep --parameters m2m-client-machine.bicepparam
*/
extension microsoftGraphV1

@description('Tjenestenavn uten Fhi.-prefiks, f.eks. "Lmr.Varseltjeneste".')
param tjenesteNavn string

@allowed(['Dev', 'Test', 'QA', 'Prod'])
param miljo string

@description('''
Det OFFENTLIGE sertifikatet (.cer, DER) som base64. Ikke en hemmelighet — skal committes.
  base64 -w0 <navn>.cer
Privatnøkkelen (PEM) settes som secret i miljøet, ALDRI her.
''')
param sertifikatBase64 string

@description('Object-IDer som skal eie app-registreringen.')
param eiere string[] = []

@description('''
API-ene denne klienten skal kunne kalle. Én oppføring per kant i kall-grafen:
  apiAppId     – callee-.Api sin appId (resourceAppId)
  apiSpObjectId– callee-.Api sin service principal object id (resourceId i tildelingen)
  appRoleId    – callee sin application-app-rolle (Fhi.Lmr.<Callee>.All)
''')
param callees object[]

@description('''
Om admin consent (appRoleAssignedTo) skal gis her. Application permissions kan app-eier gi selv.
Sett false hvis consent skal samlebestilles — da erklæres kun requiredResourceAccess.
''')
param giAdminConsent bool = true

var visningsnavn = 'Fhi.${tjenesteNavn}.Client.Machine - ${miljo}'
var uniktNavn = toLower('fhi-${replace(tjenesteNavn, '.', '-')}-client-machine-${miljo}')

resource klient 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: uniktNavn
  displayName: visningsnavn
  signInAudience: 'AzureADMyOrg'
  // Tom web-blokk: confidential client uten redirect-URI-er. Ingen brukerinnlogging her.
  web: {}
  keyCredentials: [
    {
      type: 'AsymmetricX509Cert'
      usage: 'Verify'
      key: sertifikatBase64
    }
  ]
  // type: 'Role' = application permission. 'Scope' ville vært delegert (på vegne av bruker).
  requiredResourceAccess: [
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
  owners: {
    relationships: eiere
    relationshipSemantics: 'append'
  }
}

resource klientSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: klient.appId
  owners: {
    relationships: eiere
    relationshipSemantics: 'append'
  }
}

/*
  Selve admin consent-en for application permissions: klientens SP tildeles callee-API-ets
  app-rolle. Uten denne er tokenet gyldig, men 'roles' er TOM — og callee svarer 403, ikke 401.
*/
resource consent 'Microsoft.Graph/appRoleAssignedTo@v1.0' = [
  for c in callees: if (giAdminConsent) {
    appRoleId: c.appRoleId
    principalId: klientSp.id
    resourceId: c.apiSpObjectId
  }
]

@description('OidcClients:EntraIdClient:ClientId i backend.')
output klientAppId string = klient.appId

@description('Trengs når denne klienten skal bli eier av sikkerhetsgrupper, eller få tildelt roller.')
output klientSpObjectId string = klientSp.id

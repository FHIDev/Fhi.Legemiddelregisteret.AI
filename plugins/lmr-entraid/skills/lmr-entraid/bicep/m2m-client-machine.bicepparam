using 'm2m-client-machine.bicep'

param tjenesteNavn = 'Lmr.MinTjeneste'
param miljo = 'Test'

// base64 av den OFFENTLIGE .cer-fila:  base64 -w0 MinTjeneste-Test.cer
// Offentlig sertifikat — ikke en hemmelighet, og skal committes.
param sertifikatBase64 = 'PLACEHOLDER_BASE64_AV_CER_FIL'

param eiere = [
  '00000000-0000-0000-0000-000000000000'
]

// Én oppføring per kant i kall-grafen. IDene hentes fra callee-tjenestens outputs
// (apiAppId / apiSpObjectId / defaultScope), eller fra kall-graf.md sitt ID-register.
param callees = [
  {
    navn: 'Grunndata'
    apiAppId: '00000000-0000-0000-0000-000000000000'
    apiSpObjectId: '00000000-0000-0000-0000-000000000000'
    appRoleId: '00000000-0000-0000-0000-000000000000'
  }
]

// Application permissions kan app-eier gi selv. Sett false hvis consent skal samlebestilles.
param giAdminConsent = true

using 'm2m-client-machine.bicep'

param tjenesteNavn = 'Lmr.MinTjeneste'
param miljo = 'Test'

// base64 av den OFFENTLIGE .cer-fila:  base64 -w0 MinTjeneste-Test.cer
// Offentlig sertifikat — ikke en hemmelighet, og skal committes.
param sertifikatBase64 = 'PLACEHOLDER_BASE64_AV_CER_FIL'

param eiere = [
  '00000000-0000-0000-0000-000000000000'
]

// Én oppføring per kant. IDene står i entraid/baseline/<callee>.json i Fhi.Lmr.AI:
// apiAppId = appId, apiSpObjectId = spObjectId, appRoleId = appRoller[].id.
param callees = [
  {
    navn: 'Grunndata'
    apiAppId: '00000000-0000-0000-0000-000000000000'
    apiSpObjectId: '00000000-0000-0000-0000-000000000000'
    appRoleId: '00000000-0000-0000-0000-000000000000'
  }
]

// false: tildelingene gis etterpå med entraid/scripts/legg-til-kant.sh (se malen for hvorfor).
param giAdminConsent = false

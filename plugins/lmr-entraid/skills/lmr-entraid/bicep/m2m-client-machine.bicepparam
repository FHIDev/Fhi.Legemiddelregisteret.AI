using 'm2m-client-machine.bicep'

param tjenesteNavn = 'Lmr.MinTjeneste'
param miljo = 'Test'

// base64 av den OFFENTLIGE .cer-fila:  base64 -w0 MinTjeneste-Test.cer
// Offentlig sertifikat — ikke en hemmelighet, og skal committes.
param sertifikatBase64 = 'PLACEHOLDER_BASE64_AV_CER_FIL'

// Object-IDer til de som skal eie app-registreringen. Finn din egen med:
//   az ad signed-in-user show --query id -o tsv
// ⚠️ I Prod skal fagpersonen også stå her: LMR Kari 'b53747d8-b2a0-4297-b430-5bfb3919f4bd',
// Grossiststatistikken Kristine 'af7e2f5c-58c1-4a7d-b675-d9a312bb431e'. Du fjerner deg selv
// etterpå — se «Rekkefølgen» steg 12 i SKILL.md.
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

using 'm2m-api.bicep'

// Eksempelverdier. Bytt til din tjeneste før bruk.
param tjenesteNavn = 'Lmr.MinTjeneste'
param miljo = 'Test'

// ⚠️ Generér ÉN gang: uuidgen (bash) eller [guid]::NewGuid() (PowerShell).
// Endres den, mister alle rolletildelinger referansen sin.
param apiAppRoleId = '00000000-0000-0000-0000-000000000000'

param apiAppRoleValue = 'Fhi.Lmr.MinTjeneste.All'

// Object-IDer til de som skal eie app-registreringen. Finn din egen med:
//   az ad signed-in-user show --query id -o tsv
// ⚠️ I Prod skal fagpersonen også stå her: LMR Kari 'b53747d8-b2a0-4297-b430-5bfb3919f4bd',
// Grossiststatistikken Kristine 'af7e2f5c-58c1-4a7d-b675-d9a312bb431e'. Du fjerner deg selv
// etterpå — se «Rekkefølgen» steg 12 i SKILL.md.
param eiere = [
  '00000000-0000-0000-0000-000000000000'
]

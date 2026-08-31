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
param eiere = [
  '00000000-0000-0000-0000-000000000000'
]

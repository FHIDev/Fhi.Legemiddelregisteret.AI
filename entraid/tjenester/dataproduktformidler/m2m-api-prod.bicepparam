using 'm2m-api.bicep'

param tjenesteNavn = 'Lmr.DataproduktFormidler'
param miljo = 'Prod'
param apiAppRoleId = 'dab6461f-9c64-486c-98fb-56fa0acb8b2a'
param apiAppRoleValue = 'Fhi.Lmr.DataproduktFormidler.All'
// Prod: fagpersonen (Kari) eier permanent. Utvikleren som oppretter fjerner seg selv etterpå
// (SKILL.md steg 12).
param eiere = [
  '5a97c6da-0282-47e1-ab1b-779a656ad988'
  'b53747d8-b2a0-4297-b430-5bfb3919f4bd'
]

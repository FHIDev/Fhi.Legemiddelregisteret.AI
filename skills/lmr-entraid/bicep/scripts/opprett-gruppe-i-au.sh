#!/usr/bin/env bash
#
# opprett-gruppe-i-au.sh — DEN ENE TINGEN BICEP IKKE KAN GJØRE
#
# Graph Bicep-extensionen har ingen Microsoft.Graph/administrativeUnits, og rettighetene
# rundt AU-er er asymmetriske:
#
#   Opprette NY gruppe inne i AU-en    →  Groups Administrator SCOPED TIL AU-en   (det du har)
#   Flytte EKSISTERENDE gruppe inn     →  Privileged Role Administrator           (NHN-bestilling)
#
# Lar du Bicep opprette gruppa, havner den i katalogroten, og å rette det opp krever en
# NHN-bestilling per gruppe. Derfor opprettes rollegrupper ALLTID direkte i AU-en, her.
#
# Terraform har nøyaktig samme grense — modules/user-app-regs shell-er ut til det samme
# endepunktet fra en null_resource. Ingen av verktøyene kan gjøre dette deklarativt.
#
# Scriptet er idempotent: finnes gruppa allerede, settes bare uniqueName (om det mangler).
#
# Bruk:
#   ./opprett-gruppe-i-au.sh "A-FHI-App-Lmr-Test-Godkjenn" <clientMachineSpObjectId>
#
set -uo pipefail

FHI_TENANT="54475f80-1baa-4ea9-9185-c0de5cc603fe"
# AU-Legemiddelregisteret
AU_ID="a563113b-80b4-4187-a938-a8d97992c3ce"

if [ "$#" -ne 2 ]; then
  echo "Bruk: $0 <gruppens displayName> <eier-SP-objectId>" >&2
  echo "  Eier bør være Client.Machine sin service principal, slik at appen kan" >&2
  echo "  administrere medlemmer via Graph." >&2
  exit 64
fi

visningsnavn="$1"
eier_sp="$2"
# uniqueName er nøkkelen Bicep bruker for å referere gruppa med 'existing'.
unikt_navn="$(printf '%s' "$visningsnavn" | tr '[:upper:]' '[:lower:]')"
mail_nickname="$(printf '%s' "$unikt_navn" | tr -d '-')"

aktiv_tenant="$(az account show --query tenantId -o tsv 2>/dev/null || true)"
if [ "$aktiv_tenant" != "$FHI_TENANT" ]; then
  echo "FEIL: az står på tenant '${aktiv_tenant:-<ingen>}', ikke FHI ($FHI_TENANT)." >&2
  echo "      Fiks: az account set --subscription FHI-LMR-Dev" >&2
  exit 1
fi

eksisterende="$(az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/groups?\$filter=displayName eq '${visningsnavn}'&\$select=id,uniqueName" \
  2>/dev/null | jq -r '.value[0].id // empty' || true)"

if [ -n "$eksisterende" ]; then
  echo "Gruppa finnes allerede: $visningsnavn ($eksisterende)"
  gruppe_id="$eksisterende"
else
  # ⚠️ POST mot .../administrativeUnits/{au}/members OPPRETTER gruppa inne i AU-en.
  # Bruk aldri .../members/$ref her — den er for å flytte en eksisterende gruppe inn,
  # og krever Privileged Role Administrator.
  #
  # @odata.type MÅ med, ellers svarer Graph 400.
  body="$(jq -n \
    --arg navn "$visningsnavn" \
    --arg nick "$mail_nickname" \
    --arg unikt "$unikt_navn" \
    --arg eier "https://graph.microsoft.com/v1.0/servicePrincipals/${eier_sp}" \
    '{
      "@odata.type": "#microsoft.graph.group",
      displayName: $navn,
      description: "Rolletilgang for LMR. Medlemskap gir rollen i roles-claimet.",
      securityEnabled: true,
      mailEnabled: false,
      mailNickname: $nick,
      uniqueName: $unikt,
      "owners@odata.bind": [$eier]
    }')"

  svar="$(az rest --method POST \
    --uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits/${AU_ID}/members" \
    --headers "Content-Type=application/json" \
    --body "$body" 2>&1)"

  gruppe_id="$(printf '%s' "$svar" | jq -r '.id // empty' 2>/dev/null || true)"
  if [ -z "$gruppe_id" ]; then
    echo "FEIL: kunne ikke opprette gruppa." >&2
    printf '%s\n' "$svar" >&2
    exit 1
  fi
  echo "Opprettet gruppe i AU-Legemiddelregisteret: $visningsnavn ($gruppe_id)"
fi

# Etterfyll uniqueName hvis gruppa er eldre og mangler den. Immutable — settes kun én gang.
naavaerende_unikt="$(az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/groups/${gruppe_id}?\$select=uniqueName" \
  2>/dev/null | jq -r '.uniqueName // empty' || true)"

if [ -z "$naavaerende_unikt" ]; then
  az rest --method PATCH \
    --uri "https://graph.microsoft.com/v1.0/groups/${gruppe_id}" \
    --headers "Content-Type=application/json" \
    --body "$(jq -n --arg u "$unikt_navn" '{uniqueName: $u}')" >/dev/null
  echo "Satt uniqueName = $unikt_navn"
else
  echo "uniqueName er satt: $naavaerende_unikt"
fi

# ⚠️ VERIFISER EIERSKAP MED \$expand. GET /groups/{id}/owners returnerer IKKE
# service-principal-eiere — den svarer [] selv når eieren faktisk er satt.
eiere="$(az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/groups/${gruppe_id}?\$expand=owners" \
  2>/dev/null | jq -r '[.owners[]?.id] | join(" ")' || true)"

if printf '%s' "$eiere" | grep -q "$eier_sp"; then
  echo "OK: $eier_sp er eier av gruppa."
else
  echo "⚠️  ADVARSEL: $eier_sp står IKKE som eier. Eiere nå: ${eiere:-<ingen>}" >&2
  echo "    Uten eierskap kan ikke appen legge til medlemmer via Graph." >&2
  exit 1
fi

echo
echo "Bruk denne i .bicepparam:  gruppeUniktNavn: '${unikt_navn}'"
echo
echo "NB: eierskap gir POST av medlemmer, men IKKE DELETE. Skal appen kunne FJERNE"
echo "    medlemmer, trengs rollen Groups Administrator scoped til AU-en — se"
echo "    references/NHN-OG-ADMIN.md."

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
# Finnes gruppa allerede, endres ingenting: scriptet kontrollerer bare at den ligger i riktig AU
# og har riktig eier, og skriver ut object ID-en malen trenger (gruppeObjektId).
#
# ⚠️ Eieren kan legge til medlemmer og dermed gi tilgang. Eier skal være Client.Machine til appen
# som ADMINISTRERER medlemskapet (i LMR: Kontroll), aldri en app som bare leser rollene fra tokenet.
# For en NY app med NYE grupper: deploy appen, kjør dette scriptet, og gi tildelingene etterpå. De felles LMR-rollegruppene
# (A-FHI-App-Lmr-<Miljø>-<Rolle>) finnes fra før — der trengs bare object ID-en.
#
# Bruk:
#   ./opprett-gruppe-i-au.sh "A-FHI-App-Lmr-Test-Godkjenn" <clientMachineSpObjectId> [au-objectId]
#
# AU-en er valgfri og utledes av gruppenavnet. Hvert fagområde har én AU for prod og én for
# øvrige miljøer, slik at bare prod-applikasjonen kan endre hvem som har tilgang i prod:
#   A-FHI-App-Lmr-Prod-*                          -> AU-Legemiddelregisteret-Prod
#   A-FHI-App-Lmr-{Dev,Test,QA}-*                 -> AU-Legemiddelregisteret-Test
#   A-FHI-App-Grossiststatistikken-Prod-*         -> AU-Grossiststatistikken-Prod
#   A-FHI-App-Grossiststatistikken-{Sandbox,Test}-* -> AU-Grossiststatistikken-Test
# Andre navn krever AU som tredje argument — scriptet gjetter ikke, fordi en gruppe i feil AU
# bare kan flyttes med en NHN-bestilling.
#
set -uo pipefail

FHI_TENANT="54475f80-1baa-4ea9-9185-c0de5cc603fe"
AU_LMR_PROD="a563113b-80b4-4187-a938-a8d97992c3ce"      # AU-Legemiddelregisteret-Prod
AU_LMR_TEST="7aa36d85-8358-42f1-96fb-d511f49b40f2"      # AU-Legemiddelregisteret-Test
AU_GROSSIST_PROD="94d49e82-a17c-458f-93b1-5bab0c2fcfb2" # AU-Grossiststatistikken-Prod
AU_GROSSIST_TEST="60f3749d-721f-4b0c-8793-90949662ffb9" # AU-Grossiststatistikken-Test
GRAPH="https://graph.microsoft.com/v1.0"

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Bruk: $0 <gruppens displayName> <eier-SP-objectId> [au-objectId]" >&2
  echo "  Eier er Client.Machine-SP-en til appen som administrerer medlemskapet" >&2
  echo "  (i LMR: Kontroll), ikke en app som bare leser rollene fra tokenet." >&2
  echo "  AU utledes av miljøet i gruppenavnet; oppgi den eksplisitt for andre navn." >&2
  exit 64
fi

visningsnavn="$1"
eier_sp="$2"
if [ "$#" -eq 3 ]; then
  AU_ID="$3"
else
  case "$visningsnavn" in
    A-FHI-App-Lmr-Prod-*)                                   AU_ID="$AU_LMR_PROD" ;;
    A-FHI-App-Lmr-Dev-*|A-FHI-App-Lmr-Test-*|A-FHI-App-Lmr-QA-*) AU_ID="$AU_LMR_TEST" ;;
    A-FHI-App-Grossiststatistikken-Prod-*)                  AU_ID="$AU_GROSSIST_PROD" ;;
    A-FHI-App-Grossiststatistikken-Sandbox-*|A-FHI-App-Grossiststatistikken-Test-*) AU_ID="$AU_GROSSIST_TEST" ;;
    *)
      echo "FEIL: kan ikke utlede AU av '$visningsnavn'. Oppgi AU-ens object ID som tredje argument." >&2
      exit 64 ;;
  esac
fi
echo "AU: $AU_ID"
unikt_navn="$(printf '%s' "$visningsnavn" | tr '[:upper:]' '[:lower:]')"
mail_nickname="$(printf '%s' "$unikt_navn" | tr -d '-')"

aktiv_tenant="$(az account show --query tenantId -o tsv 2>/dev/null | tr -d '\r' || true)"
if [ "$aktiv_tenant" != "$FHI_TENANT" ]; then
  echo "FEIL: az står på tenant '${aktiv_tenant:-<ingen>}', ikke FHI ($FHI_TENANT)." >&2
  echo "      Fiks: az account set --subscription FHI-LMR-Dev" >&2
  exit 1
fi

# stderr holdes utenfor svaret: az kan skrive advarsler der også når kallet lykkes, og blandet
# inn i JSON-en ville de gjort svaret uleselig.
feilfil="$(mktemp)"
trap 'rm -f "$feilfil"' EXIT

# Et feilet oppslag må STOPPE scriptet. Tolkes det som «finnes ikke», opprettes en duplikat.
if ! oppslag="$(az rest --method GET \
    --uri "$GRAPH/groups?\$filter=displayName eq '${visningsnavn}'&\$select=id" 2>"$feilfil")"; then
  echo "FEIL: oppslaget av gruppa feilet. Ingenting er gjort." >&2
  cat "$feilfil" >&2
  exit 1
fi
# Oppretting er bare lov når svaret er bekreftet som en liste. Alt annet stopper.
if ! antall="$(printf '%s' "$oppslag" | jq -e '.value | if type == "array" then length else error("ikke en liste") end' 2>/dev/null)"; then
  echo "FEIL: uventet svar fra oppslaget av gruppa. Ingenting er gjort." >&2
  exit 1
fi
if [ "$antall" -gt 1 ]; then
  echo "FEIL: $antall grupper heter '$visningsnavn'. Rydd opp før du fortsetter." >&2
  exit 1
fi
eksisterende="$(printf '%s' "$oppslag" | jq -r '.value[0].id // empty')"

if [ -n "$eksisterende" ]; then
  gruppe_id="$eksisterende"
  echo "Gruppa finnes allerede: $visningsnavn ($gruppe_id)"
  if ! au_svar="$(az rest --method GET \
      --uri "$GRAPH/groups/${gruppe_id}/memberOf/microsoft.graph.administrativeUnit?\$select=id" 2>"$feilfil")"; then
    echo "FEIL: klarte ikke å slå opp AU-medlemskapet: $(cat "$feilfil")" >&2
    exit 1
  fi
  if [ "$(printf '%s' "$au_svar" | jq -r --arg au "$AU_ID" 'any(.value[]; .id == $au)' 2>/dev/null)" != "true" ]; then
    echo "FEIL: gruppa ligger ikke i AU $AU_ID. Å flytte den krever en NHN-bestilling." >&2
    exit 1
  fi
  echo "Ligger i riktig AU."
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
    --arg eier "$GRAPH/servicePrincipals/${eier_sp}" \
    '{
      "@odata.type": "#microsoft.graph.group",
      displayName: $navn,
      description: "Rolletilgang. Medlemskap gir rollen i roles-claimet.",
      securityEnabled: true,
      mailEnabled: false,
      mailNickname: $nick,
      uniqueName: $unikt,
      "owners@odata.bind": [$eier]
    }')"

  svar="$(az rest --method POST \
    --uri "$GRAPH/directory/administrativeUnits/${AU_ID}/members" \
    --headers "Content-Type=application/json" \
    --body "$body" 2>"$feilfil")"

  gruppe_id="$(printf '%s' "$svar" | jq -r '.id // empty' 2>/dev/null || true)"
  if [ -z "$gruppe_id" ]; then
    echo "FEIL: kunne ikke opprette gruppa." >&2
    cat "$feilfil" >&2
    exit 1
  fi
  echo "Opprettet gruppe i AU $AU_ID: $visningsnavn ($gruppe_id)"
fi

# ⚠️ VERIFISER EIERSKAP MED $expand. GET /groups/{id}/owners returnerer IKKE
# service-principal-eiere — den svarer [] selv når eieren faktisk er satt.
eiere="$(az rest --method GET \
  --uri "$GRAPH/groups/${gruppe_id}?\$expand=owners" \
  2>/dev/null | jq -r '[.owners[]?.id] | join(" ")' || true)"

if printf '%s' "$eiere" | grep -q "$eier_sp"; then
  echo "OK: $eier_sp er eier av gruppa."
else
  echo "⚠️  $eier_sp står IKKE som eier. Eiere nå: ${eiere:-<ingen>}" >&2
  echo "    Uten eierskap (eller Groups Administrator på AU-en) kan ikke appen legge til" >&2
  echo "    medlemmer via Graph. En felles gruppe kan ha flere eiere:" >&2
  echo "    POST $GRAPH/groups/${gruppe_id}/owners/\$ref" >&2
  exit 1
fi

echo
echo "Bruk denne i .bicepparam:  gruppeObjektId: '${gruppe_id}'"
echo
echo "NB: eierskap gir POST av medlemmer, men IKKE DELETE. Skal appen kunne FJERNE"
echo "    medlemmer, trengs rollen Groups Administrator scoped til AU-en — se"
echo "    references/NHN-OG-ADMIN.md."

#!/usr/bin/env bash
#
# verifiser.sh — KJØR ETTER DEPLOY, og senere for å oppdage drift
#
# Graph Bicep-extensionen har ingen what-if, og en re-deploy retter ikke opp drift: er malen
# uendret hopper ARM over ressursen, og properties du har tatt ut av malen blir stående.
# Dette skriptet er derfor den eneste drift-deteksjonen du har - det sammenligner mot FAKTISK
# tilstand i Entra.
#
# Bruk:
#   ./verifiser.sh <uniqueName>                    # skriv baseline til stdout
#   ./verifiser.sh <uniqueName> baseline.json      # sammenlign mot baseline, exit 1 ved avvik
#
# Typisk flyt (fasiten ligger i entraid/baseline/ i Fhi.Lmr.AI):
#   ./verifiser.sh fhi-lmr-mintjeneste-api-test > ny.json && mv ny.json entraid/baseline/fhi-lmr-mintjeneste-api-test.json
#   ./verifiser.sh fhi-lmr-mintjeneste-api-test entraid/baseline/fhi-lmr-mintjeneste-api-test.json
#
# Baselinen inneholder bare ID-er og verdier fra app-registreringen, ingen personnavn. Navn kommer
# ut av az med ødelagte norske tegn på enkelte maskiner, og ville gitt falsk drift.
#
# Feiler noe underveis (oppslag, SP mangler, jq), avslutter skriptet med exit 1 og skriver
# INGENTING til stdout — en halv baseline er verre enn ingen.
#
set -uo pipefail

FHI_TENANT="54475f80-1baa-4ea9-9185-c0de5cc603fe"
GRAPH="https://graph.microsoft.com/v1.0"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Bruk: $0 <uniqueName> [baseline.json]" >&2
  exit 64
fi

unikt_navn="$1"
baseline="${2:-}"

tmp="$(mktemp)"; tmpdiff="$(mktemp)"; feilfil="$(mktemp)"
trap 'rm -f "$tmp" "$tmpdiff" "$feilfil"' EXIT

feil() { echo "FEIL: $*" >&2; exit 1; }

aktiv_tenant="$(az account show --query tenantId -o tsv 2>/dev/null | tr -d '\r' || true)"
if [ "$aktiv_tenant" != "$FHI_TENANT" ]; then
  echo "FEIL: az står på tenant '${aktiv_tenant:-<ingen>}', ikke FHI ($FHI_TENANT)." >&2
  echo "      Fiks: az account set --subscription FHI-LMR-Dev" >&2
  exit 1
fi

# Henter en liste fra Graph og følger @odata.nextLink, slik at lister over 100 elementer
# (f.eks. rolletildelinger) ikke blir avkuttet.
hent_alle() {
  local uri="$1" side alle='[]'
  while [ -n "$uri" ]; do
    # stderr holdes utenfor: az kan skrive advarsler der også når kallet lykkes.
    side="$(az rest --method GET --uri "$uri" 2>"$feilfil")" || { cat "$feilfil" >&2; return 1; }
    alle="$(jq -c --argjson a "$alle" '$a + .value' <<<"$side")" || return 1
    uri="$(jq -r '."@odata.nextLink" // empty' <<<"$side")"
  done
  printf '%s' "$alle"
}

app="$(az rest --method GET \
  --uri "$GRAPH/applications(uniqueName='${unikt_navn}')?\$expand=owners" 2>"$feilfil")" \
  || feil "fant ingen app-registrering med uniqueName '${unikt_navn}': $(head -c 300 "$feilfil")"

app_id="$(jq -r '.appId // empty' <<<"$app")"
[ -n "$app_id" ] || feil "svaret for '${unikt_navn}' mangler appId."

sp_object_id="$(az rest --method GET \
  --uri "$GRAPH/servicePrincipals(appId='${app_id}')?\$select=id" 2>/dev/null | jq -r '.id // empty')"
[ -n "$sp_object_id" ] || feil "fant ingen service principal for appId $app_id. Rett etter opprettelse kan det ta et minutt; kjør på nytt."

# Tildelinger på denne SP-en som RESSURS (consent gitt til kallere, og grupper → roller).
tildelt_til="$(hent_alle "$GRAPH/servicePrincipals/${sp_object_id}/appRoleAssignedTo?\$select=appRoleId,principalId,principalType")" \
  || feil "klarte ikke å hente appRoleAssignedTo."
# Tildelinger denne SP-en HAR FÅTT som kaller (consent for dens egne m2m-kanter).
har_faatt="$(hent_alle "$GRAPH/servicePrincipals/${sp_object_id}/appRoleAssignments?\$select=appRoleId,resourceId")" \
  || feil "klarte ikke å hente appRoleAssignments."

# ⚠️ owners hentes med $expand. GET /applications/{id}/owners returnerer IKKE
# service-principal-eiere — den ser tom ut selv når eieren er satt.
jq --arg sp "$sp_object_id" --argjson tildeltTil "$tildelt_til" --argjson harFaatt "$har_faatt" '{
  uniqueName,
  displayName,
  appId,
  spObjectId: $sp,
  signInAudience,
  identifierUris: (.identifierUris // [] | sort),
  requestedAccessTokenVersion: (.api.requestedAccessTokenVersion),
  delegerteScopes: [.api.oauth2PermissionScopes[]? | {id, value, type, isEnabled}] | sort_by(.value),
  appRoller: [.appRoles[]? | {id, value, allowedMemberTypes: (.allowedMemberTypes | sort), isEnabled}] | sort_by(.value),
  redirectUrisWeb: (.web.redirectUris // [] | sort),
  redirectUrisSpa: (.spa.redirectUris // [] | sort),
  logoutUrl: (.web.logoutUrl // null),
  sertifikatThumbprints: [.keyCredentials[]? | .customKeyIdentifier] | sort,
  requiredResourceAccess: [.requiredResourceAccess[]? | {
    resourceAppId,
    resourceAccess: [.resourceAccess[] | {id, type}] | sort_by(.id)
  }] | sort_by(.resourceAppId),
  eiere: [.owners[]? | .id] | sort,
  appRoleAssignedTo: ($tildeltTil | map({appRoleId, principalId, principalType}) | sort_by(.appRoleId, .principalId)),
  appRoleAssignments: ($harFaatt | map({appRoleId, resourceId}) | sort_by(.resourceId, .appRoleId))
}' <<<"$app" > "$tmp" || feil "jq klarte ikke å bygge baselinen."

[ -s "$tmp" ] || feil "baselinen ble tom."

if [ -z "$baseline" ]; then
  cat "$tmp"
  exit 0
fi

[ -f "$baseline" ] || feil "baseline-fila '$baseline' finnes ikke."

if diff -u "$baseline" "$tmp" > "$tmpdiff"; then
  echo "OK: ingen avvik mellom Entra og baseline for '${unikt_navn}'."
  exit 0
else
  echo "⚠️  AVVIK mellom baseline og faktisk tilstand i Entra for '${unikt_navn}':"
  echo "    (- = baseline, + = slik det faktisk er nå)"
  echo
  cat "$tmpdiff"
  exit 1
fi

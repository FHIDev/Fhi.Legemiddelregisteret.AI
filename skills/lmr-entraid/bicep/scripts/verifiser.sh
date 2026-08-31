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
# Typisk flyt:
#   ./verifiser.sh fhi-lmr-mintjeneste-api-test > baseline/api-test.json   # rett etter deploy
#   ./verifiser.sh fhi-lmr-mintjeneste-api-test baseline/api-test.json     # senere, i CI
#
set -uo pipefail

FHI_TENANT="54475f80-1baa-4ea9-9185-c0de5cc603fe"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Bruk: $0 <uniqueName> [baseline.json]" >&2
  exit 64
fi

unikt_navn="$1"
baseline="${2:-}"

aktiv_tenant="$(az account show --query tenantId -o tsv 2>/dev/null || true)"
if [ "$aktiv_tenant" != "$FHI_TENANT" ]; then
  echo "FEIL: az står på tenant '${aktiv_tenant:-<ingen>}', ikke FHI ($FHI_TENANT)." >&2
  echo "      Fiks: az account set --subscription FHI-LMR-Dev" >&2
  exit 1
fi

app="$(az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/applications(uniqueName='${unikt_navn}')?\$expand=owners" \
  2>/dev/null || true)"

if [ -z "$(printf '%s' "$app" | jq -r '.appId // empty' 2>/dev/null || true)" ]; then
  echo "FEIL: fant ingen app-registrering med uniqueName '${unikt_navn}'." >&2
  exit 1
fi

app_id="$(printf '%s' "$app" | jq -r '.appId')"
sp_object_id="$(az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals(appId='${app_id}')?\$select=id" \
  2>/dev/null | jq -r '.id // empty' || true)"

# App-rolletildelinger på SP-en (admin consent for application permissions, og gruppe→rolle).
tildelinger='[]'
if [ -n "$sp_object_id" ]; then
  tildelinger="$(az rest --method GET \
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/${sp_object_id}/appRoleAssignedTo" \
    2>/dev/null | jq '[.value[] | {appRoleId, principalId, principalDisplayName}]' || echo '[]')"
fi

# Normaliser: sorter alt som er en mengde, og drop felter som endrer seg av seg selv
# (createdDateTime, @odata.context osv.). Uten sortering gir Graph tilfeldig rekkefølge,
# og da ville diffen slått ut på ingenting.
#
# ⚠️ owners hentes med $expand. GET /applications/{id}/owners returnerer IKKE
# service-principal-eiere — den ser tom ut selv når eieren er satt.
printf '%s' "$app" | jq --argjson tildelinger "$tildelinger" '{
  uniqueName,
  displayName,
  appId,
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
  appRoleAssignedTo: ($tildelinger | sort_by(.appRoleId, .principalId))
}' > /tmp/verifiser-$$.json

if [ -z "$baseline" ]; then
  cat /tmp/verifiser-$$.json
  rm -f /tmp/verifiser-$$.json
  exit 0
fi

if [ ! -f "$baseline" ]; then
  echo "FEIL: baseline-fila '$baseline' finnes ikke." >&2
  rm -f /tmp/verifiser-$$.json
  exit 1
fi

if diff -u "$baseline" /tmp/verifiser-$$.json > /tmp/verifiser-diff-$$.txt; then
  echo "OK: ingen avvik mellom Entra og baseline for '${unikt_navn}'."
  rm -f /tmp/verifiser-$$.json /tmp/verifiser-diff-$$.txt
  exit 0
else
  echo "⚠️  AVVIK mellom baseline og faktisk tilstand i Entra for '${unikt_navn}':"
  echo "    (- = baseline, + = slik det faktisk er nå)"
  echo
  cat /tmp/verifiser-diff-$$.txt
  rm -f /tmp/verifiser-$$.json /tmp/verifiser-diff-$$.txt
  exit 1
fi

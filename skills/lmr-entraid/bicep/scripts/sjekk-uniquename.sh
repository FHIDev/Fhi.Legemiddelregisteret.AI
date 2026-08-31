#!/usr/bin/env bash
#
# sjekk-uniquename.sh — KJØR FØR DEPLOY
#
# Graph Bicep-extensionen har ingen what-if. Den viktigste feilen den ville fanget er en
# skrivefeil i uniqueName: da OPPRETTER deployen en helt ny app-registrering i stedet for å
# oppdatere den eksisterende — stille, med ny appId, og du oppdager det først etterpå.
#
# Dette scriptet slår opp hver uniqueName og sier om deployen kommer til å OPPDATERE eller
# OPPRETTE. Les output før du kjører az deployment.
#
# Bruk:
#   ./sjekk-uniquename.sh fhi-lmr-mintjeneste-api-test fhi-lmr-mintjeneste-client-machine-test
#
set -uo pipefail

FHI_TENANT="54475f80-1baa-4ea9-9185-c0de5cc603fe"

if [ "$#" -eq 0 ]; then
  echo "Bruk: $0 <uniqueName> [<uniqueName> ...]" >&2
  exit 64
fi

# ⚠️ az faller jevnlig tilbake til en annen tenant. Symptomet er at ALT ser ut til å mangle,
# som leser som «app-registreringene er slettet». Sperr for det med én gang.
aktiv_tenant="$(az account show --query tenantId -o tsv 2>/dev/null || true)"
if [ "$aktiv_tenant" != "$FHI_TENANT" ]; then
  echo "FEIL: az står på tenant '${aktiv_tenant:-<ingen>}', ikke FHI ($FHI_TENANT)." >&2
  echo "      Fiks: az account set --subscription FHI-LMR-Dev" >&2
  exit 1
fi

antall_nye=0

for navn in "$@"; do
  # Alternate-key-oppslag. uniqueName er nøkkelen extensionen bruker til upsert.
  svar="$(az rest --method GET \
    --uri "https://graph.microsoft.com/v1.0/applications(uniqueName='${navn}')?\$select=appId,displayName,id" \
    2>/dev/null || true)"

  app_id="$(printf '%s' "$svar" | jq -r '.appId // empty' 2>/dev/null || true)"

  if [ -n "$app_id" ]; then
    visningsnavn="$(printf '%s' "$svar" | jq -r '.displayName // empty')"
    printf 'OPPDATERER  %-50s appId=%s  (%s)\n' "$navn" "$app_id" "$visningsnavn"
  else
    printf 'OPPRETTER   %-50s <finnes ikke>\n' "$navn"
    antall_nye=$((antall_nye + 1))
  fi
done

echo
if [ "$antall_nye" -gt 0 ]; then
  echo "⚠️  $antall_nye uniqueName finnes ikke og vil bli OPPRETTET som nye app-registreringer."
  echo "    Er dette en førstegangs-provisjonering? Da er det riktig."
  echo "    Skulle det vært en oppdatering? Da er det en SKRIVEFEIL i uniqueName — stopp her."
  echo
  echo "    NB: uniqueName er immutable. Oppretter du feil, må appen slettes OG tømmes fra"
  echo "    papirkurven (directory/deletedItems) før navnet kan brukes på nytt."
else
  echo "Alle uniqueName finnes. Deployen blir en ren oppdatering."
fi

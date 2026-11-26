#!/usr/bin/env bash
#
# sjekk-uniquename.sh — KJØR FØR DEPLOY
#
# Bicep-malene brukes BARE til å opprette nye app-registreringer. En deploy mot en som finnes,
# setter de deklarerte propertyene til malens verdi, og en deklarert liste (kanter, roller,
# redirect-URI-er) kan bli erstattet. Graph Bicep-extensionen har dessuten ingen what-if.
#
# Dette scriptet slår opp hver uniqueName og STOPPER (exit 2) hvis noen av dem finnes.
# Går det gjennom (exit 0), vil deployen bare opprette. Kjør det rett før az deployment.
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
antall_finnes=0
antall_feil=0

# stderr holdes utenfor svaret: az kan skrive advarsler der også når kallet lykkes.
feilfil="$(mktemp)"
trap 'rm -f "$feilfil"' EXIT

for navn in "$@"; do
  # Oppslag på uniqueName. Bare et bekreftet 404 (Request_ResourceNotFound) betyr «finnes ikke».
  # Alle andre feil — utløpt innlogging, nettverk, 403, throttling — må STOPPE, ellers ville en
  # app-registrering som finnes blitt rapportert som ny, og deployen fått grønt lys.
  if svar="$(az rest --method GET \
      --uri "https://graph.microsoft.com/v1.0/applications(uniqueName='${navn}')?\$select=appId,displayName,id" 2>"$feilfil")"; then
    app_id="$(printf '%s' "$svar" | jq -r '.appId // empty' 2>/dev/null || true)"
    visningsnavn="$(printf '%s' "$svar" | jq -r '.displayName // empty' 2>/dev/null || true)"
    printf 'FINNES      %-50s appId=%s  (%s)\n' "$navn" "${app_id:-?}" "$visningsnavn"
    antall_finnes=$((antall_finnes + 1))
  elif grep -q 'Request_ResourceNotFound' "$feilfil"; then
    printf 'OPPRETTER   %-50s <finnes ikke>\n' "$navn"
    antall_nye=$((antall_nye + 1))
  else
    printf 'FEIL        %-50s oppslaget feilet: %s\n' "$navn" "$(head -c 300 "$feilfil")"
    antall_feil=$((antall_feil + 1))
  fi
done

echo
if [ "$antall_feil" -gt 0 ]; then
  echo "⛔ STOPP: $antall_feil oppslag feilet, så det er ukjent om navnene finnes. IKKE DEPLOY."
  echo "   Rett feilen (az login, nettverk, tilgang) og kjør på nytt."
  exit 1
fi
if [ "$antall_finnes" -gt 0 ]; then
  # Bicep-malene brukes BARE til å opprette. En deploy mot en app-registrering som finnes, setter
  # de deklarerte propertyene til malens verdi, og en deklarert liste kan bli erstattet.
  echo "⛔ STOPP: $antall_finnes uniqueName finnes allerede. IKKE DEPLOY."
  echo "   Bicep-malene brukes bare til å OPPRETTE nye app-registreringer. En deploy mot en"
  echo "   eksisterende kan overskrive verdier og erstatte lister som kantene."
  echo "   Ny kant på en eksisterende klient: entraid/scripts/legg-til-kant.sh i Fhi.Lmr.AI."
  echo "   Andre endringer på en eksisterende app-registrering gjøres manuelt, med verifiser.sh"
  echo "   før og etter."
  exit 2
fi

echo "Ingen av navnene finnes. Deployen OPPRETTER $antall_nye nye app-registreringer."
echo "Er det en skrivefeil i et navn, oppretter du en app-registrering du ikke ville ha:"
echo "uniqueName er immutable, og en feil må slettes OG tømmes fra papirkurven"
echo "(directory/deletedItems) før navnet kan brukes på nytt."

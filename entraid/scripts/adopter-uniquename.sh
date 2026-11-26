#!/usr/bin/env bash
#
# adopter-uniquename.sh — gir eksisterende app-registreringer en uniqueName
#
# App-registreringene som ble laget før Bicep har ingen uniqueName. Uten den kan verken
# verifiser.sh eller en Bicep-mal finne dem. Dette skriptet setter den én gang, ut fra
# mappingfila adopsjon-uniquename.tsv.
#
# ⚠️ uniqueName er IMMUTABLE. Er navnet feil, er det feil for alltid — eneste vei ut er å
# slette app-registreringen, som gir ny appId. Les tørrkjøringen før du bruker --utfor.
#
# Endringen påvirker ikke appId, tokens, consent, sertifikater eller innlogging. Den gir
# bare app-registreringen en alternativ nøkkel.
#
# Bruk:
#   ./adopter-uniquename.sh [--utfor] [mappingfil] [filter-regex]
#
#   ./adopter-uniquename.sh                                   # tørrkjøring, alle rader
#   ./adopter-uniquename.sh ../adopsjon-uniquename.tsv 'logging-api-test$'   # tørrkjøring, én rad
#   ./adopter-uniquename.sh --utfor ../adopsjon-uniquename.tsv 'logging-api-test$'
#
# Filteret matches mot foreslått uniqueName. Start med én app-registrering i Test.
#
# Mappingfila er tab-separert med header:
#   displayName  objectId  appId  foreslattUniqueName  status
#
set -uo pipefail

FHI_TENANT="54475f80-1baa-4ea9-9185-c0de5cc603fe"
GRAPH="https://graph.microsoft.com/v1.0"

utfor=false
if [ "${1:-}" = "--utfor" ]; then
  utfor=true
  shift
fi

skriptkatalog="$(cd "$(dirname "$0")" && pwd)"
mappingfil="${1:-$skriptkatalog/../adopsjon-uniquename.tsv}"
filter="${2:-.}"

if [ ! -f "$mappingfil" ]; then
  echo "FEIL: finner ikke mappingfila '$mappingfil'." >&2
  exit 64
fi

command -v jq >/dev/null || { echo "FEIL: jq er ikke installert." >&2; exit 1; }

# ⚠️ az faller jevnlig tilbake til en annen tenant. Da ser alt ut til å mangle.
aktiv_tenant="$(az account show --query tenantId -o tsv 2>/dev/null | tr -d '\r' || true)"
if [ "$aktiv_tenant" != "$FHI_TENANT" ]; then
  echo "FEIL: az står på tenant '${aktiv_tenant:-<ingen>}', ikke FHI ($FHI_TENANT)." >&2
  echo "      Fiks: az account set --subscription FHI-LMR-Dev" >&2
  exit 1
fi

if $utfor; then
  echo "MODUS: UTFØR — uniqueName blir satt og kan ikke endres etterpå."
else
  echo "MODUS: tørrkjøring — ingenting skrives. Legg til --utfor for å sette uniqueName."
fi
echo

antall_settes=0
antall_satt=0
antall_hoppet=0
antall_feil=0

# Leser mappingfila fra fd 3, slik at az ikke spiser stdin-en til løkka.
while IFS=$'\t' read -r -u 3 visningsnavn object_id app_id unikt_navn _status; do
  object_id="${object_id%$'\r'}"; app_id="${app_id%$'\r'}"; unikt_navn="${unikt_navn%$'\r'}"

  [ "$visningsnavn" = "displayName" ] && continue
  [ -z "$unikt_navn" ] && continue
  printf '%s' "$unikt_navn" | grep -Eq -- "$filter" || continue

  # Slå opp på objectId — ikke appId. PATCH-en skal treffe nøyaktig dette objektet.
  if ! app="$(az rest --method GET \
      --uri "$GRAPH/applications/${object_id}?\$select=id,appId,displayName,uniqueName" 2>&1)"; then
    printf 'FEIL        %-50s fant ikke objectId %s: %s\n' "$unikt_navn" "$object_id" "$app"
    antall_feil=$((antall_feil + 1))
    continue
  fi

  faktisk_app_id="$(printf '%s' "$app" | jq -r '.appId')"
  faktisk_navn="$(printf '%s' "$app" | jq -r '.displayName')"
  faktisk_unikt="$(printf '%s' "$app" | jq -r '.uniqueName // empty')"

  # Sperre mot en utdatert mappingfil: objectId og appId må fortsatt høre sammen.
  if [ "$faktisk_app_id" != "$app_id" ]; then
    printf 'FEIL        %-50s appId i Entra (%s) matcher ikke fila (%s)\n' \
      "$unikt_navn" "$faktisk_app_id" "$app_id"
    antall_feil=$((antall_feil + 1))
    continue
  fi
  if [ "$faktisk_navn" != "$visningsnavn" ]; then
    printf 'ADVARSEL    %-50s visningsnavn er endret: fil="%s", Entra="%s"\n' \
      "$unikt_navn" "$visningsnavn" "$faktisk_navn"
  fi

  if [ -n "$faktisk_unikt" ]; then
    if [ "$faktisk_unikt" = "$unikt_navn" ]; then
      printf 'HAR ALLEREDE %-49s\n' "$unikt_navn"
    else
      printf 'AVVIK       %-50s har allerede uniqueName "%s" — kan ikke endres\n' \
        "$unikt_navn" "$faktisk_unikt"
      antall_feil=$((antall_feil + 1))
      continue
    fi
    antall_hoppet=$((antall_hoppet + 1))
    continue
  fi

  # Navnet må være ledig i tenanten. Graph ville avvist en kollisjon, men da vet vi det før.
  opptatt="$(az rest --method GET \
    --uri "$GRAPH/applications(uniqueName='${unikt_navn}')?\$select=id" 2>/dev/null \
    | jq -r '.id // empty' 2>/dev/null || true)"
  if [ -n "$opptatt" ]; then
    printf 'KOLLISJON   %-50s brukes allerede av objectId %s\n' "$unikt_navn" "$opptatt"
    antall_feil=$((antall_feil + 1))
    continue
  fi

  if ! $utfor; then
    printf 'VIL SETTE   %-50s på "%s" (%s)\n' "$unikt_navn" "$faktisk_navn" "$object_id"
    antall_settes=$((antall_settes + 1))
    continue
  fi

  if ! svar="$(az rest --method PATCH \
      --uri "$GRAPH/applications/${object_id}" \
      --headers "Content-Type=application/json" \
      --body "{\"uniqueName\":\"${unikt_navn}\"}" 2>&1)"; then
    printf 'FEIL        %-50s PATCH avvist: %s\n' "$unikt_navn" "$svar"
    antall_feil=$((antall_feil + 1))
    continue
  fi

  # Verifiser på den nye nøkkelen — det er den verifiser.sh og Bicep skal bruke.
  bekreftet="$(az rest --method GET \
    --uri "$GRAPH/applications(uniqueName='${unikt_navn}')?\$select=id" 2>/dev/null \
    | jq -r '.id // empty' 2>/dev/null || true)"
  if [ "$bekreftet" = "$object_id" ]; then
    printf 'SATT        %-50s\n' "$unikt_navn"
    antall_satt=$((antall_satt + 1))
  else
    printf 'FEIL        %-50s PATCH svarte OK, men oppslag på uniqueName ga "%s"\n' \
      "$unikt_navn" "${bekreftet:-<ingenting>}"
    antall_feil=$((antall_feil + 1))
  fi
done 3< "$mappingfil"

echo
if $utfor; then
  echo "Satt: $antall_satt · hadde allerede: $antall_hoppet · feil: $antall_feil"
else
  echo "Vil sette: $antall_settes · hadde allerede: $antall_hoppet · feil: $antall_feil"
fi

[ "$antall_feil" -eq 0 ]

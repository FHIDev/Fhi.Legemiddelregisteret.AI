#!/usr/bin/env bash
#
# legg-til-kant.sh — gir en EKSISTERENDE .Client.Machine tilgang til en EKSISTERENDE .Api
#
# Det eneste skriptet for å endre en app-registrering som finnes fra før. Bicep-malene brukes bare
# til å OPPRETTE nye: en deploy mot en eksisterende app-registrering setter de deklarerte
# propertyene til malens verdi, og en deklarert liste (som kantene) kan bli erstattet.
#
# Skriptet kan bare LEGGE TIL. Det kan ikke fjerne eller endre noe, og det stopper før det skriver
# hvis noe ikke stemmer:
#
#   1. az står på FHI-tenanten
#   2. kaller er en -client-machine-<miljo> og callee en -api-<miljo>, i samme miljø — eller
#      kaller i dev/qa og callee i test (m2m-API-ene har bare Test og Prod; Dev/QA bruker Test)
#   3. begge har en baseline i entraid/baseline/, og Entra stemmer NØYAKTIG med den
#      (ukjent drift må forstås før noen endrer noe)
#   4. callee har nøyaktig én aktiv application-rolle, eller den du ber om
#   5. den nye kantlista inneholder ALT den gamle hadde, pluss kanten — ingenting annet
#
# Etter hvert steg leses tilstanden på nytt og sammenlignes med forventet tilstand: den gamle
# baselinen pluss nøyaktig denne endringen. Bare da skrives ny baseline, så et avbrudd kan
# fortsettes ved å kjøre skriptet igjen, og en endring noen andre har gjort underveis blir aldri
# stille ny fasit.
# `git diff entraid/baseline/` viser til slutt nøyaktig hva som ble lagt til.
#
# Bruk:
#   ./legg-til-kant.sh <kaller-uniqueName> <callee-uniqueName> [rolleverdi]            # tørrkjøring
#   ./legg-til-kant.sh --utfor <kaller-uniqueName> <callee-uniqueName> [rolleverdi]
#
# Eksempel:
#   ./legg-til-kant.sh fhi-lmr-varseltjeneste-client-machine-test fhi-lmr-grunndata-api-test
#
# Rolletildelingen er en application permission. Eier av callee (eller den som har
# Application Administrator på den) kan gi den selv, uten NHN.
#
set -uo pipefail

FHI_TENANT="54475f80-1baa-4ea9-9185-c0de5cc603fe"
GRAPH="https://graph.microsoft.com/v1.0"

skriptkatalog="$(cd "$(dirname "$0")" && pwd)"
entraid="$(cd "$skriptkatalog/.." && pwd)"
baselinekatalog="$entraid/baseline"
verifiser="$entraid/../plugins/lmr-entraid/skills/lmr-entraid/bicep/scripts/verifiser.sh"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

stopp() { echo "STOPP: $*" >&2; exit 1; }

utfor=false
if [ "${1:-}" = "--utfor" ]; then utfor=true; shift; fi

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Bruk: $0 [--utfor] <kaller-uniqueName> <callee-uniqueName> [rolleverdi]" >&2
  exit 64
fi
kaller="$1"; callee="$2"; rolleverdi="${3:-}"

command -v jq >/dev/null || stopp "jq er ikke installert."
[ -f "$verifiser" ] || stopp "finner ikke verifiser.sh på $verifiser."

# Skriver ny baseline bare hvis Entra er NØYAKTIG lik forventet tilstand ($2, en fil): den gamle
# baselinen pluss akkurat denne endringen. Har noen andre endret noe underveis, blir det ikke
# stille ny fasit. Prøver noen ganger, fordi en ny tildeling kan ta litt tid før den er synlig.
skriv_forventet_baseline() {
  local navn="$1" forventet="$2" forsok
  for forsok in 1 2 3 4 5 6; do
    if bash "$verifiser" "$navn" > "$tmp" 2>/dev/null \
       && [ "$(jq -S . "$tmp")" = "$(jq -S . "$forventet")" ]; then
      mv "$tmp" "$baselinekatalog/$navn.json" || {
        echo "Kunne ikke erstatte $baselinekatalog/$navn.json." >&2
        return 1
      }
      return 0
    fi
    [ "$forsok" -lt 6 ] && sleep 10
  done
  echo "Forventet tilstand for '$navn' (- forventet, + Entra nå):" >&2
  diff -u <(jq -S . "$forventet") <(jq -S . "$tmp" 2>/dev/null) >&2 || true
  return 1
}

# --- 1. tenant -----------------------------------------------------------------------------
aktiv_tenant="$(az account show --query tenantId -o tsv 2>/dev/null | tr -d '\r' || true)"
[ "$aktiv_tenant" = "$FHI_TENANT" ] || stopp "az står på tenant '${aktiv_tenant:-<ingen>}', ikke FHI. Kjør: az account set --subscription FHI-LMR-Dev"

# --- 2. navn og miljø ----------------------------------------------------------------------
[[ "$kaller" =~ ^fhi-.+-client-machine-([a-z]+)$ ]] || stopp "kaller '$kaller' er ikke en ...-client-machine-<miljo>."
kaller_miljo="${BASH_REMATCH[1]}"
[[ "$callee" =~ ^fhi-.+-api-([a-z]+)$ ]] || stopp "callee '$callee' er ikke en ...-api-<miljo>."
callee_miljo="${BASH_REMATCH[1]}"
if [ "$kaller_miljo" != "$callee_miljo" ]; then
  if ! { [[ "$kaller_miljo" =~ ^(dev|qa)$ ]] && [ "$callee_miljo" = "test" ]; }; then
    stopp "kaller i $kaller_miljo kan ikke kalle callee i $callee_miljo. Lovlig: samme miljø, eller dev/qa → test."
  fi
fi

# --- 3. baseline finnes og stemmer ---------------------------------------------------------
for n in "$kaller" "$callee"; do
  [ -f "$baselinekatalog/$n.json" ] || stopp "ingen baseline for '$n' i $baselinekatalog. Lag den med verifiser.sh først."
  if ! bash "$verifiser" "$n" "$baselinekatalog/$n.json" > "$tmp" 2>&1; then
    cat "$tmp" >&2
    stopp "Entra stemmer ikke med baselinen for '$n' (se over). Finn ut hvorfor før du endrer noe."
  fi
done
echo "Baseline stemmer for begge."

# --- hent kaller og callee -----------------------------------------------------------------
kaller_app="$(az rest --method GET --uri "$GRAPH/applications(uniqueName='$kaller')?\$select=id,appId,displayName,requiredResourceAccess" 2>/dev/null)" \
  || stopp "fant ikke kaller '$kaller'."
callee_app="$(az rest --method GET --uri "$GRAPH/applications(uniqueName='$callee')?\$select=appId,displayName,appRoles" 2>/dev/null)" \
  || stopp "fant ikke callee '$callee'."

kaller_object_id="$(jq -r '.id' <<<"$kaller_app")"
callee_app_id="$(jq -r '.appId' <<<"$callee_app")"
kaller_sp="$(jq -r '.spObjectId // empty' "$baselinekatalog/$kaller.json")"
callee_sp="$(jq -r '.spObjectId // empty' "$baselinekatalog/$callee.json")"
[ -n "$kaller_sp" ] && [ -n "$callee_sp" ] || stopp "baselinen mangler spObjectId. Lag den på nytt med verifiser.sh."

# --- 4. riktig app-rolle -------------------------------------------------------------------
roller="$(jq -c '[.appRoles[] | select(.isEnabled and (.allowedMemberTypes | index("Application")))]' <<<"$callee_app")"
if [ -n "$rolleverdi" ]; then
  roller="$(jq -c --arg v "$rolleverdi" '[.[] | select(.value == $v)]' <<<"$roller")"
fi
antall_roller="$(jq 'length' <<<"$roller")"
if [ "$antall_roller" -ne 1 ]; then
  echo "Aktive application-roller på callee:" >&2
  jq -r '.appRoles[] | select(.isEnabled and (.allowedMemberTypes | index("Application"))) | "  " + .value' <<<"$callee_app" >&2
  stopp "fant $antall_roller passende roller. Oppgi rolleverdien som tredje argument."
fi
rolle_id="$(jq -r '.[0].id' <<<"$roller")"
rolle_verdi="$(jq -r '.[0].value' <<<"$roller")"

# --- 5. ny kantliste: alt det gamle + kanten -----------------------------------------------
# Den gamle lista er baselinen, ikke et nytt oppslag: en kant som noen fjerner etter kontrollen i
# steg 3, skal ikke bli borte også fra forventet tilstand. Graph må likevel være lik baselinen.
# Rollen legges INN i callee sin eksisterende oppføring hvis den finnes. Ingen oppføring byttes ut.
gammel="$(jq -c '.requiredResourceAccess' "$baselinekatalog/$kaller.json")"
ny="$(jq -c --arg app "$callee_app_id" --arg rolle "$rolle_id" '
  if any(.[]; .resourceAppId == $app) then
    map(if .resourceAppId == $app and (any(.resourceAccess[]; .id == $rolle and .type == "Role") | not)
        then .resourceAccess += [{id: $rolle, type: "Role"}] else . end)
  else . + [{resourceAppId: $app, resourceAccess: [{id: $rolle, type: "Role"}]}] end' <<<"$gammel")"

# Flat liste over (ressurs, id, type) — det er det som må bevares.
flat='[.[] | .resourceAppId as $a | .resourceAccess[] | "\($a)|\(.id)|\(.type)"] | sort'
gammel_flat="$(jq -c "$flat" <<<"$gammel")"
ny_flat="$(jq -c "$flat" <<<"$ny")"
kant="$callee_app_id|$rolle_id|Role"

[ "$(jq -c "$flat" <<<"$(jq -c '.requiredResourceAccess' <<<"$kaller_app")")" = "$gammel_flat" ]   || stopp "kantlista på '$kaller' i Entra er endret siden baselinen ble kontrollert — kjører noen andre samtidig? Ingenting er skrevet."

kontroller_utvidelse() { # $1 = flat liste som skal være gammel + kant
  jq -e --argjson g "$gammel_flat" --arg k "$kant" '. == (($g + [$k]) | unique)' <<<"$1" >/dev/null
}
kontroller_utvidelse "$ny_flat" || stopp "den beregnede lista er ikke nøyaktig den gamle pluss kanten. Ingenting er skrevet."

kant_finnes=false
jq -e --arg k "$kant" 'index($k) != null' <<<"$gammel_flat" >/dev/null && kant_finnes=true

# Rolletildelingen slås opp i kallerens baseline (appRoleAssignments), som nettopp er
# kontrollert mot Entra.
tildeling_finnes=false
jq -e --arg r "$callee_sp" --arg a "$rolle_id" 'any(.appRoleAssignments[]; .resourceId == $r and .appRoleId == $a)' \
  "$baselinekatalog/$kaller.json" >/dev/null && tildeling_finnes=true

echo
echo "Kaller: $(jq -r '.displayName' <<<"$kaller_app")  ($(jq -r '.appId' <<<"$kaller_app"))"
echo "Callee: $(jq -r '.displayName' <<<"$callee_app")  ($callee_app_id)"
echo "Rolle:  $rolle_verdi  ($rolle_id)"
echo "Kanter på kaller: $(jq length <<<"$gammel_flat") -> $(jq length <<<"$ny_flat")"
$kant_finnes      && echo "  requiredResourceAccess: finnes allerede"   || echo "  requiredResourceAccess: LEGGES TIL"
$tildeling_finnes && echo "  rolletildeling:         finnes allerede"   || echo "  rolletildeling:         GIS"
echo

if $kant_finnes && $tildeling_finnes; then
  echo "Ingenting å gjøre."
  exit 0
fi

if ! $utfor; then
  echo "Tørrkjøring — ingenting er skrevet. Kjør med --utfor for å legge til kanten."
  echo "Reserver først klienten og API-et i Teams-kanalen Team A-informasjonsgruppe: 🔒 $kaller → $callee"
  exit 0
fi

# --- forventet tilstand etterpå, bygget fra de kontrollerte baselinene -----------------------
# Normalisert på samme måte som verifiser.sh, så de kan sammenlignes direkte.
forventet_kaller_kant="$(mktemp)"; forventet_kaller="$(mktemp)"; forventet_callee="$(mktemp)"
trap 'rm -f "$tmp" "$forventet_kaller_kant" "$forventet_kaller" "$forventet_callee"' EXIT

jq --argjson rra "$ny" '
  .requiredResourceAccess = ($rra
    | map({resourceAppId, resourceAccess: (.resourceAccess | map({id, type}) | sort_by(.id))})
    | sort_by(.resourceAppId))' "$baselinekatalog/$kaller.json" > "$forventet_kaller_kant"
jq --arg r "$callee_sp" --arg a "$rolle_id" '
  .appRoleAssignments = ((.appRoleAssignments + [{appRoleId: $a, resourceId: $r}])
    | unique | sort_by(.resourceId, .appRoleId))' "$forventet_kaller_kant" > "$forventet_kaller"
jq --arg p "$kaller_sp" --arg a "$rolle_id" '
  .appRoleAssignedTo = ((.appRoleAssignedTo + [{appRoleId: $a, principalId: $p, principalType: "ServicePrincipal"}])
    | unique | sort_by(.appRoleId, .principalId))' "$baselinekatalog/$callee.json" > "$forventet_callee"

# --- skriv requiredResourceAccess ----------------------------------------------------------
# Graph har ingen betinget oppdatering (ingen ETag/If-Match på applications), og PATCH erstatter
# hele lista. To samtidige kjøringer mot samme klient kan derfor overskrive hverandres kant, og
# begge kan gå grønt. Det finnes ingen lås: reserver klienten og API-et i Teams-kanalen
# Team A-informasjonsgruppe før --utfor (se entraid/README.md). Lesingen rett før skriving gjør vinduet kort, og en tapt kant
# blir synlig som drift når begge baselinene er merget.
if ! $kant_finnes; then
  rett_for="$(az rest --method GET --uri "$GRAPH/applications/$kaller_object_id?\$select=requiredResourceAccess" 2>/dev/null | jq -c '.requiredResourceAccess')"
  [ "$(jq -c "$flat" <<<"$rett_for")" = "$gammel_flat" ] \
    || stopp "kantlista på '$kaller' er endret siden kontrollen for et øyeblikk siden — kjører noen andre samtidig? Ingenting er skrevet."

  az rest --method PATCH --uri "$GRAPH/applications/$kaller_object_id" \
    --headers "Content-Type=application/json" \
    --body "$(jq -c '{requiredResourceAccess: .}' <<<"$ny")" > /dev/null \
    || stopp "PATCH av requiredResourceAccess ble avvist. Ingenting er endret."

  etter="$(az rest --method GET --uri "$GRAPH/applications/$kaller_object_id?\$select=requiredResourceAccess" 2>/dev/null | jq -c '.requiredResourceAccess')"
  etter_flat="$(jq -c "$flat" <<<"$etter")"
  if ! kontroller_utvidelse "$etter_flat"; then
    echo "⚠️⚠️ Kantlista i Entra er IKKE den gamle pluss kanten etter skriving:" >&2
    echo "  før:   $gammel_flat" >&2
    echo "  etter: $etter_flat" >&2
    stopp "Gjenopprett fra baselinen: requiredResourceAccess i $baselinekatalog/$kaller.json"
  fi
  echo "requiredResourceAccess: lagt til og kontrollert."

  # Baselinen skrives NÅ, så en ny kjøring etter et avbrudd under rolletildelingen godtar kanten.
  skriv_forventet_baseline "$kaller" "$forventet_kaller_kant" \
    || stopp "kanten er lagt til, men '$kaller' i Entra er ikke lik den gamle baselinen pluss kanten (se over). Baselinen er IKKE oppdatert. Finn ut hva annet som er endret før du går videre."
fi

# --- gi rolletildelingen -------------------------------------------------------------------
if ! $tildeling_finnes; then
  az rest --method POST --uri "$GRAPH/servicePrincipals/$callee_sp/appRoleAssignedTo" \
    --headers "Content-Type=application/json" \
    --body "$(jq -nc --arg p "$kaller_sp" --arg r "$callee_sp" --arg a "$rolle_id" '{principalId: $p, resourceId: $r, appRoleId: $a}')" > /dev/null \
    || stopp "rolletildelingen ble avvist. Kanten er lagt til og baselinen oppdatert; kjør skriptet på nytt når årsaken er rettet."
  echo "Rolletildeling: gitt."
fi

# --- nye baselines og kall-graf ------------------------------------------------------------
skriv_forventet_baseline "$kaller" "$forventet_kaller" \
  || stopp "endringen er gjort, men '$kaller' i Entra er ikke lik forventet tilstand (se over). Baselinen er IKKE oppdatert."
skriv_forventet_baseline "$callee" "$forventet_callee" \
  || stopp "endringen er gjort, men '$callee' i Entra er ikke lik forventet tilstand (se over). Baselinen er IKKE oppdatert."

bash "$skriptkatalog/lag-kall-graf.sh" > "$tmp" && mv "$tmp" "$entraid/KALL-GRAF-ENTRAID.md" \
  || echo "ADVARSEL: KALL-GRAF-ENTRAID.md ble ikke oppdatert. Kjør scripts/lag-kall-graf.sh manuelt." >&2

echo
echo "Ferdig. Se over endringen og commit baselinene og kall-grafen:"
echo "  git diff -- entraid/baseline/$kaller.json entraid/baseline/$callee.json entraid/KALL-GRAF-ENTRAID.md"

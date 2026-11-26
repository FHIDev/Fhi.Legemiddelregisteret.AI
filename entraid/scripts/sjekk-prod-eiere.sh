#!/usr/bin/env bash
#
# sjekk-prod-eiere.sh — sjekker at prod-app-registreringene bare eies av fagpersonen
#
# Målbildet (US 121935): fagpersonen eier prod permanent, utviklerne låner tilgang via PIM-gruppen.
# En utvikler som står igjen som fast eier, kan gi seg selv tilgang uten godkjenning — tildele
# brukere direkte til app-roller og laste opp sertifikater. Se NHN-OG-ADMIN.md i lmr-entraid.
#
# Fagområdet avgjøres av prefikset i uniqueName (tabellen i fagomrade_for under):
#   fhi-lmr-                    LMR                    Kari (påkrevd) + mi-lmr-sertifikatfornyelse-prod
#   fhi-grossiststatistikken-   Grossiststatistikken   Kristine (påkrevd)
#   fhi-reservasjonsregister-   hoppes over — ikke en del av fagperson-modellen (bruker-beslutning
#                               26. nov 2026)
# Et prefiks som ikke står i tabellen gir avvik («ukjent fagområde»), i stedet for å bli regnet
# med til et fagområde det kanskje ikke hører til.
#
# Skriptet leser KUN baselinene i entraid/baseline/ og endrer ingenting. Kjør verifiser.sh først
# hvis du vil være sikker på at baselinene stemmer med Entra.
#
# Bruk:
#   ./sjekk-prod-eiere.sh              # alle fagområder
#   ./sjekk-prod-eiere.sh lmr          # bare LMR
#   ./sjekk-prod-eiere.sh grossist     # bare Grossiststatistikken
#
# Exit 0 = ingen avvik. Exit 1 = minst ett avvik. Exit 2 = ugyldig argument.
#
set -uo pipefail

KARI="b53747d8-b2a0-4297-b430-5bfb3919f4bd"
KRISTINE="af7e2f5c-58c1-4a7d-b675-d9a312bb431e"
SERTIFIKATFORNYELSE_PROD="950fcb91-93df-4a70-a150-3e7458cf6d8a"

fagomrade_for() {
  case "$1" in
    fhi-lmr-*)                  echo lmr ;;
    fhi-grossiststatistikken-*) echo grossist ;;
    fhi-reservasjonsregister-*) echo utenfor ;;
    *)                          echo ukjent ;;
  esac
}

filter="${1:-alle}"
case "$filter" in
  alle|lmr|grossist) ;;
  *) echo "Ukjent fagområde «$filter». Bruk lmr, grossist eller ingen argument." >&2; exit 2 ;;
esac

skriptkatalog="$(cd "$(dirname "$0")" && pwd)"
baselinekatalog="$(cd "$skriptkatalog/../baseline" && pwd)"

avvik=0
antall=0

for fil in "$baselinekatalog"/*-prod.json; do
  [ -e "$fil" ] || { echo "Fant ingen prod-baselines i $baselinekatalog" >&2; exit 1; }
  navn="$(basename "$fil" .json)"
  fagomrade="$(fagomrade_for "$navn")"

  if [ "$fagomrade" = utenfor ]; then
    [ "$filter" = alle ] && echo "– $navn (utenfor fagperson-modellen, ikke sjekket)"
    continue
  fi
  if [ "$fagomrade" = ukjent ]; then
    [ "$filter" = alle ] || continue
    antall=$((antall + 1)); avvik=$((avvik + 1))
    echo "✗ $navn"
    echo "    ukjent fagområde — legg prefikset inn i fagomrade_for i dette skriptet"
    continue
  fi
  [ "$filter" = alle ] || [ "$filter" = "$fagomrade" ] || continue

  case "$fagomrade" in
    lmr)      fagperson="$KARI";     tillatt="$KARI $SERTIFIKATFORNYELSE_PROD" ;;
    grossist) fagperson="$KRISTINE"; tillatt="$KRISTINE" ;;
  esac
  antall=$((antall + 1))

  eiere="$(jq -r '.eiere[]?' "$fil" | tr -d '\r')"
  feil=""

  if ! printf '%s\n' "$eiere" | grep -qx "$fagperson"; then
    feil="${feil}    mangler fagpersonen som eier ($fagperson)\n"
  fi
  for eier in $eiere; do
    case " $tillatt " in
      *" $eier "*) ;;
      *) feil="${feil}    uventet eier: $eier\n" ;;
    esac
  done

  if [ -n "$feil" ]; then
    avvik=$((avvik + 1))
    echo "✗ $navn"
    printf "%b" "$feil"
  fi
done

echo
if [ "$avvik" -eq 0 ]; then
  echo "✓ Alle $antall prod-app-registreringer ($filter) eies kun av fagpersonen."
  exit 0
fi
echo "$avvik av $antall prod-app-registreringer ($filter) har avvik. Slå opp object-id-en med:"
echo "  az rest --method GET --uri \"https://graph.microsoft.com/v1.0/directoryObjects/<id>\""
exit 1

#!/usr/bin/env bash
#
# lag-kall-graf.sh — skriver EntraID-kantene som en markdown-tabell, utledet fra baselinene
#
# Kantene leses fra requiredResourceAccess i baseline/*.json og slås opp mot callee sin baseline
# for å få navn på rollen/scopet. Det leser bare lokale filer — ingen kall mot Entra.
#
# Bruk:
#   ./lag-kall-graf.sh > ../KALL-GRAF-ENTRAID.md
#
# Kolonnen «Tildelt» viser om rolletildelingen (application permission) er gitt. For LMR-callees
# slås den opp i callee sin baseline; for Microsoft Graph, som ikke har baseline, i kallerens
# appRoleAssignments. Delegerte scopes (type Scope) gis som oauth2PermissionGrant og står ikke i
# baselinen, så der står «—».
#
set -euo pipefail

skriptkatalog="$(cd "$(dirname "$0")" && pwd)"
baselinekatalog="$skriptkatalog/../baseline"

command -v jq >/dev/null || { echo "FEIL: jq er ikke installert." >&2; exit 1; }
ls "$baselinekatalog"/*.json >/dev/null 2>&1 || { echo "FEIL: ingen baselines i $baselinekatalog." >&2; exit 1; }

echo "<!-- GENERERT av entraid/scripts/lag-kall-graf.sh fra baseline/. Ikke rediger for hånd. -->"
echo
echo "| Miljø | Kaller | Callee (miljø) | Tillatelse | Type | Tildelt |"
echo "|---|---|---|---|---|---|"

# Object ID-en til Microsoft Graph sin service principal i FHI-tenanten
# (az ad sp show --id 00000003-0000-0000-c000-000000000000 --query id).
GRAPH_SP="d7ec3e68-9431-4ba9-8019-fbe4bafd1880"

jq -rs --arg graphSp "$GRAPH_SP" '
  def miljo: (.uniqueName | capture("-(?<m>[a-z]+)$").m);
  def kort: (.displayName | sub("^Fhi\\."; "") | sub(" ?- ?[A-Za-z]+$"; ""));
  (map({key: .appId, value: .}) | from_entries) as $apper
  | [ .[] as $k
      | $k.requiredResourceAccess[]
      | .resourceAppId as $ra
      | .resourceAccess[]
      | . as $tilgang
      | ($apper[$ra]) as $c
      | {
          miljo:  ($k | miljo),
          kaller: ($k | kort),
          callee: (if $c then (($c | kort) + " (" + ($c | miljo) + ")")
                   elif $ra == "00000003-0000-0000-c000-000000000000" then "Microsoft Graph"
                   else "ukjent (" + $ra + ")" end),
          tillatelse: (if $c == null then ({"e1fe6dd8-ba31-4d61-89e7-88639da4683d": "User.Read",
                                            "97235f07-e226-4f63-ace3-39588e11d3a1": "User.ReadBasic.All"}[$tilgang.id] // $tilgang.id)
                       elif $tilgang.type == "Role"
                         then ([$c.appRoller[] | select(.id == $tilgang.id) | .value][0] // $tilgang.id)
                       else ([$c.delegerteScopes[] | select(.id == $tilgang.id) | .value][0] // $tilgang.id) end),
          type: (if $tilgang.type == "Role" then "application" else "delegert" end),
          tildelt: (if $tilgang.type != "Role" then "—"
                    elif $ra == "00000003-0000-0000-c000-000000000000" then
                      (if any($k.appRoleAssignments[]; .resourceId == $graphSp and .appRoleId == $tilgang.id)
                       then "ja" else "**NEI**" end)
                    elif $c == null then "—"
                    elif any($c.appRoleAssignedTo[]; .appRoleId == $tilgang.id and .principalId == $k.spObjectId)
                      then "ja" else "**NEI**" end)
        }
    ]
  | sort_by(.miljo, .kaller, .callee)
  | .[]
  | "| \(.miljo) | \(.kaller) | \(.callee) | `\(.tillatelse)` | \(.type) | \(.tildelt) |"
' "$baselinekatalog"/*.json

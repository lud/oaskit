#!/usr/bin/env bash
# Compares two OpenAPI JSON documents (requires jq):
#   * servers
#   * operations: HTTP method + path + operationId
#   * for each operationId present in both documents: response status codes,
#     requestBody.required, parameters (in:name, * when required), security
#   * component schema names
#   * with --deep: the body of each component present in both documents and
#     the schema of each parameter, after normalizing both documents
#     (nullable -> type union with "null", example -> examples, x-struct and
#     x-validate removed, empty descriptions and empty required lists removed)
#
#     spec_diff.sh [--deep] old_openapi.json new_openapi.json
#
# Typical use: dump the OpenAPI document with `mix openapi.spec.json`
# (OpenApiSpex) before migrating, dump it with `mix openapi.dump` (Oaskit)
# after, and review every line of the diff.
set -euo pipefail

deep=false
if [ "${1:-}" = "--deep" ]; then
  deep=true
  shift
fi

if [ "$#" -ne 2 ]; then
  echo "usage: $0 [--deep] OLD_OPENAPI.json NEW_OPENAPI.json" >&2
  exit 1
fi

old="$1"
new="$2"

ops() {
  jq -r '[.paths // {} | to_entries[] | .key as $p | .value | to_entries[]
          | select(.value | type == "object")
          | "\(.key | ascii_upcase) \($p) \(.value.operationId)"] | sort | .[]' "$1"
}

# One tab-separated line per detail: operationId, then the detail.
details() {
  jq -r '.paths // {} | to_entries[] | .key as $p | .value as $item | $item | to_entries[]
    | select(.key | IN("get", "put", "post", "patch", "delete", "head", "options", "trace"))
    | .key as $m | .value as $op
    | ($op.operationId // "\($m | ascii_upcase) \($p)") as $id
    | "\($id)\tresponses: \($op.responses // {} | keys | join(","))",
      "\($id)\trequestBody: \(if $op.requestBody == null then "none" else "required=\($op.requestBody.required // false)" end)",
      "\($id)\tparameters: \([($item.parameters // []) + ($op.parameters // []) | .[]
          | "\(.in):\(.name)\(if .required then "*" else "" end)"] | sort | join(" "))",
      "\($id)\tsecurity: \($op.security // "inherited" | tojson)"' "$1" | sort
}

ids() {
  details "$1" | cut -f1 | sort -u
}

components() {
  jq -r '.components.schemas // {} | keys[]' "$1" | sort
}

echo "== openapi version: $(jq -r .openapi "$old") -> $(jq -r .openapi "$new")"
echo "== servers"
diff <(jq -c '.servers // []' "$old") <(jq -c '.servers // []' "$new") && echo "(identical)" || true
echo "== operations: $(ops "$old" | wc -l) -> $(ops "$new" | wc -l)"
diff <(ops "$old") <(ops "$new") && echo "(identical)" || true
common="$(comm -12 <(ids "$old") <(ids "$new"))"
only_common() { awk -F'\t' 'NR == FNR { keep[$0] = 1; next } keep[$1]' <(printf '%s\n' "$common") -; }
echo "== details of the operations present in both documents (by operationId)"
diff <(details "$old" | only_common) <(details "$new" | only_common) && echo "(identical)" || true
echo "== component schemas: $(components "$old" | wc -l) -> $(components "$new" | wc -l)"
diff <(components "$old") <(components "$new") && echo "(identical)" || true

if [ "$deep" = false ]; then
  exit 0
fi

# OpenAPI 3.0 schema -> the shape rewrite_lib.exs and Oaskit produce. Applied to
# both documents. Approximate: read each remaining difference.
norm='
def add_null: if type == "array" then (if index("null") then . else . + ["null"] end) else [., "null"] end;
def norm: walk(
  if type == "object" then
    del(.["x-struct"], .["x-validate"])
    | (if has("example") then .examples = [.example] | del(.example) else . end)
    | (if .description == "" then del(.description) else . end)
    | (if .required == [] then del(.required) else . end)
    | (if .nullable == true then
        del(.nullable)
        | if has("type") and (has("allOf") | not) then
            .type |= add_null
            | (if has("enum") then .enum = ((.enum - [null]) + [null]) else . end)
          elif has("oneOf") then .oneOf = [{"type": "null"}] + .oneOf
          elif has("anyOf") then .anyOf = [{"type": "null"}] + .anyOf
          elif has("allOf") then
            (if (.allOf | length) == 1 then .allOf[0] else {allOf: .allOf} end) as $inner
            | del(.allOf, .type) + {anyOf: [{"type": "null"}, $inner]}
          else . end
      else del(.nullable) end)
  else . end);
'

component() {
  jq -S --arg n "$2" "$norm"'.components.schemas[$n] | norm' "$1"
}

param_schemas() {
  jq -r "$norm"'.paths // {} | to_entries[] | .key as $p | .value as $item | $item | to_entries[]
    | select(.key | IN("get", "put", "post", "patch", "delete", "head", "options", "trace"))
    | .key as $m | .value as $op
    | ($op.operationId // "\($m | ascii_upcase) \($p)") as $id
    | (($item.parameters // []) + ($op.parameters // []))[]
    | "\($id)\t\(.in):\(.name)\t\(.schema // {} | norm | tojson)"' "$1" | sort
}

echo "== parameter schemas of the operations present in both documents (normalized)"
diff <(param_schemas "$old" | only_common) <(param_schemas "$new" | only_common) && echo "(identical)" || true

echo "== bodies of the component schemas present in both documents (normalized)"
same=true
for name in $(comm -12 <(components "$old") <(components "$new")); do
  if ! out="$(diff <(component "$old" "$name") <(component "$new" "$name"))"; then
    same=false
    echo "-- $name"
    printf '%s\n' "$out"
  fi
done
[ "$same" = true ] && echo "(identical)" || true

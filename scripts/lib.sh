#!/usr/bin/env bash
# Shared helpers for the demo scripts. Values are read from Terraform outputs.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF="terraform -chdir=${ROOT_DIR}/infra"

for bin in terraform curl jq; do
  command -v "$bin" >/dev/null || { echo "Missing dependency: $bin" >&2; exit 1; }
done

tf_output() { $TF output -raw "$1"; }
tf_output_json() { $TF output -json "$1"; }
# Fully qualified scope, e.g. scope_id candidates.read -> candidate-api-dev/candidates.read
scope_id() { tf_output_json client_scopes | jq -r --arg s "$1" 'map(select(endswith("/" + $s)))[0]'; }

API_URL="$(tf_output api_base_url)"
TOKEN_URL="$(tf_output token_endpoint)"

# get_token [scope]   Without argument, requests every scope of the client.
# A shorter scope list (e.g. only candidates.read) gives a narrower token.
get_token() {
  local client_id client_secret scope
  client_id="$(tf_output client_id)"
  client_secret="$(tf_output client_secret)"
  scope="${1:-$(tf_output_json client_scopes | jq -r 'join(" ")')}"

  curl -sS --fail-with-body -X POST "$TOKEN_URL" \
    -u "${client_id}:${client_secret}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "scope=${scope}" | jq -r '.access_token'
}

# create_candidate <token> <specialty> <firstName> <lastName> <birthDate> <file>
create_candidate() {
  curl -sS -X POST "${API_URL}/candidates" \
    -H "Authorization: Bearer $1" \
    -F "specialty=$2" -F "firstName=$3" -F "lastName=$4" -F "birthDate=$5" \
    -F "resume=@$6"
}

# Same as create_candidate but prints the body and the HTTP status (negative tests).
create_candidate_verbose() {
  curl -sS -X POST "${API_URL}/candidates" \
    -H "Authorization: Bearer $1" \
    -F "specialty=$2" -F "firstName=$3" -F "lastName=$4" -F "birthDate=$5" \
    -F "resume=@$6" -w '\nHTTP %{http_code}\n'
}

# Prints the JSON payload of a JWT (base64url without padding).
decode_jwt() {
  local payload
  payload="$(cut -d. -f2 <<<"$1" | tr '_-' '/+')"
  while (( ${#payload} % 4 )); do payload+="="; done
  base64 -d <<<"$payload"
}

title() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

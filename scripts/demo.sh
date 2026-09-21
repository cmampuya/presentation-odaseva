#!/usr/bin/env bash
# End-to-end demo: authentication, authorization, create, read, download, list, errors.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
S="${ROOT_DIR}/samples"
OUT="$(mktemp -d)"

title "1. Call without token -> 401"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" "${API_URL}/candidates/CA-000001"

title "2. Get an access token from Cognito (client credentials)"
RW_TOKEN="$(get_token)"
decode_jwt "$RW_TOKEN" | jq '{client_id, scope, token_use, exp}'
# Same client, token restricted to the read scope (used in step 7).
RO_TOKEN="$(get_token "$(scope_id candidates.read)")"
echo "read-only token scope: $(decode_jwt "$RO_TOKEN" | jq -r .scope)"

title "3. POST /candidates -> 201"
CREATED="$(create_candidate "$RW_TOKEN" Informatique Ada Lovelace 1985-12-10 "${S}/resume.pdf")"
echo "$CREATED" | jq .
CANDIDATE_ID="$(jq -r .candidateId <<<"$CREATED")"

title "4. GET /candidates/${CANDIDATE_ID} -> 200 + presigned URL"
DETAILS="$(curl -sS "${API_URL}/candidates/${CANDIDATE_ID}" -H "Authorization: Bearer ${RO_TOKEN}")"
echo "$DETAILS" | jq '.resume.downloadUrl |= (.[0:80] + "...")'

title "5. Download the resume with the presigned URL (no AWS credentials)"
curl -sS -o "${OUT}/${CANDIDATE_ID}.pdf" -w "HTTP %{http_code}, %{size_download} bytes\n" "$(jq -r .resume.downloadUrl <<<"$DETAILS")"
file "${OUT}/${CANDIDATE_ID}.pdf" 2>/dev/null || true

title "6. GET /candidates?specialty=Informatique -> 200"
curl -sS "${API_URL}/candidates?specialty=Informatique&limit=10" -H "Authorization: Bearer ${RO_TOKEN}" | jq .

title "7. POST with a token that only has candidates.read -> rejected by API Gateway (scope)"
create_candidate_verbose "$RO_TOKEN" Informatique Eve Hacker 1990-01-01 "${S}/resume.pdf"

title "8. Invalid resume type -> 400"
create_candidate_verbose "$RW_TOKEN" Informatique Bad File 1990-01-01 "${S}/invalid.txt"

title "9. Unknown candidate -> 404"
curl -sS "${API_URL}/candidates/CA-999999" -H "Authorization: Bearer ${RO_TOKEN}" -w '\nHTTP %{http_code}\n'

title "10. Missing specialty -> 400 (API Gateway request validation)"
curl -sS "${API_URL}/candidates" -H "Authorization: Bearer ${RO_TOKEN}" -w '\nHTTP %{http_code}\n'

title "11. Tampered token -> 401"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" "${API_URL}/candidates/${CANDIDATE_ID}" -H "Authorization: Bearer ${RO_TOKEN}x"

rm -rf "$OUT"

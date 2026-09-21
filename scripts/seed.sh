#!/usr/bin/env bash
# Loads the sample data set of the exercise (CA-000001 .. CA-000007 on a fresh table).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TOKEN="$(get_token)"
S="${ROOT_DIR}/samples"

while IFS='|' read -r specialty first last birth file; do
  create_candidate "$TOKEN" "$specialty" "$first" "$last" "$birth" "${S}/${file}" | jq -c '{candidateId, specialty, resumeKey}'
done <<'DATA'
Informatique|Josephine|Darakjy|1970-01-01|resume.pdf
Mathematique|Art|Venere|1981-05-19|resume.docx
Physique|Lenna|Paprocki|1977-03-25|resume.pdf
Informatique|Donette|Foller|1990-01-05|resume.docx
Medecine|Simona|Morasca|1985-09-26|resume.pdf
Mathematique|Mitsue|Tollner|1993-07-25|resume.docx
Informatique|Leota|Dilliard|1979-08-09|resume.ppt
DATA

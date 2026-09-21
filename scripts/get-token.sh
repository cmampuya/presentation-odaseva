#!/usr/bin/env bash
# Prints an OAuth2 access token (client credentials flow).
# Usage: scripts/get-token.sh [scope]   (default: every scope of the client)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if [[ -n "${1:-}" ]]; then get_token "$(scope_id "$1")"; else get_token; fi

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/lib/core.sh"
source "$ROOT_DIR/lib/standalone.sh"
source "$ROOT_DIR/lib/stack.sh"
source "$ROOT_DIR/lib/main.sh"

prc_main "$@"

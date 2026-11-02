#!/bin/bash
set -euo pipefail
TDJ_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ "${1:-}" == "--help" ]]; then
  echo 'Usage: release-ipad.sh DEVICE_ID TEAM_ID [--build-only]'
  echo 'Uses the single numbered iPad loop and its existing build cache.'
  exit 0
fi
TDJ_DEVICE="${1:?Supply the test iPad device ID.}"
TDJ_TEAM="${2:?Supply the Apple signing team ID.}"
TDJ_MODE="${3:-}"
[[ -z "$TDJ_MODE" || "$TDJ_MODE" == '--build-only' ]] || { echo 'Unknown option.' >&2; exit 2; }
TDJ_ACTION=run
[[ "$TDJ_MODE" != '--build-only' ]] || TDJ_ACTION=build
exec python3 "$TDJ_REPO_ROOT/tools/ipad_test.py" "$TDJ_ACTION" --device "$TDJ_DEVICE" --team "$TDJ_TEAM"

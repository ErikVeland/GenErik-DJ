#!/bin/bash
set -euo pipefail
TDJ_REPLICA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Compile an unsigned device app. Do not enumerate, connect to or install on hardware.
xcodebuild -project "$TDJ_REPLICA_ROOT/iPad/GenErikDJ.xcodeproj" \
  -scheme GenErikDJ -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$TDJ_REPLICA_ROOT/.build-iphoneos" -jobs 2 \
  CODE_SIGNING_ALLOWED=NO build

#!/bin/bash
set -euo pipefail
TDJ_REPLICA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Compile the complete app for a generic simulator platform. Do not select,
# boot, enumerate, sign for or install on a physical device.
xcodebuild -project "$TDJ_REPLICA_ROOT/iPad/GenErikDJ.xcodeproj" \
  -scheme GenErikDJ -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$TDJ_REPLICA_ROOT/.build-xcode" -jobs 2 \
  CODE_SIGNING_ALLOWED=NO build

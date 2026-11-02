#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
TDJ_ADAPTIVE_VARIANT="${TDJ_ADAPTIVE_SANITIZER:-normal}"
TDJ_ADAPTIVE_CACHE=".cache/adaptive-beatgrid/$TDJ_ADAPTIVE_VARIANT"
TDJ_ADAPTIVE_FLAGS=(-O3)
if [[ "$TDJ_ADAPTIVE_VARIANT" != normal ]]; then
 TDJ_ADAPTIVE_FLAGS=(-O1 -g -fno-omit-frame-pointer "-fsanitize=$TDJ_ADAPTIVE_VARIANT")
fi
mkdir -p "$TDJ_ADAPTIVE_CACHE"
for unit in TDJTransport TDJStreaming TDJRecording; do
 xcrun clang "${TDJ_ADAPTIVE_FLAGS[@]}" -std=c11 -I Sources/CTDJTransport/include -c "Sources/CTDJTransport/$unit.c" -o "$TDJ_ADAPTIVE_CACHE/$unit.o"
done
xcrun clang++ "${TDJ_ADAPTIVE_FLAGS[@]}" -std=c++17 -I Sources/CTDJTransport/include -I Sources/CTDJTransport/Vendor Sources/CTDJTransport/TDJKeylock.cpp Scripts/adaptive-beatgrid-native-check.cpp "$TDJ_ADAPTIVE_CACHE/TDJTransport.o" "$TDJ_ADAPTIVE_CACHE/TDJStreaming.o" "$TDJ_ADAPTIVE_CACHE/TDJRecording.o" -framework Accelerate -o "$TDJ_ADAPTIVE_CACHE/check"
"$TDJ_ADAPTIVE_CACHE/check"

#!/bin/bash
set -euo pipefail
TDJ_REPLICA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TDJ_REPLICA_ROOT"
mkdir -p .cache/keylock-stress
TDJ_STRESS_FLAGS=(-O3)
TDJ_STRESS_VARIANT=normal
if [[ -n "${TDJ_STRESS_SANITIZERS:-}" ]]; then
  TDJ_STRESS_FLAGS=(-O1 -g -fno-omit-frame-pointer "-fsanitize=$TDJ_STRESS_SANITIZERS")
  TDJ_STRESS_VARIANT="${TDJ_STRESS_SANITIZERS//,/-}"
fi
TDJ_STRESS_CACHE=".cache/keylock-stress/$TDJ_STRESS_VARIANT"
mkdir -p "$TDJ_STRESS_CACHE"
xcrun clang "${TDJ_STRESS_FLAGS[@]}" -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJTransport.c -o "$TDJ_STRESS_CACHE/transport.o"
xcrun clang "${TDJ_STRESS_FLAGS[@]}" -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJStreaming.c -o "$TDJ_STRESS_CACHE/streaming.o"
xcrun clang "${TDJ_STRESS_FLAGS[@]}" -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJRecording.c -o "$TDJ_STRESS_CACHE/recording.o"
xcrun clang++ "${TDJ_STRESS_FLAGS[@]}" -std=c++17 -I Sources/CTDJTransport/include -I Sources/CTDJTransport/Vendor \
  Sources/CTDJTransport/TDJKeylock.cpp Scripts/keylock-stress.cpp "$TDJ_STRESS_CACHE/transport.o" "$TDJ_STRESS_CACHE/streaming.o" "$TDJ_STRESS_CACHE/recording.o" \
  -framework Accelerate -o "$TDJ_STRESS_CACHE/check.new"
mv -f "$TDJ_STRESS_CACHE/check.new" "$TDJ_STRESS_CACHE/check"
"$TDJ_STRESS_CACHE/check" "$@"

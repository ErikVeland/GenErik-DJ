#!/bin/bash
set -euo pipefail
TDJ_PERFORMANCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TDJ_PERFORMANCE_ROOT"
TDJ_PERFORMANCE_OUTPUT="${1:?Supply a fresh output directory}"
if [[ -e "$TDJ_PERFORMANCE_OUTPUT" ]]; then echo 'Output already exists; preserve earlier evidence.' >&2; exit 2; fi
mkdir -p "$TDJ_PERFORMANCE_OUTPUT"
shasum -a 256 Sources/CTDJTransport/TDJTransport.c Sources/CTDJTransport/TDJRecording.c Sources/CTDJTransport/include/TDJRecording.h Sources/CTDJTransport/TDJStreaming.c Sources/CTDJTransport/TDJAsset.h Sources/CTDJTransport/include/TDJStreaming.h Sources/CTDJTransport/TDJEffects.h Sources/CTDJTransport/TDJDlcEffects.h Sources/CTDJTransport/include/TDJTransport.h Sources/CTDJTransport/TDJMixer.h Sources/CTDJTransport/TDJKeylock.cpp Scripts/performance-render-stress.cpp > "$TDJ_PERFORMANCE_OUTPUT/sources.sha256"
xcrun clang -O3 -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJTransport.c -o "$TDJ_PERFORMANCE_OUTPUT/transport.o"
xcrun clang -O3 -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJStreaming.c -o "$TDJ_PERFORMANCE_OUTPUT/streaming.o"
xcrun clang -O3 -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJRecording.c -o "$TDJ_PERFORMANCE_OUTPUT/recording.o"
xcrun clang++ -O3 -std=c++17 -I Sources/CTDJTransport/include -I Sources/CTDJTransport/Vendor Sources/CTDJTransport/TDJKeylock.cpp Scripts/performance-render-stress.cpp "$TDJ_PERFORMANCE_OUTPUT/transport.o" "$TDJ_PERFORMANCE_OUTPUT/streaming.o" "$TDJ_PERFORMANCE_OUTPUT/recording.o" -framework Accelerate -o "$TDJ_PERFORMANCE_OUTPUT/check"
"$TDJ_PERFORMANCE_OUTPUT/check" "$TDJ_PERFORMANCE_OUTPUT/result.json" "${2:-30}" "${3:-0}" "${4:-0}" "${5:-0}"

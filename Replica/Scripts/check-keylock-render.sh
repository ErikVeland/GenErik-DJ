#!/bin/bash
set -euo pipefail
TDJ_REPLICA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TDJ_REPLICA_ROOT"
mkdir -p .cache/keylock-render Validation
xcrun clang -O3 -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJTransport.c -o .cache/keylock-render/transport.o
xcrun clang -O3 -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJStreaming.c -o .cache/keylock-render/streaming.o
xcrun clang -O3 -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJRecording.c -o .cache/keylock-render/recording.o
xcrun clang++ -O3 -std=c++17 -I Sources/CTDJTransport/include -I Sources/CTDJTransport/Vendor \
  Sources/CTDJTransport/TDJKeylock.cpp Scripts/keylock-render-check.cpp .cache/keylock-render/transport.o .cache/keylock-render/streaming.o .cache/keylock-render/recording.o \
  -framework Accelerate -o .cache/keylock-render/check
.cache/keylock-render/check

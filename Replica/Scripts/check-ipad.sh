#!/bin/bash
set -euo pipefail
TDJ_REPLICA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TDJ_REPLICA_ROOT"
export CLANG_MODULE_CACHE_PATH="$TDJ_REPLICA_ROOT/.cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$TDJ_REPLICA_ROOT/.cache/swift"
TDJ_SIMULATOR_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
swift build --build-system native --disable-sandbox --cache-path .cache \
  --config-path .cache/config --security-path .cache/security --scratch-path .build-ios \
  --configuration "${TDJ_BUILD_CONFIGURATION:-debug}" --target TDJInterface --triple arm64-apple-ios17.0-simulator --sdk "$TDJ_SIMULATOR_SDK" \
  -j 2 --disable-index-store -debug-info-format none -Xswiftc -gnone

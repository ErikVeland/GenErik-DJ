#!/bin/bash
set -euo pipefail
TDJ_REPLICA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TDJ_REPLICA_ROOT"
export CLANG_MODULE_CACHE_PATH="$TDJ_REPLICA_ROOT/.cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$TDJ_REPLICA_ROOT/.cache/swift"
export TDJ_WORKSPACE="${TDJ_WORKSPACE:-$TDJ_REPLICA_ROOT/.workspace}"
swift run --build-system native --disable-sandbox --cache-path .cache \
  --config-path .cache/config --security-path .cache/security --scratch-path .build \
  -j 2 --disable-index-store -debug-info-format none -Xswiftc -gnone tdj-preview

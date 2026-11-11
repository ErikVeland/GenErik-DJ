#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
TDJ_GROOVE_CACHE=".cache/groove-sync"
mkdir -p "$TDJ_GROOVE_CACHE"
python3 - "$TDJ_GROOVE_CACHE" <<'PY'
import hashlib
from pathlib import Path
import sys
files = [Path('Scripts/check-groove-sync-native.sh'), Path('Scripts/groove-sync-native-check.cpp')]
files += sorted(path for path in Path('Sources/CTDJTransport').rglob('*') if path.is_file())
Path(sys.argv[1], 'sources.sha256').write_text(''.join(
    hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + str(path) + '\n' for path in files))
PY
for unit in TDJTransport TDJStreaming TDJRecording; do
 xcrun clang -O3 -std=c11 -I Sources/CTDJTransport/include -c "Sources/CTDJTransport/$unit.c" -o "$TDJ_GROOVE_CACHE/$unit.o"
done
xcrun clang++ -O3 -std=c++17 -I Sources/CTDJTransport/include -I Sources/CTDJTransport/Vendor Sources/CTDJTransport/TDJKeylock.cpp Scripts/groove-sync-native-check.cpp "$TDJ_GROOVE_CACHE/TDJTransport.o" "$TDJ_GROOVE_CACHE/TDJStreaming.o" "$TDJ_GROOVE_CACHE/TDJRecording.o" -framework Accelerate -o "$TDJ_GROOVE_CACHE/check"
"$TDJ_GROOVE_CACHE/check"
shasum -a 256 -c "$TDJ_GROOVE_CACHE/sources.sha256" > "$TDJ_GROOVE_CACHE/input-check.log"
shasum -a 256 "$TDJ_GROOVE_CACHE/check" > "$TDJ_GROOVE_CACHE/binary.sha256"

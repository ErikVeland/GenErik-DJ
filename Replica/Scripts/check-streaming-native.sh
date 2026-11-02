#!/bin/bash
set -euo pipefail
TDJ_STREAM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TDJ_STREAM_ROOT"
TDJ_STREAM_VARIANT="${TDJ_STREAM_SANITIZER:-normal}"
TDJ_STREAM_FLAGS=(-O3)
if [[ "$TDJ_STREAM_VARIANT" != normal ]]; then
  TDJ_STREAM_FLAGS=(-O1 -g -fno-omit-frame-pointer "-fsanitize=$TDJ_STREAM_VARIANT")
fi
TDJ_STREAM_CACHE=".cache/streaming-native/$TDJ_STREAM_VARIANT"
mkdir -p "$TDJ_STREAM_CACHE"
python3 - "$TDJ_STREAM_CACHE" <<'PY'
import hashlib, sys
from pathlib import Path
files = [Path('Scripts/check-streaming-native.sh'), Path('Scripts/streaming-native-check.cpp'), Path('Scripts/streaming-handoff-check.h')]
files += sorted(p for p in Path('Sources/CTDJTransport').rglob('*') if p.is_file())
Path(sys.argv[1], 'sources.sha256').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p)+'\n' for p in files))
PY
for unit in TDJTransport TDJStreaming; do
  xcrun clang "${TDJ_STREAM_FLAGS[@]}" -std=c11 -I Sources/CTDJTransport/include \
    -c "Sources/CTDJTransport/$unit.c" -o "$TDJ_STREAM_CACHE/$unit.o"
done
xcrun clang++ "${TDJ_STREAM_FLAGS[@]}" -std=c++17 -I Sources/CTDJTransport/include -I Sources/CTDJTransport/Vendor \
  Sources/CTDJTransport/TDJKeylock.cpp Scripts/streaming-native-check.cpp \
  "$TDJ_STREAM_CACHE/TDJTransport.o" "$TDJ_STREAM_CACHE/TDJStreaming.o" -framework Accelerate -o "$TDJ_STREAM_CACHE/check"
shasum -a 256 -c "$TDJ_STREAM_CACHE/sources.sha256" > "$TDJ_STREAM_CACHE/input-check.log"
shasum -a 256 "$TDJ_STREAM_CACHE/check" > "$TDJ_STREAM_CACHE/binary.sha256"
"$TDJ_STREAM_CACHE/check"

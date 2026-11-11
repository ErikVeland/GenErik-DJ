#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
TDJ_TRANSITION_VARIANT="${TDJ_TRANSITION_SANITIZER:-normal}"
TDJ_TRANSITION_CACHE=".cache/transport-transitions/$TDJ_TRANSITION_VARIANT"
TDJ_TRANSITION_FLAGS=(-O3)
if [[ "$TDJ_TRANSITION_VARIANT" != normal ]]; then
 TDJ_TRANSITION_FLAGS=(-O1 -g -fno-omit-frame-pointer "-fsanitize=$TDJ_TRANSITION_VARIANT")
fi
mkdir -p "$TDJ_TRANSITION_CACHE"
python3 - "$TDJ_TRANSITION_CACHE" <<'PY'
import hashlib,sys
from pathlib import Path
files=[Path('Scripts/check-transport-transitions-native.sh'),Path('Scripts/transport-transition-native-check.cpp'),Path('Scripts/bass-assist-native-check.h')]+sorted(p for p in Path('Sources/CTDJTransport').rglob('*') if p.is_file())
Path(sys.argv[1],'sources.sha256').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p)+'\n' for p in files))
PY
for unit in TDJTransport TDJStreaming TDJRecording; do
 xcrun clang "${TDJ_TRANSITION_FLAGS[@]}" -std=c11 -I Sources/CTDJTransport/include -c "Sources/CTDJTransport/$unit.c" -o "$TDJ_TRANSITION_CACHE/$unit.o"
done
xcrun clang++ "${TDJ_TRANSITION_FLAGS[@]}" -std=c++17 -I Sources/CTDJTransport/include -I Sources/CTDJTransport -I Sources/CTDJTransport/Vendor Sources/CTDJTransport/TDJKeylock.cpp Scripts/transport-transition-native-check.cpp "$TDJ_TRANSITION_CACHE/TDJTransport.o" "$TDJ_TRANSITION_CACHE/TDJStreaming.o" "$TDJ_TRANSITION_CACHE/TDJRecording.o" -framework Accelerate -o "$TDJ_TRANSITION_CACHE/check"
shasum -a 256 -c "$TDJ_TRANSITION_CACHE/sources.sha256" > "$TDJ_TRANSITION_CACHE/input-check.log"
shasum -a 256 "$TDJ_TRANSITION_CACHE/check" > "$TDJ_TRANSITION_CACHE/binary.sha256"
"$TDJ_TRANSITION_CACHE/check" "$@"

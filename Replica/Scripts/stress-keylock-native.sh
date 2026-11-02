#!/bin/bash
set -euo pipefail
TDJ_REPLICA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TDJ_REPLICA_ROOT"
mkdir -p .cache/keylock-native
if [[ $# -ge 2 ]]; then
  if [[ -e "$1" || -e "$1.source.mm" || -e "$1.build.json" || -e "$1.stop" ]]; then
    printf 'Refusing to overwrite native audio evidence: %s\n' "$1" >&2
    exit 2
  fi
  cp Scripts/keylock-native-stress.mm "$1.source.mm"
  cp Scripts/native-residency-diagnostic.h "$1.native-residency-diagnostic.h"
  python3 - "$@" <<'PYMETA'
import datetime
import hashlib
import json
from pathlib import Path
import sys
sources = [Path("Scripts/keylock-native-stress.mm"), Path("Scripts/stress-keylock-native.sh")]
sources += sorted(Path("Scripts").glob("native-*.h"))
sources += sorted(Path("Sources/CTDJTransport").rglob("*.c"))
sources += sorted(Path("Sources/CTDJTransport").rglob("*.cpp"))
sources += sorted(Path("Sources/CTDJTransport").rglob("*.h"))
manifest = {"preparedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(), "arguments": sys.argv[1:],
            "sourcesSHA256": {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}}
Path(sys.argv[1]+".build.json").write_text(json.dumps(manifest, indent=2)+"\n")
PYMETA
fi
xcrun clang -O3 -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJTransport.c -o .cache/keylock-native/transport.o
xcrun clang -O3 -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJStreaming.c -o .cache/keylock-native/streaming.o
xcrun clang -O3 -std=c11 -I Sources/CTDJTransport/include -c Sources/CTDJTransport/TDJRecording.c -o .cache/keylock-native/recording.o
xcrun clang++ -O3 -std=c++17 -I Sources/CTDJTransport/Vendor -c Sources/CTDJTransport/TDJKeylock.cpp -o .cache/keylock-native/keylock.o
xcrun clang++ -O3 -std=c++17 -fobjc-arc -I Sources/CTDJTransport/include Scripts/keylock-native-stress.mm \
  .cache/keylock-native/transport.o .cache/keylock-native/streaming.o .cache/keylock-native/keylock.o .cache/keylock-native/recording.o -framework AudioToolbox -framework AVFoundation -framework Foundation -framework CoreAudio -framework Accelerate \
  -o .cache/keylock-native/check.new
mv -f .cache/keylock-native/check.new .cache/keylock-native/check
.cache/keylock-native/check "$@"

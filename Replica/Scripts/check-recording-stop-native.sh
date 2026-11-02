#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
TDJ_RECORDING_VARIANT="${TDJ_RECORDING_SANITIZER:-normal}"
TDJ_RECORDING_CACHE=".cache/recording-stop/$TDJ_RECORDING_VARIANT"
TDJ_RECORDING_FLAGS=(-O3)
if [[ "$TDJ_RECORDING_VARIANT" != normal ]]; then
  TDJ_RECORDING_FLAGS=(-O1 -g -fno-omit-frame-pointer "-fsanitize=$TDJ_RECORDING_VARIANT")
fi
mkdir -p "$TDJ_RECORDING_CACHE"
shasum -a 256 Sources/CTDJTransport/TDJRecording.c Sources/CTDJTransport/include/TDJRecording.h \
  Scripts/recording-stop-native-check.c Scripts/check-recording-stop-native.sh > "$TDJ_RECORDING_CACHE/sources.sha256"
xcrun clang -std=c11 "${TDJ_RECORDING_FLAGS[@]}" -DTDJ_TEST_REQUEST_STOP \
  -I Sources/CTDJTransport/include Scripts/recording-stop-native-check.c -o "$TDJ_RECORDING_CACHE/check"
xcrun clang -std=c11 "${TDJ_RECORDING_FLAGS[@]}" \
  -I Sources/CTDJTransport/include Scripts/recording-stop-native-check.c -o "$TDJ_RECORDING_CACHE/check-blocking"
python3 - "$TDJ_RECORDING_CACHE/check-blocking" "$TDJ_RECORDING_CACHE/check" <<'PY'
import subprocess, sys
for executable in sys.argv[1:]:
    subprocess.run([executable], check=True, timeout=10)
PY
shasum -a 256 -c "$TDJ_RECORDING_CACHE/sources.sha256"
shasum -a 256 "$TDJ_RECORDING_CACHE/check" "$TDJ_RECORDING_CACHE/check-blocking" > "$TDJ_RECORDING_CACHE/binary.sha256"

#!/bin/bash
# Copy the Mac's iCloud-synced DJ collection into the test app's own Documents on a USB iPad.
# The source is only read. Only the GenErik DJ test app's container is written.
# Usage: Scripts/push-collection-to-ipad.sh <device-udid> [bundle-id]
set -euo pipefail
DEVICE="${1:?Give the iPad UDID (xcrun devicectl list devices).}"
BUNDLE="${2:-org.generikdj.replica.audiocheck}"
SOURCE="$HOME/Library/Mobile Documents/iCloud~com~native-instruments~tdj/Documents/collection.nml.gz"
[ -f "$SOURCE" ] || { echo "No synced collection at $SOURCE" >&2; exit 1; }
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp "$SOURCE" "$STAGE/collection.nml.gz"
shasum -a 256 "$STAGE/collection.nml.gz"
xcrun devicectl device copy to --device "$DEVICE" --domain-type appDataContainer \
  --domain-identifier "$BUNDLE" --source "$STAGE/collection.nml.gz" --destination Documents/collection.nml.gz
echo "Copied. The app imports it automatically at its next launch or activation."

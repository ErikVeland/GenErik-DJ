#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" == "--help" ]]; then
  echo 'Usage: release-ipad.sh DEVICE_ID TEAM_ID [--build-only]'
  echo 'Build and update GenErik DJ Test. Use --build-only to skip installation.'
  exit 0
fi
DEVICE="${1:?Supply the test iPad device ID.}"
TEAM="${2:?Supply the Apple signing team ID.}"
MODE="${3:-}"
[[ -z "$MODE" || "$MODE" == '--build-only' ]] || { echo 'Unknown option.' >&2; exit 2; }
cd "$ROOT/.."
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  echo 'Commit or preserve working changes before releasing this source.' >&2
  exit 1
fi
REVISION="$(git rev-parse HEAD)"
BUNDLE='org.generikdj.replica.audiocheck'
BUILD="$ROOT/.build-micro-release"
RUN="$BUILD/releases/$(date +%Y%m%d-%H%M%S)-${REVISION:0:8}"
mkdir -p "$RUN"
printf 'source=%s\nbundle=%s\ndevice=%s\nstatus=building\n' "$REVISION" "$BUNDLE" "$DEVICE" > "$RUN/release.txt"
xcodebuild -project "$ROOT/iPad/GenErikDJ.xcodeproj" \
  -scheme GenErikDJ -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath "$BUILD" -jobs 2 \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" \
  INFOPLIST_KEY_CFBundleDisplayName='GenErik DJ Test' \
  INFOPLIST_KEY_TDJSourceRevision="$REVISION" build 2>&1 | tee "$RUN/build.log"
APP="$BUILD/Build/Products/Release-iphoneos/GenErikDJ.app"
codesign --verify --deep --strict "$APP"
[[ "$(git rev-parse HEAD)" == "$REVISION" && -z "$(git status --porcelain --untracked-files=normal)" ]] || {
  echo 'Source changed during the build. Release stopped.' >&2; exit 1;
}
printf 'status=built\n' >> "$RUN/release.txt"
if [[ "$MODE" == '--build-only' ]]; then
  echo "Signed test app: $APP"
  echo "Release record: $RUN/release.txt"
  exit 0
fi
xcrun devicectl device install app --device "$DEVICE" "$APP" 2>&1 | tee "$RUN/install.log"
printf 'status=installed\n' >> "$RUN/release.txt"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE" 2>&1 | tee "$RUN/launch.log"
printf 'status=launched\n' >> "$RUN/release.txt"
echo "Release record: $RUN/release.txt"

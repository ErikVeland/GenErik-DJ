#!/bin/bash
set -euo pipefail
TDJ_REPLICA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TDJ_REPLICA_ROOT"
export CLANG_MODULE_CACHE_PATH="$TDJ_REPLICA_ROOT/.cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$TDJ_REPLICA_ROOT/.cache/swift"
swift build --build-system native --disable-sandbox --cache-path .cache \
  --config-path .cache/config --security-path .cache/security --scratch-path .build \
  --configuration release --product tdj-preview -j 2 --disable-index-store -debug-info-format none -Xswiftc -gnone
TDJ_APP_PATH="$TDJ_REPLICA_ROOT/Build/GenErik DJ Development.app"
mkdir -p "$TDJ_APP_PATH/Contents/MacOS"
mkdir -p "$TDJ_APP_PATH/Contents/Resources"
cp THIRD_PARTY_NOTICES.txt "$TDJ_APP_PATH/Contents/Resources/ThirdPartyNotices.txt"
cp .build/release/tdj-preview "$TDJ_APP_PATH/Contents/MacOS/.tdj-preview.new"
mv -f "$TDJ_APP_PATH/Contents/MacOS/.tdj-preview.new" "$TDJ_APP_PATH/Contents/MacOS/tdj-preview"
cat > "$TDJ_APP_PATH/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>tdj-preview</string>
<key>CFBundleIdentifier</key><string>org.generikdj.replica.mac.development</string>
<key>CFBundleName</key><string>GenErik DJ Development</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSAppleMusicUsageDescription</key><string>Choose local and synced songs and playlists for DJ analysis and mixing. Your Music library stays unchanged.</string>
</dict></plist>
PLIST
codesign --force --sign - "$TDJ_APP_PATH"
printf '%s\n' "$TDJ_APP_PATH"

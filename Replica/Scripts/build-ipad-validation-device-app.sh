#!/bin/bash
set -euo pipefail
TDJ_AUDIO_CHECK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TDJ_AUDIO_CHECK_DERIVED="$TDJ_AUDIO_CHECK_ROOT/.build-audio-check-iphoneos"
TDJ_AUDIO_CHECK_SOURCE_SHA256="$(python3 "$TDJ_AUDIO_CHECK_ROOT/Scripts/validation_app_provenance.py" begin \
  --derived-data "$TDJ_AUDIO_CHECK_DERIVED" --sdk iphoneos)"
# Generic unsigned compilation only. Do not enumerate, boot, contact or install on hardware.
xcodebuild -project "$TDJ_AUDIO_CHECK_ROOT/iPadValidation/GenErikDJAudioCheck.xcodeproj" \
  -scheme GenErikDJAudioCheck -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$TDJ_AUDIO_CHECK_DERIVED" -jobs 2 \
  TDJ_VALIDATION_SOURCE_SHA256="$TDJ_AUDIO_CHECK_SOURCE_SHA256" CODE_SIGNING_ALLOWED=NO build
python3 "$TDJ_AUDIO_CHECK_ROOT/Scripts/validation_app_provenance.py" finish \
  --derived-data "$TDJ_AUDIO_CHECK_DERIVED" --sdk iphoneos

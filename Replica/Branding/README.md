# GenErik DJ branding

`GenErik-Source.ai` preserves Erik's supplied artwork. The interface uses
`../Sources/TDJInterface/Resources/HeaderArtwork/GenErikHeaderMark.png` and
the system-font wordmark in `GenErikBrandLockup`.

`../iPad/AppIcon.icon/` is the shared Icon Composer source for iPad and Mac.
Both Mac Xcode targets use it. The Mac development package compiles it with
`actool` when `Scripts/package-mac.sh` runs.

## App Store header

`AppStore/header-current-3840x1646.png` uses the interface mark, bold system-font
wordmark and graphite palette. It is an opaque sRGB PNG. The mark, gap and
type retain the proportions in `GenErikBrandLockup`.

Run `swift Replica/Scripts/export-store-header.swift` from the repository root
to regenerate it. App Store Connect saved this replacement on 18 November
2026. Its iPhone product-page preview showed the complete mark and wordmark.

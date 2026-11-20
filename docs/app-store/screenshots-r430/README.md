# R430 App Store release captures

On 19 November 2026, Xcode 27.1 built GenErik DJ 1.0 (228) for iOS and Mac from consolidated source `b8827365e6a542edd440d4402937a5a2efb0476e`. Both device archives passed signature verification. Xcode exported the Mac App Store package. A disk cleanup removed the first capture directory and both local archives. The simulator binaries and Mac export log survived. The original signed archives and package are no longer available locally. The Mac image in this folder is Apple's processed copy.

The iPhone, iPhone Duo and iPad sessions ran the same Release simulator binary. The executable hashes match. The native Mac window ran from the signed archive. It shows original demo audio on both decks. The Mac capture was fitted to an opaque 1440 × 900 canvas without stretching the UI. The mobile captures use their native simulator dimensions.

Apple accepted these placements in the English (Australia) 1.0 drafts for app 6832211854. The earlier screenshot placements stayed in place.

| Display | Pixels | Capture |
| --- | --- | --- |
| iPhone 18 Pro | 1206 × 2622 | Workspace menu |
| iPhone Duo inner | 2853 × 2007 | Song library |
| iPad 13-inch | 2752 × 2064 | Song library |
| Mac | 1440 × 900 | Two decks |

The iPhone library capture stalled in Xcode, so the iPhone image shows the workspace menu. The earlier Duo outer-screen capture remains in the draft.

The separate R428 browser fix landed after this release build. The R428 iPad test build reports version 0.1.0 (228) and uses a different source commit. Both App Store versions remain drafts.

[Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

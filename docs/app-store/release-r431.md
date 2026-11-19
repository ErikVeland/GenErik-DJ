# R431 Release build and iPhone screenshot

Xcode 27.1 built GenErik DJ 1.0 (229) from `1b168fd37322b4e57d8e2a7f18144ab0d8e45b35`. This source includes the R428 browser fix, commit `591dfd9d0`.
Both archives passed signature checks. Xcode exported the iOS IPA and Mac installer. The first iOS export used the wrong rsync version. The retry used Apple's system tools and passed.

| Package | Local file |
| --- | --- |
| iOS | `TestBuilds/r431-release-waveform/ios/export-retry/GenErikDJ.ipa` |
| Mac | `TestBuilds/r431-release-waveform/mac/export/GenErik DJ.pkg` |

The 1.0 (229) Release simulator build also passed. The iPhone 18 Pro and 17 Pro simulator startup attempts timed out before app launch. A process sample on iOS 27.0 found the simulator loader waiting on a system library cache mapping. Restarting the simulator service and regenerating the iOS 26.4 cache did not restore startup. Logs and package checksums are in `TestBuilds/r431-release-waveform`.

The iPhone screenshot replacement is pending. App Store Connect still shows the R430 workspace-menu image in the English (Australia) medium Dynamic Island slot.

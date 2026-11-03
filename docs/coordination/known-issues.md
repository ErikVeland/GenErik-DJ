# Open candidate issues

| ID | Related request | Issue / uncertainty | Next evidence needed |
| --- | --- | --- | --- |
| B01 | R13 | The packaged empty-workspace snapshot shows a yellow/prohibited-style search field. The cause and live-app impact are unknown. | Compare the actual live Mac and simulator browser with the snapshot path. Retain the current render before any fix. |
| B02 | R01/R07/R20 | The exact combined source has not completed sustained audio or physical A10X qualification. | Run the unchanged combined workloads, then listening and rehearsal gates. |
| B03 | R09/R11 | Automatic semantic drop/song-structure recognition and validated musical-ending detection remain incomplete. | Reference-labelled real music, conservative uncertainty handling and correct manual overrides. |
| B04 | R12 | The app reviews governed JSON and one ID3 Initial Key field, but does not parse Mixed In Key project exports or write changes to Traktor Pro files. The ID3 field does not identify its writer. | Obtain representative native exports and collection files; verify field and identity mappings; add adapter tests and preview/backup/write-back checks before external writes. |
| B05 | R14/R23 | Z1 bridge and opt-in controller profiles do not establish physical accessory compatibility, model mappings, output behaviour or accepted control feel. The configfs helper has filesystem-fixture tests, not bridge-hardware checks. | Verify supported connection, input mappings, output messages, calibration, audio route and control feel on available hardware. |
| B06 | R19 | The 18 candidate folders are absent here. The inventory lists 909 differing file entries; 908 current paths differ by hash and one is missing. Hashes cannot show whether changes were superseded or incorporated differently. | Restore candidate source and inspect meaningful patches before assigning dispositions. See `private-worktree-comparison.md`. |
| B07 | R20 | Build 79 from source `ca1a31f` is installed and launched. Current source adds unsigned R31 header spacing in `0f0042e`. The saved app and signing config are absent from this checkout, and `xcode-select` points to Command Line Tools rather than full Xcode. A further signed increment cannot be prepared here. | Restore full Xcode and signing configuration before the next source change that needs a signed build. Erik's build 79 review, audio qualification and rehearsal remain pending. |

These issues are open. The passing package suite does not close them.

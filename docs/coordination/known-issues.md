# Known issues

| Request | Open work |
| --- | --- |
| R89–R93 | Focused fixes are included in build 155. Physical acceptance remains open. R96 also reproduces a lost waveform release under queue pressure, so grid restoration is not reliable across every release path. See [live-test feedback](live-test-144.md) and [reliability audit](reliability-audit-155.md). |
| R96 | Build 159 includes fixes for lost mixer values, lost gesture release and audio-device recovery. Host checks passed. Physical Z1 routing, listening, touch and sustained A10X deadlines remain open. [Evidence and remaining checks](reliability-audit-155.md). |
| R01/R07/R20 | Sustained current-source audio, adaptive timing, memory/thermal behaviour and real-setup rehearsal need A10X acceptance. |
| R09/R11/R35–R38 | Verse/chorus/drop/ending labels remain estimates. Dense remixes and unresolved vocal tracks need reference-labelled listening checks. |
| R12 | Mixed In Key native exports and Traktor Pro write-back need verified format/identity mappings and preview/backup checks. |
| R14/R23 | Controller profiles and bridge code need physical connection, calibration, routing and feedback acceptance. Original Z1 is first. |
| R17 | The stem model is bundled. Inference, cached stem playback and mixer controls are not implemented. A10X cost is unknown. |
| R73/R85 | The legacy launch-reanalysis test expects valid saved grids and keys to be replaced. Nine assertions fail across three cases on both `aaab02b8c` and R85. Reconcile this test with the R73 reuse policy separately. Evidence: `TestBuilds/r85/`. |
| R19 | Eighteen private candidates remain preserved in the external archive. Their meaningful differences still need source review. |
| R28/R39/R40/R42 | Front/inside phone layouts and shortcuts need physical acceptance. iPad layout stays separate. |

Earlier screenshots, failures and superseded installation blockers remain in [history](../history.md). The old Xcode licence/signing blocker is superseded by successful signed builds through 111.

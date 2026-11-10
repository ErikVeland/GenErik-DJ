# R156: Whole-library analysis and delivery

Erik requested the current analysis on every track available on the iPad. He then requested the remaining full library, after iPad delivery.

The frozen iPad inventory contains 6,087 available Music items. The Mac inventory contains 116,110 items and 96,002 distinct available audio files. Duplicate Music items can refer to one recording. Missing downloads and protected files remain outside the playable local set.

## Run contract

The Mac app decodes candidate files with the same Float32 CAF path as iOS. Metadata selects candidates only. The decoded SHA-256 and audio dimensions must match the saved iPad identity before the app stages a result. A mismatch remains an explicit error. Tracks without a saved identity require one candidate and remain identifiable by their resulting audio hash.

Each track retains its first-pass analysis, deep result, final automatic analysis, stage times and model profile. Policy 14 includes the R139 rhythm changes. Prediction windows and completed results survive restart. A run lock prevents simultaneous writers. The source inventory remains frozen.

Results use the existing automatic CloudPreparation archive. They contain analysis, not the sender's manual performance preparation. The production receiver preserves manual grids, imported preparation and newer results. Loaded tracks remain protected until the app can safely adopt the result.

The signed Mac app uploads directly through the existing private CloudKit transport. It uses the same app identity and container as the iOS test app. It checks the signed-in account before each batch and validates every incoming archive. The worker never creates cloud confirmation markers. It reads actual confirmation markers on the receiving devices.

The full-library phase waits until every iPad item has a successful result and the iPad has confirmed every generated revision. It then skips source files completed in the iPad run and processes the remaining local files. Offline devices retain pending delivery. Receiving a revision and adopting it into a currently loaded track are separate checks.

## Evidence and limits

Initial evidence is retained under `TestBuilds/r156` in the analysis worktree. Long-run output belongs on `/Volumes/iTunes/GenErik DJ Analysis/r156`. This avoids the Mac system volume's low free space. Original audio and previous validation evidence remain unchanged.

The initial three-track Mac trial matched all three device audio hashes. A changed-identity trial produced no export. Restart reused completed results. Six focused Python checks cover corrupt payloads, manual archives, account changes, commit order, candidate matching and phase selection.

The signed Mac trial received server acknowledgements for all three results. Its account hash matched the iPad and Duo. The initial separate Mac app identifier failed CloudKit container association. That failed attempt remains retained. The working Mac build uses `org.generikdj.replica.audiocheck` with an Apple development profile and the Development CloudKit environment, matching the installed test apps. Production/TestFlight is a separate environment.

Device delivery and the full run are not yet complete. A cloud confirmation does not establish musical correctness. The manually corrected R139 tracks remain the verified musical references. The wider library establishes a versioned baseline for later review and comparison.

Audio files are not included in iCloud preparation sync. Each device still requires its own available audio copy. Live audio and touch acceptance remain separate from this idle analysis run.

## Exact iPad source recovery

Some Mac candidates fail the saved iPad audio identity check. The cause is not yet established for each file. These results remain excluded from sharing.

The recovery worker requests one iPad Music item by its persistent identifier. The iPad prepares one temporary lossless copy. Playback, backgrounding, power loss or excessive heat cancels preparation. The Mac verifies the copied bytes and audio dimensions against the saved identity before analysis. It copies this prepared file unchanged into the analyser.

Each successful recovery retains the original failed attempt. The result and cloud payload become visible only after validation. The campaign can reconnect to an active analyser and wait for recovery before the full-library phase. Changed device identities and unavailable audio remain explicit review items.

Fifteen focused Swift checks and eight campaign checks passed before device installation. These cover exact identity reads, cancellation, cloud admission, archive integrity and recovery publication.

Build 220 installed on the A10X from `bdc57d76be61363d395c6c8d294a7e5421c87df0`. The signed Mac recovery app uses the same source. The original Mac batch remains on `eda78ac03` with the same analysis profile. The first recovery, “Blockbuster”, matched the saved iPad hash and all audio dimensions. The Mac completed its analysis and queued its revision. Evidence is under `source-proof/4268600258740691148` in the external run folder. Receipt of this revision still requires verification.

The controller starts the recovery worker automatically. Both workers retain independent locks and checkpoints. Restart can reconnect to the original Mac batch without stopping it. The full-library phase remains queued behind iPad completion and receipt. The iPhone was unavailable at the latest check. No completion claim applies to the full inventory or every device.

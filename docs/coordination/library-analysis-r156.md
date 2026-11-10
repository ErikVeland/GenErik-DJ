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

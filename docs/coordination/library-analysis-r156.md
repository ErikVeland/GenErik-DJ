# R156: Whole-library analysis and delivery

Erik requested the current analysis on every track available on the iPad. He then requested the remaining full library, after iPad delivery.

The frozen iPad inventory contains 6,087 available Music items. The Mac inventory contains 116,110 items and 96,002 distinct available audio files. Duplicate Music items can refer to one recording. Missing downloads and protected files remain outside the playable local set.

## Run contract

The Mac app decodes candidate files with the same Float32 CAF path as iOS. Metadata selects candidates only. The decoded SHA-256 and audio dimensions must match the saved iPad identity before the app stages a result. A mismatch remains an explicit error. Tracks without a saved identity require one candidate and remain identifiable by their resulting audio hash.

Each track retains its first-pass analysis, deep result, final automatic analysis, stage times and model profile. Policy 14 includes the R139 rhythm changes. Prediction windows and completed results survive restart. A run lock prevents simultaneous writers. The source inventory remains frozen.

Results use the existing automatic CloudPreparation archive. They contain analysis, not the sender's manual performance preparation. The production receiver preserves manual grids, imported preparation and newer results. Loaded tracks remain protected until the app can safely adopt the result.

The signed Mac app uploads directly through the existing private CloudKit transport. It uses the same app identity and container as the iOS test app. It checks the signed-in account before each batch and validates every incoming archive. The worker never creates cloud confirmation markers. It reads actual confirmation markers on the receiving devices.

The full-library phase waits until every iPad item has a successful result or three failed recovery attempts. The iPad must confirm every successful revision. Repeated failures remain in `ipad-unresolved.json` and do not count as successful analysis. The full phase skips source files completed in the iPad run and processes the remaining local files. Offline devices retain pending delivery. Receiving a revision and adopting it into a currently loaded track are separate checks.

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

## Receive throughput

Build 221 added diagnostics. On the A10X, four retained results took 44.05 seconds to apply. The 45-second automatic sync deadline then cancelled the operation before download. Each result saved the whole library. The retained results were safe, but this delayed receipt of later Mac results.

The receiver now groups up to 32 revisions and saves their deep results in one library transaction. It rechecks loaded and active tracks before the save. It retains prior preparation and applies section changes only to the current playback grid. A new test reproduced three saves before the change and verifies one save after it. It also covers a protected track and an older revision arriving after a newer result.

Two older sharing tests failed on the unchanged baseline. One expected a missing completion date after the R159 legacy-date fallback. The other expected automatic full-grid adoption, which policy 14 requires users to review. Their fixtures now follow those established contracts. Both baseline failures remain in `TestBuilds/r156/cloud-sharing-baseline.log`.

Mac recovery now keeps one analyser process open. A fresh “Blockbuster” run took 108.61 seconds under the active workload. The next run in the same process took 1.40 seconds. First-pass and deep results were identical except for completion time. This measures model setup reuse on one short track, not general library throughput. Evidence is under `service-proof` in the external run folder.

Source recovery retries failed exports with a new request after five minutes. Three failed attempts produce an explicit exception for review. Prior requests and responses remain retained. The worker exits after the campaign starts the full-library phase. Nine campaign checks passed, including the repeated-failure gate.

Build 222 applied 24 results in 9.65 seconds, then reached download. A later group applied 32 results in 8.17 seconds. The iPad acknowledged the recovered “Blockbuster” revision. A copied library contained 236 exact Mac results. All 222 protected grids checked in that set remained unchanged. The run still has unapplied results.

Build 223 identified CloudKit error 14 inside the remaining partial upload failures. The saved engine state contained 382 pending revisions with no local confirmation. The receiver now fetches and verifies the complete server payload for a conflicting revision. It clears that pending upload only after verification. It continues only when every error is a verified conflict and the operation made progress. Other errors and cancellation still stop sync. Seventeen focused checks passed. Device verification remains open.

Build 222 also installed on the Duo. iOS refused both launch attempts because the device was locked. The iPad build record retains separate device evidence. The iPhone remained unavailable. Neither device has confirmed the current Mac batch.

## Offline Mac workers

The Mac has an M4 Pro, 14 CPU cores and 24 GB memory. The initial worker used background priority. A dedicated offline context now requests higher CPU priority only on macOS. Normal app work and iOS remain at background priority. Four focused checks verify that boundary and cancellation.

The optional worker pool assigns disjoint track inventories to at most four processes. Each process retains its own model compilation and checkpoints. Validated payloads reach the shared outbox before their result files. A late failed attempt cannot replace a successful device-source recovery. Restart reuses the frozen plan and rejects a changed analyser. Thirteen campaign and pool checks passed. Real-track throughput and result comparisons remain pending.


## Full-library capacity checks

The dedicated Mac cloud job can import and upload 512 saved revisions per cycle, in groups of 32. Device sync retains its existing limits. The focused transfer-limit and conflict checks passed. Fourteen Python checks passed, including a compact progress cache that excludes audio features from memory.

A 15-item trial covered 14 audio identities. Four workers took 54.41 seconds, compared with 51.00 seconds for one. A larger 60-file trial took 126.55 seconds with four workers and 168.59 seconds with one. These runs shared the Mac with the existing analysis job. Part of the parallel trial also overlapped host compilation. These measurements are operational comparisons, not isolated throughput guarantees.

The larger trial completed 59 parallel and 58 serial analyses. Every completed result retained the earlier musical decisions. Comparisons exclude completion dates and allow absolute numerical differences below 0.0000001 or relative differences below 0.000000000001. Untouched and Dune retained their corrected results. Raw outputs and comparisons remain under `pool-proof` and `pool-proof-60` in the external run folder.

The incomplete trials exposed variable MP3 tail padding in Apple's asset decoder. Eight repeated decodes of each affected file produced identical shared audio prefixes, with a 529-frame difference at the end. This occurred in serial decoding too. The Mac now allows three MP3 decode attempts when a saved device identity exists. Each attempt must match the complete saved hash. Other mismatches still require the exact device copy. Evidence remains under `decode-proof`. The signed Mac check retained all three reference-track decisions and rejected the deliberately wrong identity. Both affected MP3s still failed that check after retries. Their results remained excluded from sharing and require exact-source recovery.

Build 224 installed on the iPad and Duo. The Duo remains locked, so launch and receipt are unverified. The iPad continued automatic downloads. Of the 382 pending uploads captured before the conflict fix, 32 had cleared at the later snapshot. Other uploads and automatic-cycle deadlines remain visible. The full run and all-device delivery remain incomplete.


## Active campaign v5

At 15:53 UTC on 10 November 2026, campaign v5 replaced the single Mac analyser with four workers. It retained 1,433 terminal attempts and the interrupted checkpoints. The previous cloud operation finished before the replacement started. The existing device-source recovery worker continued without interruption.

The signed library runner comes from canonical `main` at `057475342a10e41f593eaa5ad327b22f7df41ae5`. Its executable and frozen script hashes are recorded in `source-v5.json`. The app is `LibraryRunner.app` in the external run folder. Earlier apps, scripts, manifests and failed evidence remain retained.

The Mac completed a new larger upload cycle. The copied iPad library contained 733 exact Mac deep results. All 940 protected grids checked retained their timing. One JSON round trip changed the displayed anchor by less than 0.000000001 frame. The raw before/after values remain in `ipad-adoption-proof-224.json`.

The frozen full-library phase remains queued after iPad processing and receipt. It uses the same four-worker plan. The controller retains checkpoints, explicit exceptions and pending cloud delivery. The Duo is on build 224 but locked. The iPhone remains unavailable. The campaign is still in progress, and no whole-library or all-device completion is claimed.

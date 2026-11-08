# CloudKit and TestFlight implementation plan

Request: R86. Follow the approved local-first recommendation in this chat. Work serially in this folder. Preserve the installed bundle ID and workspace path.

## Design

Keep the existing local library as the playback source. Use the private database in `iCloud.org.generikdj.analysis`. Retain immutable preparation revisions so sync cannot overwrite a previous version or spread a local deletion. Include analysis, manual preparation, cues, cue deletion history, sections and waveform data. Audio files remain outside sync.

The first TestFlight increment exposes explicit sync and recovery controls in Library settings. Transfer one track at a time. Stop transfers when playback, recording or loading starts. Do not change loaded decks. Downloaded revisions stay separate until the user selects a matching revision to restore. Apply recovery at the next launch, before the library opens. Require the full audio hash, sample rate, channel count and frame count to match. Preserve a local revision before restoration. Reject recovery if local preparation changes after scheduling. Never match titles or the opening-audio fingerprint.

Use CKSyncEngine with automatic scheduling disabled. Persist engine state and pending local revisions. Confirm upload status only after server acknowledgement. Isolate account state and retain local data across account changes. Never upload records staged for a different account.

## Implementation and checks

- [x] Add a versioned per-track preparation archive and validation. Test round-trip preservation, deliberate cue clears, malformed data, mismatched audio and retention of previous versions.
- [x] Add the private CloudKit transport with durable state, bounded batches and cancellation. Add explicit sync/recovery UI and playback gating. Test offline persistence and the playback gate without contacting CloudKit from host tests.
- [x] Add entitlements and the CloudKit schema. Validate the schema in development and deploy it to production for TestFlight.
- [x] Add an archive/export action to the existing numbered iPad build tool. Preserve source hashes, logs and failed attempts. Build only from committed main.
- [x] Prepare and validate an App Store distribution archive. Upload only the requested TestFlight candidate, without adding external testers or submitting an App Store release.

## Verification limits

Host checks and signing do not establish A10X performance. Verify real account sync, restoration, interruptions, offline use and playback on the iPad before accepting this feature for a set. Automatic conflict merging, scheduled sync and Mac preparation remain separate follow-up increments.

## Apple registration

- Team: `54WU29TRTY`.
- Bundle ID: `org.generikdj.replica.audiocheck`.
- App ID: `J3FWS4LJ4Z`.
- Container: `iCloud.org.generikdj.analysis`.
- App Store Connect app: `6832211854`.
- App Store Connect name: GenErik DJ. Primary language: English (Australia).
- The app record uses limited access. No tester invitations or App Store submission were made.

- Apple validated the development schema and deployed it to Production on 8 November 2026. PreparationRevision grants read/write access to its creator.

## TestFlight checks for Erik

1. Stop the decks and recording.
2. Open Settings → Library → iCloud preparation.
3. Select Sync now.
4. Wait for the confirmed revision count.
5. Repeat on another device with the same iCloud account.
6. Import the same audio file and complete its analysis.
7. Select a saved preparation revision.
8. Select Restore at next launch.
9. Close and reopen the app.
10. Check the grid, key, cues, cleared cue slots, sections and waveform.

Also test interrupted sync, an offline retry and playback started during sync. Check audio and control response on the A10X. Test account switching without moving one account's retained revisions into another account. A downloaded revision does not replace local preparation until recovery is selected.

Cloud sync is an additional recovery copy. It does not copy audio files or replace an independent backup. Mac integration and automatic scheduling are not included in this increment.

## Distribution preparation

The archive includes a privacy manifest for existing app behaviour. It declares app-only settings, local/user-selected file metadata, elapsed-time measurements and storage checks before model downloads. These declarations follow [Apple's approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

Build 145 archived and passed runtime-path and signing checks. Export failed because Xcode's Apple rsync invoked Homebrew rsync through PATH. The export process now selects Apple command-line tools first. Build 145 and its failed logs remain retained. The next candidate adds the privacy manifest.

Build 146 exported successfully. Its signature, Production CloudKit settings, push environment and privacy manifest passed inspection. Apple rejected the upload because Xcode 27.2 beta (27B5019j) is no longer supported. Rebuild the same app source with installed Xcode 27.1 (27A9275). The distribution tool now records the compiler and selects the installed release by default. This does not change the system's selected Xcode.

Build 147 (0.1.0), from main at `58a198cca`, exported with Xcode 27.1 and uploaded successfully. The exported package passed signature, SDK, Production CloudKit, push and privacy-manifest checks. Apple completed processing. The build shows Ready to Submit. Test notes are saved in English (Australia). No testing group is assigned. Thirteen focused Swift tests and four release-tool tests passed. No device installation or tester invitation was made.

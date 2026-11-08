# CloudKit and TestFlight implementation plan

Request: R86. Follow the approved local-first recommendation in this chat. Work serially in this folder. Preserve the installed bundle ID and workspace path.

## Design

Keep the existing local library as the playback source. Use the private database in `iCloud.org.generikdj.analysis`. Retain immutable preparation revisions so sync cannot overwrite a previous version or spread a local deletion. Include analysis, manual preparation, cues, cue deletion history, sections and waveform data. Audio files remain outside sync.

The first TestFlight increment exposes explicit sync and recovery controls in Library settings. Transfer one track at a time. Stop transfers when playback, recording or loading starts. Do not change loaded decks. Downloaded revisions stay separate until the user selects a matching revision to restore. Require the full audio hash, sample rate and frame count to match. Preserve a local revision before restoration. Never match titles or the opening-audio fingerprint.

Use CKSyncEngine with automatic scheduling disabled. Persist engine state and pending local revisions. Confirm upload status only after server acknowledgement. Isolate account state and retain local data across account changes. Never upload records staged for a different account.

## Implementation and checks

- [ ] Add a versioned per-track preparation archive and validation. Test round-trip preservation, deliberate cue clears, malformed data, mismatched audio and retention of previous versions.
- [ ] Add the private CloudKit transport with durable state, bounded batches and cancellation. Add explicit sync/recovery UI and playback gating. Test offline persistence and the playback gate without contacting CloudKit from host tests.
- [ ] Add entitlements and the CloudKit schema. Validate the schema in development and deploy it to production for TestFlight.
- [ ] Add an archive/export action to the existing numbered iPad build tool. Preserve source hashes, logs and failed attempts. Build only from committed main.
- [ ] Prepare and validate an App Store distribution archive. Upload only the requested TestFlight candidate, without adding external testers or submitting an App Store release.

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

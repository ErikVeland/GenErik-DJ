# Local and synced Music library

Documentation reviewed against the shared implementation on 30 October 2026. [Current readiness and verification](Status.md) is the implementation status record. Dated measurements below apply only to their recorded source and workload.

The performer confirmed local/synced iTunes and Apple Music library access on 23 October 2026. Subscription streaming is excluded. This implementation reads the system library and prepares selected local audio for the existing analysis, recommendation inputs and deck-loading workflow.

On 24 October 2026, the performer confirmed that this must work the same with the iPad's own library. The iPad is a required target. It must not depend on a running Mac or a manual Files export. Mac verification and iPad compilation are intermediate checks, not completion of this requirement.

## Required iPad device acceptance

The same shared browser and preparation workflow must pass these checks on an authorised test iPad:

1. Grant Music library permission and browse that iPad's synced songs and playlists.
2. Search by title, artist and album, and retain the source playlist order.
3. Prepare available local/synced audio, including native `ipod-library` assets, without a Mac connection.
4. Retain title, artist, genre and available artwork with the analysed song.
5. Load the prepared song into either deck and play it through the shared master-tempo and early-Play path.
6. Save a grid correction, restart the app and retain the correction and source identity without a duplicate import.
7. Refresh after syncing another song or changing a playlist in Music, and show the new source state.
8. Handle denied access, missing local audio and preparation cancellation without losing prepared songs or interrupting existing playback.

These device checks are pending. Existing synthetic workflow tests and Mac asset decoding do not exercise the real iPad media library. The latest requested test could not operate the iPad: this session denies Apple device-service access and disables sandbox approvals.

## Use the development build

1. Open the packaged Mac app and choose **Music library**.
2. Allow Music library access if the operating system asks.
3. Choose a playlist or search by title, artist or album.
4. Select songs and choose **Add selected**. **Select available** selects available songs in the current results.
5. Choose **Done** to return to the decks at any time. Preparation continues in the background; completed songs appear in Songs and can be loaded through the up-for-A/down-for-B slider. Reopen **Music library** to review progress or stop the batch.

**Refresh** reads the current system library again when preparation is idle. **Stop** cancels preparation after retaining completed songs. Preparation failures appear beside the affected songs. Other selected songs continue. The model owns the batch, so closing its sheet does not cancel it or keep the performance controls covered. Orderly shutdown cancels the owned batch before finishing persistence.

The model also owns a pending library read. Closing the sheet does not discard its result, and reopening shares that read. Shutdown cancels publication without waiting for a stalled system service. A scalar catalog revision triggers browser updates without comparing every song and playlist on the main thread. `Validation/owned-native-library-refresh-tests.log` covers cancellation of the sheet's caller and coalescing on reopen.

Opening the browser does not prepare the whole library. Playlists retain source order within the browser. Search and playlist filtering do not change the system Music library. Source playlists are not copied into a new editable playlist system.

A song must expose accessible local audio. A cloud-library flag alone does not disqualify a downloaded song. Songs without local audio show a download/sync message. Protected songs are unavailable for mixing. The adapter accepts file and iPod-library asset URLs and rejects network URLs. It does not stream, download songs or change Music settings.

## Platform adapters

On macOS, `iTunesLibrary.ITLibrary` supplies the current library's songs and playlists. A serial background worker owns initialization, metadata scans and local-file checks. The library handle stays on that worker. A live stack sample on 28 October 2026 confirmed that initialization can wait synchronously for a Music service reply. Keeping that wait off the main thread protects the performance controls. Moving the call does not prove the system service will finish. The captured wait is retained in `Validation/music-library-hang-sample.txt`.

The [29 October live follow-up](Validation/LiveMacControls-2026-10-29-01/manifest.json) verifies native refresh completion with 115,219 songs and 401 playlists, title/album search, playlist selection, preparation of one local AAC item, directional deck loading and live playback with recording. Done, the tempo wheel and normal Quit responded during an earlier pending native read. Startup was slow; separate signed read-only main/background probes both completed, so these checks do not establish a thread-only cause or guarantee future service latency. No Music settings, source files or system playlists were changed. The full catalog was browsed, not imported.

On iPadOS, `MediaPlayer.MPMediaLibrary` requests permission when the browser opens. `MPMediaQuery` supplies songs and playlists. Before preparing a song, the adapter checks authorization and resolves its current persistent ID again. Library artwork is retained when available.

Both app packages declare `NSAppleMusicUsageDescription`. The Mac development package is not App Sandbox enabled. A future sandboxed Mac distribution must supply the appropriate read-only music-file entitlement and verify access in that distribution.

## Audio and identity

Local file URLs use the existing copied-file import path. iPad `ipod-library` assets are decoded with `AVAssetReader` to a temporary Float32 PCM CAF, then imported and analysed. This avoids a lossy intermediate encoding. Temporary decoded files are removed after preparation, cancellation or failure. The retained workspace copy supports playback after preparation.

Library title, artist and genre accompany the audio. Embedded artwork remains available for direct-file imports. The iPad adapter obtains artwork from the library before decoding, since the temporary PCM file does not carry the source tags.

Each prepared track can retain namespaced Mac/iPad persistent source IDs. The existing content SHA-256 remains the internal track identity. Adding an already imported recording attaches its source ID without discarding manual grids or analysis. If a source ID later refers to different imported content, its link moves to the new track while the old prepared track remains intact.

Source links persist in the atomic workspace snapshot. The collection uses the [compact index and per-track waveform storage](Storage.md); routine metadata changes do not rewrite every waveform. Existing snapshots without this optional field still load. Import and analysis do not create performed-transition history or resolve the original recommendation calibration.

## Verification and limits

`Tests/TDJCoreTests/MusicLibraryTests.swift` covers playlist order and search, library metadata, source identities, repeat imports, saved corrections, legacy snapshots, changed source content and lossless stereo asset decoding. It also rejects network URLs and protects an existing preparation file.

`Tests/TDJInterfaceTests/MusicLibraryWorkflowTests.swift` covers explicit access, permission errors, failure isolation in a batch, unavailable/protected songs, repeat selection, temporary-file cleanup and a prepared song reaching audible offline deck output. These workflow tests use an injected library provider and synthetic audio.

Native Mac browsing/import evidence and current build results are recorded in `Validation/music-library-validation.json`. Cross-compilation does not establish real iPad Music-library access. The requested real iPad run remains blocked by device-service permissions; no deployment or physical acceptance was completed.

The development toolbar and preparation sheet provide access to this implementation. They do not establish the original TDJ1 browser geometry or gesture fidelity. Original recommendation fidelity, the normal iPad sharing workflow and end-to-end library acceptance remain open. AIFF recording and native sharing are implemented; retained diagnostic iPad recordings have been copied and format/frame checked on the Mac. The native system-share route and full-length recording still need acceptance.

Implementation references: [Apple ITLibrary](https://developer.apple.com/documentation/ituneslibrary/itlibrary), [media asset URLs](https://developer.apple.com/documentation/mediaplayer/mpmediaitem/asseturl), [library authorization](https://developer.apple.com/documentation/mediaplayer/mpmedialibraryauthorizationstatus), and [asset-reader audio output](https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput).

## Analysis versions and original preparation

New imports use the versioned analyser described in [Analysis.md](Analysis.md) unless a complete supported original TDJ reference is available. Choose **Import Traktor preparation** and select `collection.nml.gz` or `collection.nml`. The Mac can discover its conventional TDJ iCloud file; the iPad requires a one-time Files grant to a collection copy. Audio preparation still uses the iPad's own Music library and does not require audio-file export or a running Mac.

The [production TDJ1 NML17 importer](TraktorPreparation.md) matches exact native persistent IDs with duration verification. It retains original bytes and source provenance; original musical preparation stays separate from independent analysis. Complete supported references bypass independent BPM/key/downbeat analysis while generating the waveform. Missing energy remains unknown. Existing prepared native-library songs can acquire preparation without decoding again; currently loaded songs and manual edits are protected. Cue import history preserves deletions across restart.

The real current and older collections (5,995 and 10,881 records) pass production parsing/archive import. These are reference metadata checks, not completed paired-audio or physical iPad tests. Original display/identity verification and the ten-track real comparison remain open. The import feature does not establish NI analysis quality.

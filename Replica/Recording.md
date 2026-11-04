# AIFF set recording

Current build and acceptance: [project status](../docs/coordination/README.md). Historical measurements apply only to their recorded source.

The recorder implements core performer requirement 8: capture the performed master output as AIFF and provide a transfer route to the Mac. This is a development implementation. It does not establish full TDJ1 recording fidelity or complete physical-device acceptance.

## Use

1. Choose **Record** in the bottom development toolbar, enter a venue or location, and choose **Record** again. An empty location is named `Unknown Location`.
2. Perform the set with the available deck controls.
3. Choose **Stop recording**.
4. Open **Recordings**.
5. Choose **Share AIFF** or **Share tracklist** for a saved set. On iPad, use an available system destination such as AirDrop or Save to Files to transfer either file to the Mac.

Recordings and tracklists use the same filename, containing the entered location, local date and time, and a short unique suffix. They are saved in `Recordings/` inside the app workspace. The Mac default is `Replica/.workspace/Recordings/`. On iPad, the development app exposes `GenErikDJ-Development/Recordings/` in its Files storage. Existing recordings remain discoverable in the same folder; old recordings do not gain a reconstructed tracklist. Sharing exports the completed files without converting the audio. Physical iPad Files access has not yet been verified.

## Tracklists

Each completed new recording has a UTF-8 `.txt` file, with one line per loaded deck generation that contributes audible audio to the recorded master: `HH:MM:SS - Artist - Track Title (Version)`. The timestamp is measured from the start of the recording to the first audible sample. Overlapping decks can both appear; headphone-only and muted playback are excluded. The version is included when it is part of the stored track title. Missing metadata is labelled `Unknown Artist` or `Unknown Track`.

A bounded native event buffer captures the first audible frame without file I/O, allocation or waits on the audio thread; the file writer resolves metadata and writes the list. If the 4,096-event capacity is exceeded, recording finalisation reports an error and retains the incomplete audio. The same applies when tracklist writing fails.

## Capture and format

The capture point follows the transport's stereo summing and output gain, including Keylock processing. The master path includes deck volume, crossfader, EQ, filter and the development FX slots. Effect tails continue into the recording after a deck pauses; otherwise paused decks and queued launches contribute silence. The separate headphone bus is excluded from recording. Physical Z1 routing validation remains unfinished.

The default output is 48 kHz, 24-bit signed, big-endian stereo PCM in an AIFF container. A transport constructed at another sample rate records at that rate. These are development choices. The user requires AIFF, but has not specified bit depth or sample rate. Existing original exports are WAV files.

The audio callback copies into a preallocated 480,000-frame C buffer. It performs no file writes, allocation, locks or waits. A serial file queue drains the buffer every 20 ms. Stop closes capture, drains accepted frames, finalises the header and renames the temporary file. The temporary filename ends in `.incomplete.aiff` and is excluded from the saved-set list.

The recording controller now closes the capture gate synchronously when handling Stop. This atomic request does not wait for a callback that already owns the gate. The serial recording writer joins that accepted copy before its final drain and file close; later callbacks are excluded. The recording buffer now also retains bounded track events for the accepted audio frames. [Focused handoff checks](../docs/history.md#local-validation) retain the gate model, sanitizer checks, sample/file tests and executor scope. The earlier async finish already ran off the main actor; this is not a claim that it previously blocked the UI.

An overflow or write failure prevents publication as a successful recording. The incomplete file is retained and the error is reported when recording finishes. Classic AIFF's size limit is guarded before 4 GiB, approximately four hours at the default format. Automatic splitting is not implemented. Levels outside the integer PCM range clip during conversion. There is no added limiter.

Stop audio, an audio interruption and engine reconfiguration finalise the recording. The iPad target now declares background audio and preserves active playback/recording when its scene backgrounds. Normal Mac quit and view closure wait for recording finalisation. These lifecycle choices are not original-app fidelity claims, and physical iPad background behavior remains unverified. Force quit, crashes or power loss can leave an incomplete file. Recovery of such files is not implemented.

## Validation on 25 October 2026

- A two-deck rendered mix is recorded after master gain. Decoded samples match both output channels within 24-bit conversion tolerance.
- The file reports `FORM` / `AIFF`, stereo, 48 kHz and 24 bits. Its frame count excludes audio before start and after stop.
- A local file copy is byte-identical and opens with the expected audio format and duration. This is not an iPad transfer test.
- Ring wrap, stop/restart isolation, concurrent capture and file draining, overflow rejection, saved-set discovery and Stop audio finalisation have dedicated tests.
- The shared interface compiles for the ARM64 iPad simulator SDK. No device was contacted or deployed to.

Logs: `Validation/recording-tests.log`, `Validation/recording-focused-tests.log` and `Validation/recording-ipad-compile.log`. The rendered development interface is `Validation/recording-preview.png`.

## Remaining acceptance

The [29 October native Mac workflow](../docs/history.md#local-validation) records a newly prepared local Music item through the live app. Stop audio finalised a 48 kHz, 24-bit stereo AIFF containing 432,128 frames (9.0027 seconds), and the file appeared in Recordings. Container and payload lengths match; samples contain nonzero audio and no integer-rail values. This checks the current native route, not listening quality, recording under sustained load or iPad-to-Mac transfer.

On 26 October 2026, `RecordingEffectsTests.swift` also verifies that both AIFF channels match the rendered master, including a delay tail after the source deck pauses. The 8,500-frame recording matches within 24-bit conversion tolerance. See `Validation/recording-effects-tests.log`. This verifies the replica's capture path, not the original effect sound.

On a separately authorised test iPad, record a known mix, share the AIFF to the Mac, open it, and compare duration, format and audio. Verify interruption and storage failure handling on that device. Run a sustained recording under realistic load before using it for a gig. Saved recordings now have Load A/B controls through the normal library path. Match the original recording entry, indicators, browsing and load-to-deck gestures against the installed reference. None of these checks authorises access to the parked gig iPad.

Adaptive suggestion fidelity, physical Z1 acceptance and exact SuperSlicer behaviour remain unfinished. SuperSlicer families and all eleven named effects have development implementations. This recording work does not close those gaps.

## Later diagnostic evidence — current scope

The signed27 five-minute GenErik diagnostic runs retained complete AIFF captures and copied-file format/frame checks. Every captured frame reached its file. This is diagnostic transfer evidence from an older source, not acceptance of the normal Share AIFF workflow, listening quality, gig-length recording, four-channel hardware routing or current-source interruption behaviour. See [Status.md](Status.md).

## Tracklist integration — 30 October 2026

The recording and tracklist changes were integrated from a guarded candidate after the user requested integration. Focused offline tests and an iOS simulator package build are recorded in `../Private/RecordingTracklist-2026-10-30/`. Synthetic Mac stress runs for both this candidate and the previous renderer exceeded their callback deadlines; they do not establish an added regression or gig-ready performance. The full test run encountered a sandbox Core Audio initialisation crash and did not complete. Physical iPad recording, Files access, sharing, and sustained audio/control performance remain unverified.

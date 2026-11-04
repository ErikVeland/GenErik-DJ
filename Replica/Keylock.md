# Keylock development implementation

Current build and acceptance: [project status](../docs/coordination/README.md). Historical measurements apply only to their recorded source.

Keylock now separates source pitch from the shared master tempo. A synced deck follows the selected BPM while its tonal content retains source pitch. Disabling Keylock restores variable-speed pitch. Sync controls musical speed and phase. Keylock controls pitch treatment.

This is a working reconstruction, not a verified match to NI's DSP. No original TDJ1 audio was captured during this phase. The gig iPad was not accessed, connected, modified or used for tests.

## Performer route and evidence

Load A and B through the existing directional load handles. Keylock starts enabled per deck in this development shell. Start A, change master tempo with the wheel, then pre-press B's Play as before. B retains its source position and contributes no audio before its launch. Keylock does not add a wait to the musical scheduler.

Use the note icon in the development toolbar to toggle Keylock for either deck. A lock beside its key indicates the acknowledged on state. The choice is retained across loads within this session. It is not written into the track's source key or prepared grid. Sync does not change when Keylock changes, and Keylock does not change when Sync changes.

NI's S4 Mk2 manual explicitly documents SHIFT+PLAY for a TRAKTOR DJ deck's Keylock in section 5.2.1. Its manual-mixing route requires Sync and Keylock off. See the [retained manual text](../Analysis/Traktor-DJ-1x/sources/traktor-kontrol-s4-mk2-manual-en.txt) and [transport evidence](../Analysis/Traktor-DJ-1x/03-transport-sync-and-queued-starts.md). This does not establish an iPad touch control. Hardware mapping is still unfinished.

The development menu, enabled startup state and session retention are provisional. Q12 remains open: enabling Keylock at a changed speed might lock source pitch or the pitch heard at that instant. This build uses source pitch, as requested for master-tempo changes. Original defaults, restart persistence, switching ramp and pending-action policy remain unmeasured. A Keylock change on a queued deck is rejected without changing its existing queue. This gate is a development guard, not an original NI rule.

## Sound path

Each deck has a preallocated instance of [Signalsmith Stretch](https://github.com/Signalsmith-Audio/signalsmith-stretch), pinned to version 1.3.2 source commit `a670068d9aeb64913331d5cc29337b19a457a7df`. Its MIT licence and the Linear dependency's licence are included in [third-party notices](THIRD_PARTY_NOTICES.txt). The [provenance manifest](Calibration/keylock-dsp-provenance.json) records both commits, original hashes and the local patch. No dependency download occurs during a build.

The processor uses the library's default 120 ms spectral block and 30 ms interval, with split computation. The source is read at its native pitch on the output-rate timeline. A fractional input counter supplies the requested speed ratio without cumulative integer rounding. Mid/side processing preserves mono and opposite-polarity relationships. General stereo image and transient quality still need original comparisons.

Production source reads use the bounded PCM pool. The stream planner includes the processor’s required pre-roll and read-ahead; storage work stays outside rendering. Immutable mapped sources remain the numerical reference path. The library's output-seek method compensates its input and output look-ahead before the first output sample. The musical scheduler retains its sample timeline. It gates the complete incoming output until the target bar, including any spectral pre-ringing. Its start frame is unaffected by the DSP window length.

The processor maintains a fixed 64-frame output quantum. It consumes every generated sample before applying the latest DSP rate. The clock and source-position timeline use the new tempo immediately. Initial native-speed playback bypasses stretching exactly. Once active, stretching stays active through native-speed crossings until Keylock is disabled or the source resets. Spectral windows can still spread a transient or respond across a tempo change. Exact NI transient shape and automation response are not inferred from clock accuracy.

EOF follows the existing logical source bound. Residual stretch output is not flushed beyond that bound. Original pause, seek and end-of-file sound still require matching. Production uses bounded streamed pools and immutable published tables. Whole-file mapping remains a comparison path. Memory-pressure behaviour still needs current-device acceptance.

Live switching uses a five-millisecond linear transition. Initial native-speed bypass and phase retention through later native-speed crossings are development sound choices. Source-rate conversion still uses linear interpolation, so its high-frequency response and alias rejection are not matched to NI. The technical speed-ratio guard is 0.125–8, and transport output supports 8–384 kHz. Unsupported Keylock actions return an error and retain the current tempo/state. These are not recovered TDJ1 ranges or quality claims at their extremes. The library recommends more modest stretch changes for its best sound.

The callback does not configure or allocate processors. Configuration and storage reservation occur when the transport is created. Local library changes reserve all spectral bins for peak storage during configuration and let guarded reset pre-roll skip bookkeeping for complete intervals whose output is discarded. The final partial interval retains the original path. The 810-case offline comparison, including sanitizer checks, produces byte-identical output; see [validation](../docs/history.md#local-validation). Processing uses existing storage. The local allocation probe counts ordinary C++ `new` and `new[]` calls during rendering, including first Play, queued Play, tempo change and live switching. It does not audit every allocation mechanism or establish device-wide real-time performance.

## Validation and listening examples

Run the full suite with `./Scripts/check.sh`. The new signal checks cover locked and unlocked pitch, source/output sample-rate conversion, exact unity bypass, stereo polarity, callback partition independence, live toggles, tempo automation, queued silence, bounded EOF, stale generations, unsupported ratios and per-deck session state. Analysis, gridding and adaptive-suggestion checks remain in the suite.

Run `.build/debug/tdj-tool keylock-probe Validation/Keylock` to generate the [pitch measurements and audio list](../docs/history.md#local-validation). A 440 Hz source is measured at 80%, 107.5% and 125% speed, with and without Keylock. The listening examples use a generated chord, kick, snare and stereo hat. They contain no original recording or TDJ1 output:

- [120 BPM reference](../docs/history.md#local-validation)
- [129 BPM with Keylock](../docs/history.md#local-validation)
- [129 BPM without Keylock](../docs/history.md#local-validation)
- [96 BPM with Keylock](../docs/history.md#local-validation)
- [150 BPM with Keylock](../docs/history.md#local-validation)

Run `bash Scripts/check-keylock-render.sh` for a separate local C++ allocation and callback-duration probe. Its [result](../docs/history.md#local-validation) reports the measured timings. It uses synthetic audio and performs no device actions. It is not a sustained-load benchmark and does not measure DAC or speaker latency.

The initial short local probe counted zero ordinary C++ allocations over 3,000 callbacks. At 128 frames / 48 kHz, the buffer duration is 2.667 ms. Median wall time was 0.030 ms, the 99th percentile was 0.060 ms, and the maximum was 0.855 ms. Maximum thread CPU time was 0.812 ms. No wall-time deadline was exceeded in that run. A [concurrent-build run](../docs/history.md#local-validation) reached 3.206 ms, exceeding one buffer duration. Both results are retained. This normal-priority command-line probe does not certify audio-thread scheduling under load.

The native Mac check used the original synthetic 120 and 128 BPM fixtures. The development menu changed A's Keylock without changing B's state. With both locked, B launched at output frame 96,000 after A started at frame 0. Rotating master tempo to 129 updated both synced rates while both Keylock indicators stayed on. The [stopped snapshot](../docs/history.md#local-validation) records that run. Pitch was measured separately through the same render core. Speaker output was not recorded.

See the [stress report](Stress.md) and [earlier stress validation](../docs/history.md#local-validation) for subsequent fixes, sustained results and limits. The [initial Keylock validation](../docs/history.md#local-validation) remains the earlier phase record. Exact matching still requires original output at the same source positions and tempo ratios, including vocals, dense chords, sharp drums, silence, live enable/disable and rapid tempo changes. That comparison remains parked until a safe reference source is available.

The [native 128-frame follow-up](Stress.md#native-128-frame-follow-up) moves initial mapped-page reads to background track preparation. The five-minute run passed with 79 exact starts. A shorter repeat still logged one HAL overload and timestamp gap. The DSP and Keylock interaction rules are unchanged.

The [HAL isolation investigation](Stress.md#remaining-hal-isolation) keeps the DSP unchanged. After the user closed the competing Mac output client, the five-minute 128-frame test passed 112,504 callbacks and 79 exact logical starts with zero HAL overloads, timestamp gaps or render deadline overruns. The maximum mixer cycle was 0.921 ms against a 2.667 ms period. The original buffer restored to 512 frames. The earlier fault's cause remains unproven. The activity-hint experiment did not eliminate the fault and was reverted.

## Latest source and device scope

Production output now uses the Objective-C++ native source bridge documented in Playback.md. The recorded signed27 A10X five-minute panel checks exercised roughly 1.867–2.133 tempo ratios with 48 kHz and 44.1 kHz source fixtures. Those passing measurements belong to that older exact source, used silenced hardware output and do not verify current-source auditory quality, extreme ratios or physical touch. See Status.md.

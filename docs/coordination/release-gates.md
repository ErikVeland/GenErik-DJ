# A10X performance acceptance

The main goal is a performance-ready app on Erik's 2017 10.5-inch A10X iPad Pro. Live sets must have uninterrupted audio and consistently responsive UI. TDJ1's performance is Erik's reference standard.

Any audio gap, dropout, click, crackle, visible stutter, UI stall, missed touch or delayed performance control blocks acceptance. Features and background work must fit this requirement. Pause, defer or cancel secondary work before it compromises performance. Do not relax deadlines to obtain a pass.

## Source and build

- Verify the exact signed Release app and source installed on the A10X iPad.
- Retain test conditions, results and failures against that source.
- Keep a saved app and rollback route.

## Audio and UI together

- Exercise two decks, fixed/adaptive Sync, scratch, loops, slices, Flux, six FX slots and recording.
- Include loading, cancellation, library browsing/search, analysis and other enabled background work.
- Require zero callback deadline misses, source starvation, invalid audio and recording drops under the existing gates.
- Require zero missed control deadlines. Verify actual frame presentation and physical touch response alongside audio.
- Check moving waveforms, panel changes and browsing for visible stutter or freezes during playback.
- Verify route changes, queued starts, recovery, Brake and deck replacement without unintended audio or control interruption.

Deadlines belong to the actual sample rate, callback size and workload. The retained 512-frame/48 kHz workload allows 10.667 ms per callback and 20 ms for exact control completion. Preserve each workload's existing limits. These numbers do not define a UI frame budget or prove sustained A10X performance.

## Real setup and sustained use

- Use the real library, preparation, output route, headphones and required controller.
- Listen through performance gestures, Sync, keylock, loops, effects, recovery and recording.
- Check both decks, intended orientations and the separate phone layouts where applicable.
- Measure memory and thermal behaviour through a representative sustained set on the A10X.
- Verify recording, tracklist and transfer on the actual device.
- Obtain Erik's acceptance of sound, touch, UI continuity and continued operation before claiming gig readiness.

Host timings, compilation, launch and repository cleanliness do not establish this acceptance. Build 112 remains a test candidate with physical performance acceptance open.

The [single-change iPad loop](../testing/README.md) continues during development. Full qualification is separate and user-directed. Install when Erik hands over for testing, then stop device actions after launch.

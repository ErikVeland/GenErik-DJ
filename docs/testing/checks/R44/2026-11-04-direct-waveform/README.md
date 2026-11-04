# R44: direct waveform manipulation

Erik reports reversed movement and missing weight when he drags the waveform. The report assumes build 98, the last recorded iPad installation.

The detailed waveform now follows finger displacement from the grab point. Rightward movement decreases the source frame. The audio command applies position and speed together. A stationary contact holds the source. Release uses exponential scroll deceleration. A new contact catches the throw. Track changes, mode changes, cancellation, hidden surfaces and transport takeover end motion. Existing Flux return and paused/playing release policies remain in use.

## Focused evidence

- `motion.log`: 93 assertions pass across spans and grab positions. Checks include direction, displacement, reversal, release continuity, decay, rest and track boundaries.
- `native.log`: direct position, held stop, reversal, paused/playing release, Flux and existing Scratch checks pass at 44.1, 48 and 96 kHz. Output remains finite and bounded. Repositioning retains the preceding output sample at the transition edge.
- `isolated-session.log`: two tests pass against the real model and gesture session. They cover slow movement, held position, throw, catch and cancellation.
- `red.log`: the baseline rejects the direct position-and-rate command. The failed command and its assertion remain recorded.
- `session.log`: the package runner cannot start because existing MIDI tests use optional chaining on arrays. The isolated runner bypasses those test files. Its initial framework, include, macro and runtime setup failures remain recorded separately.

These checks use the R44 application changes in `e72fde5b6`. The later merge `63c80376f` also retains R45 immediate-loading changes. The combined host check stopped because another task modified `BeatGrid.swift` during compilation. The isolated signed iPad build has a separate record. No physical feel or listening acceptance is inferred from these checks.

The EOF regression first failed, then passed at all three sample rates. A direct contact now resumes playback and the clock when it moves back from the track ending. Build 102 was stopped before installation for this correction. Its interrupted record and log remain available.

## Remaining acceptance

Test both decks in each direction. Grab the waveform near either edge and in the centre. Hold, throw, catch and reverse it. Check track boundaries, Sync takeover, Flux return, cancellation and clean audio. Physical feel, latency and uninterrupted audio remain Erik’s acceptance tests.

The isolated session runner links existing package objects. Build the `TDJInterface` target from the intended source before using it. The passing session record above used the objects from the first package attempt.

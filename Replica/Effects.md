# Effect implementation and remaining fidelity

Documentation reviewed against the shared implementation on 30 October 2026. See [current readiness](Status.md) for source and verification scope.

The shared catalog exposes eleven effect IDs, three slots per deck and one selected-slot XY pad. These are independent implementations. Named effect coverage does not establish NI sound or original parameter curves.

| ID | Effect | Current implementation |
| --- | --- | --- |
| 0 | Delay | Feedback delay with per-slot SYNC/FREE timing and crossfaded delay-tap changes |
| 1 | Reverb | Eight-line stereo feedback-delay network, input diffusion, early reflections, damping and DC removal |
| 2 | Flanger | Modulated short delay |
| 3 | Gater | Beat-dependent amplitude gating |
| 4 | Beatmasher 2 | Beat-related capture and buffer slicing |
| 5 | Digital LoFi | Quantization and sample-and-hold rate reduction |
| 6 | High-pass | Ramped state-variable high-pass filter |
| 7 | Low-pass | Ramped state-variable low-pass filter |
| 8 | Iceverb | The stereo feedback-delay network with a longer decay and different input/tone treatment |
| 9 | Transpose Stretch | Four overlapping Hann-weighted live read heads over an 80 ms grain window |
| 10 | Reverse Grain | One-beat capture with four overlapping reverse-grain windows |

Y controls slot wet/dry mix. The selected slot retains contact ownership until release or cancellation; slot selection changes during a hold are deferred. Locks retain released effects. Persistence stores effect parameters, lock state and delay timing mode; legacy data without a delay mode defaults to SYNC.

## Timing and sound policies

Delay SYNC uses master-tempo divisions of one-quarter, one-half, one, two and four beats. FREE maps X from 25 to 2,000 ms. The internal beat calculation clamps the tempo to at least 30 BPM. These are explicit development mappings.

Reverb X selects a decay from 0.35 to 8.4 seconds. Iceverb X selects 1.5 to 18 seconds. Their network has eight prime-length tank lines, four input all-pass diffusers per channel, predelay, early reflections, feedback damping and DC removal. Parameter ramps and history invalidation preserve bounded state transitions. This supersedes the earlier simple feedback/four-tap descriptions; neither algorithm is claimed to match NI.

Transpose has an 80 ms window and four read heads. Its cached ratio spans -60 to +12 semitones, with centre neutral. Reverse Grain captures up to one beat within the available eight-second history, then advances its captured traversal at half speed while its grain reads run backwards. Re-enabling starts a fresh capture. Neutral pitch and synthetic tone checks do not establish transparent processing of real music.

## Storage and verification

All six slots reserve eight seconds of stereo history plus their reverb network storage during construction. Compared with two-second history, the history increase alone is approximately 13.8 MB across six slots at 48 kHz. Reverb additionally owns its separately allocated fixed delay-line storage. Reset invalidates history and resets fixed-size state rather than clearing every history sample. Current memory, allocator and timing acceptance must use the exact source and workload; older allocation statements about the earlier DLC are not proof for this revised network.

The source definitions are `Sources/CTDJTransport/TDJEffects.h`, `TDJReverb.h` and `TDJDlcEffects.h`; the UI and persistence mode are in `Sources/TDJInterface/EffectsView.swift` and `PerformancePreparation.swift`.

Earlier focused functional and Mac stress results remain under Validation. The signed27 physical baseline predates the newest shared changes. Two retained post-integration unpaced Mac stress runs each exceeded a 2.667 ms deadline twice, with maxima of 3.968 ms and 3.230 ms. They contained no invalid samples or rejected commands, but they are not passing timing results and do not measure A10X performance. See [overall status](Status.md).

Exact impulse/spectral responses, XY laws, granular timbre, unlock/default behaviour, controller routing and current target-device performance remain open. Original reference provenance remains in the research dossier; implementation choices above are source observations.

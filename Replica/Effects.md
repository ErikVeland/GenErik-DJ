# Effect implementation and remaining fidelity

Documentation reviewed against this branch on 2 November 2026. See [current readiness](Status.md) for source and verification scope and [the A10X reverb design](Reverb.md) for its implementation and qualification limits.

The shared catalog exposes eleven effect IDs, three slots per deck and one selected-slot XY pad. These are independent implementations. Named effect coverage does not establish NI sound or original parameter curves.

| ID | Effect | Current implementation |
| --- | --- | --- |
| 0 | Delay | Feedback delay with per-slot SYNC/FREE timing and crossfaded delay-tap changes |
| 1 | Reverb | Eight-line stereo feedback-delay network with retuned diffusion, shaped bass/treble decay and bounded matrix movement |
| 2 | Flanger | Modulated short delay |
| 3 | Gater | Beat-dependent amplitude gating |
| 4 | Beatmasher 2 | Beat-related capture and buffer slicing |
| 5 | Digital LoFi | Quantization and sample-and-hold rate reduction |
| 6 | High-pass | Ramped state-variable high-pass filter |
| 7 | Low-pass | Ramped state-variable low-pass filter |
| 8 | Iceverb | The same fixed-cost network with longer decay, different input/tone treatment and greater matrix movement |
| 9 | Transpose Stretch | Four overlapping Hann-weighted live read heads over an 80 ms grain window |
| 10 | Reverse Grain | One-beat capture with four overlapping reverse-grain windows |

Y controls slot wet/dry mix. The selected slot retains contact ownership until release or cancellation; slot selection changes during a hold are deferred. Locks retain released effects. Persistence stores effect parameters, lock state and delay timing mode; legacy data without a delay mode defaults to SYNC.

## Timing and sound policies

Delay SYNC uses master-tempo divisions of one-quarter, one-half, one, two and four beats. FREE maps X from 25 to 2,000 ms. The internal beat calculation clamps the tempo to at least 30 BPM. These are explicit development mappings.

Reverb X selects a nominal midband decay target from 0.35 to 8.4 seconds. Iceverb X selects 1.5 to 18 seconds. Their network has eight prime-length tank lines, four input all-pass diffusers per channel, predelay, early reflections and input high-pass/low-pass filtering. Cascaded feedback shelves shorten bass and treble decay relative to the midband target. Two slowly moving feedback pairs reduce stationary coloration without interpolated delay reads. Actual measured band decay differs from the nominal target; see the impulse diagnostics in the reverb validation report.

Reverb and Iceverb add their return to the unchanged dry signal. Releasing an unlocked pad or disabling a slot fades its input over 5 ms and lets the existing tail continue. The return has a finite deadline captured at release, followed by a 20 ms fade; changing X cannot extend that deadline. Setting Y to zero fades the released return away over 5 ms. Re-enabling picks up the current return. Changing effect type invalidates the old history and bridges the output over 5 ms using only the last sample, without running a second engine. Locks and effect IDs retain their existing behaviour.

Coefficient ramps and history invalidation keep these transitions bounded. There is no load-triggered quality reduction or device-dependent algorithm switch in this candidate. Neither algorithm is claimed to reproduce NI or Valhalla.

Transpose has an 80 ms window and four read heads. Its cached ratio spans -60 to +12 semitones, with centre neutral. Reverse Grain captures up to one beat within the available eight-second history, then advances its captured traversal at half speed while its grain reads run backwards. Re-enabling starts a fresh capture. Neutral pitch and synthetic tone checks do not establish transparent processing of real music.

## Storage and verification

All six slots reserve eight seconds of stereo history plus their reverb network storage during construction. Compared with two-second history, the history increase alone is approximately 13.8 MB across six slots at 48 kHz. Reverb additionally owns its separately allocated fixed delay-line storage. Reset invalidates history and resets fixed-size state rather than clearing every history sample. Current memory, allocator and timing acceptance must use the exact source and workload; older allocation statements about the earlier DLC are not proof for this revised network.

The source definitions are `Sources/CTDJTransport/TDJEffects.h`, `TDJReverb.h` and `TDJDlcEffects.h`; the UI and persistence mode are in `Sources/TDJInterface/EffectsView.swift` and `PerformancePreparation.swift`.

Earlier focused functional and Mac stress results remain under Validation. The signed27 physical baseline predates the newest shared changes. Two retained post-integration unpaced Mac stress runs each exceeded a 2.667 ms deadline twice, with maxima of 3.968 ms and 3.230 ms. They contained no invalid samples or rejected commands, but they are not passing timing results and do not measure A10X performance. See [overall status](Status.md).

The new portable reverb harness retains source hashes, operation counts, release regressions, sanitizer results, paired host timing, impulse/band-decay diagnostics and synthetic audition files. It does not qualify the complete app or A10X output. Exact reference responses, preferred wet balance, granular timbre, controller routing and current target-device performance remain open. Original reference provenance remains in the research dossier; implementation choices above are source observations.

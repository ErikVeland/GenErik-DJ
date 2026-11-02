# Transport transition continuity

Documentation reviewed against the shared implementation on 30 October 2026. [Current readiness and verification](Status.md) is the implementation status record. Dated measurements below apply only to their recorded source and workload.

The renderer corrects discontinuities introduced by ordinary transport changes. This is an audio-quality implementation rule. The original app’s correction window has not been measured.

Each deck keeps its last dry stereo output and a small transition state outside its source state. A transition blends that output into incoming samples with a convex cubic curve. It reaches the incoming signal exactly at the final correction sample. Repeated commands restart from the actual last output. No outgoing source is read, and no extra buffer, allocation, file operation or wait occurs in this correction.

The default window is 2 ms at the output rate. Source position, clock, scheduled command frame and `last_start_frame` are unchanged. A start from silence can therefore have a zero first output sample while its source coordinate advances at the scheduled frame. Pause and EOF retain a dry tail for at most 2 ms. Effects continue processing that tail and their existing history.

Ordinary jumps, saved-loop changes and Flux returns request correction only after source validation succeeds. Accepted cue recall, seek and immediate loop/jump changes also request it while paused. This covers a pause/source-change/restart batch that contains no rendered paused sample, and cue recall immediately after EOF. Failed or cold commands remain inert. Identical loop configurations preserve Keylock state. New bounds still reset it because lookahead may cross the new boundary.

Native loop seam correction is capped at a quarter of the loop’s output duration. Windows shorter than two samples are omitted to preserve granular loops. Spectral Keylock overlap already joins its loops and does not receive a second seam correction. Held slice and scratch/reverse contacts retain their immediate attacks and rate changes. Continuous playback has no transition curve, so authentic musical transients pass unchanged.

## Keylock priming

The previous `outputSeek` initialization used synthetic reversed pre-roll. Controlled steady tones exposed gain spikes after a reset: up to 1.9535 from a 0.7 input at 1 kHz and 2x tempo, versus approximately 0.706 during uninterrupted playback.

Priming now seeks through actual source history, then discards exactly `outputLatency` output frames. The cursor still ends at `position + inputLatency + speed * outputLatency`, subject to the existing fractional sample accumulator. The source request planner already covers the history and forward bounds. This adds cached history reads during priming without adding file operations or extending required coverage. Native-speed bypass remains unchanged. No new allocation occurs during priming.

## Ended cues and performance-rate resumption

Cue recall from an ended deck normalizes the proposed state to paused before using the shared start function. Both saved loops and point cues restart their continuing timeline at the recalled cue. This prevents a later Flux release from returning to the old EOF. Existing reference-deck queue rules remain unchanged. Validation failure preserves the ended state, clock and other deck. The producer must prepare the new cue’s linear Flux continuation as well as its loop.

Raw performance rates do not consume the Keylock spectral cursor. Crossing into or out of `performance_rate == 1` invalidates that cursor after successful source validation. Resumption therefore primes from the current source position. A return to active spectral processing uses the existing bounded transition, while raw scratch/rate attack remains immediate. Latched updates to a pending touch do not change the current audible pipeline. Source position, clock and contact region stay unchanged.

A two-region source exposed the old failure: after raw travel beyond the 440 Hz region into the 880 Hz region, returning to normal still emitted 440 Hz from a stale cursor. The four direct/compound forward/reverse cases now emit the correct region. Two file-backed cases travel beyond one million source frames before returning, then remain sample-exact against the memory reference with no stale-window read.

## Verification and limits

The dated frozen implementation and executable evidence are in `Validation/TransportDiscontinuities-2026-10-28-05/manifest.json`. The preceding rate/EOF and FFT baseline remains in `...-04`. The generic-FFT correction and priming baseline is preserved in `...-03`. Earlier raw captures remain in `...-01`; the transition-only experiment remains in `...-02`.

- Eight transition captures have zero adjacent boundary step after correction. The largest ordinary-transition adjacent delta is 0.01534, versus 1.12246 before correction. The smooth source’s ordinary adjacent delta is approximately 0.01255.
- Twenty Keylock tone/reset cases peak at approximately 0.698–0.712 after the priming fix. Nine impulse tests preserve onset within one output sample.
- New native checks pass at 44.1, 48 and 96 kHz. They verify exact continuous/transient output, bounded repeated transitions, pause/EOF completion, unchanged scratch attack and granular loops, loop period, no queued pre-start audio, exact scheduled coordinates, unchanged other-deck samples, monitor equality, recording equality and preserved delay tails.
- Existing streaming checks pass without relaxing their exact file-versus-memory or failed-command comparisons. They include high-rate/Flux coverage and concurrent worker publication.
- Both native suites pass normally, with AddressSanitizer/UndefinedBehaviorSanitizer, and with ThreadSanitizer.
- The final local allocation probe reports zero C++ allocations and zero deadline overruns during 3,000 render calls. The 30 musical-second unpaced C control stress accepts 24,752 commands with no rejected commands, invalid samples, clock errors or deadline overruns. That recorded run’s maximum callback time is 2.609 ms against a 2.667 ms period. The separate 3,000-call allocation probe peaks at 0.697 ms. These are local unpaced probes rather than physical target-device headroom measurements.

These are controlled native checks on the Mac. App-level integration, paced runtime and physical target-device acceptance are separate requirements. This evidence does not establish the original app’s exact sound or gesture timing.

Host callback bounds and future Flux trajectories now have explicit capacity validation. Flux continuation reserves its native-rate Keylock history and lookahead. Unsupported future working sets return terminal `TDJ_SOURCE_CAPACITY` before changing current playback. The fixed pool is unchanged. See `PCMStreamingDesign.md` for the configuration contract and coverage limits.

The frame-bound and future-capacity extension is frozen in archive `...-05`. Both native suites pass all three build variants, with matching source hashes after execution. The deterministic trajectory sweep checks 1,800 profiles: 1,695 accepted and 105 rejected. All 195,557 future minimum-read sets for accepted profiles fit the 240 published blocks. The allocation probe reports zero C++ allocations and no deadline overruns, with a 0.598 ms maximum against a 2.667 ms period. The new 30 musical-second unpaced control stress accepts 24,752 commands with no rejection, invalid sample, clock error or deadline overrun. Its maximum is 1.354 ms. These remain local native measurements.

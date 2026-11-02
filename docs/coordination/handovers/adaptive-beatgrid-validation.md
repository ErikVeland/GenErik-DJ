# Adaptive beatgrids — implementation and qualification

The implementation is in the shared checkout on `feature/adaptive-beatgrids`. Release qualification remains open. This task did not operate the iPad. Listening acceptance remains open.

Editor source identity: `ebdc47aa823a27e8b4f0969a39f4db672394e276933f7db1b3064129df58c130`. `manifest.json` records the exact input hashes, reports and remaining gates. The editor archive and the earlier timed-audio archive retain separate identities. Later shared changes are listed in the manifest.

## Implemented

- Bounded immutable maps, interpolation, inverse lookup, end extrapolation and fixed-grid fallback.
- Legacy decoding and omission of unused adaptive fields. The retained SixAA snapshot re-encodes byte for byte.
- Background candidate extraction with robust local timing. Analysis does not activate a map.
- Immutable native publication, generation checks, deck isolation and all-segment keylock validation.
- One timing contract for Sync, queued starts, loops, slices, Flux, effects, beat jumps and waveform marks.
- Existing-editor map selection, local correction, undo and persistent locking. Downbeat and tempo edits retain adaptive sections.
- Acceptance commits after native acknowledgement. Rejected commands cannot replace saved preparation.

Reconciliation preserved newer library preparation pins, scratch controls, deck layout and layered waveform rendering. Analysis candidates remain separate from accepted preparation.

## Verification

Timed audio source identity: `7760998ab02c97d9623b2008d78c02566a5b1359e7a6003776183730cccb9c4d`. Editor verification uses the separate identity above.

The editor follow-up passed all 627 tests in serial Release execution. Its generic iPad SDK build also passed.

The follow-up verifies explicit acceptance of newer candidates, Undo through lock/unlock, and preservation of a later key correction. Each missing behavior was reproduced before its fix. The earlier 626-test run retained one gesture assertion. That assertion did not recur in the later suite, and its failed output remains preserved. The legacy snapshot comparison passes byte for byte.

Adaptive publication and concurrent snapshots pass address/undefined and thread sanitizers. The streaming sanitizer harness also passes with its required recording unit linked. The native transition harness retains its earlier cue-recall assertion failure. Generic iPad SDK compilation of TDJInterface passes. This task did not query hardware.

| Frozen audio workload | Result | Maximum callback | Maximum exact completion | Captured = AIFF frames |
| --- | --- | ---: | ---: | ---: |
| fixed60 | Pass | 4.700 ms | 4.773 ms | 2,949,632 |
| fixed300 | Pass | 2.514 ms | 15.674 ms | 14,593,536 |
| adaptive60 | Pass | 4.547 ms | 1.886 ms | 2,959,872 |
| adaptive300 | Pass | 3.963 ms | 11.696 ms | 14,434,304 |

Runtime passes require unchanged compiled inputs, no route interruption, no callback failures, no invalid output, no recording drops and no control completion misses. Existing limits remain 10.667 ms per 512-frame callback at 48 kHz and 20 ms for exact control completion.

Fixed workloads are unchanged. Adaptive workloads explicitly accept two different maps before playback and retain their map configuration. Hardware output is silenced. Captured audio and generated inputs remain at the absolute paths in the manifest. These measurements do not establish listening quality or target-device performance.

Earlier isolated-source results remain in `earlier-candidate.md` and `earlier-manifest.json`. They are separate evidence and do not qualify later source. The intermediate 0.3.0 runs remain under integrated-before-boundary-runtime. The 0.3.1 estimator uses a wider endpoint window after a delayed-final-beat regression. Its cache identity changes accordingly. The first combined attempt also retained a failure in the legacy byte comparison. Omitting unused default fields fixed that failure without changing the golden fixture.

## Remaining gate

Task 6 remains incomplete. Earlier gesture and native transition failures remain retained evidence. The latest shared native harness was edited separately and is outside this qualification. The timed harness does not cover the full Flux, slicing and import combination. Native Flux and paired-map queued starts have separate offline checks. Musical listening comparisons, physical A10X timing and touch, user acceptance and gig-duration headroom remain open.

The user owns the iPad. Device testing requires a new agreed window. An engine stop, route change, missing source proof or measured fault fails or invalidates a run. No Mac pass transfers to another source or device.

## Decisions and limits

- Preserve current working files in isolated source copies, then reconcile against the newer shared checkout. Cost: initial results apply only to their retained source.
- Limit maps to 256 anchors and 20–400 BPM segments. Cost: extreme or oversized maps fall back to fixed preparation.
- Require a paused/ready deck without an active loop, contact or queued jump before activation. Cost: the performer must finish those actions first.
- Keep Automatic acceptance explicit for this milestone. Cost: the first map is accepted in the existing editor.
- Keep baseline failures and physical acceptance open. Cost: the feature remains unqualified.
- Route the newer beat-jump, loop-step and waveform-mark consumers through the same contract. Cost: their adaptive behavior needs the same physical acceptance.

Deferred minor: drift and ramp synthetic cases share one trajectory, and syncopation coverage remains limited. A separate delayed-beat fixture now verifies that one late transient cannot bend the tempo map.

The source archives, scoped integration patch, binary hash and complete logs make the result reviewable. The timed runs use the 0.3.1 analyser and the frozen audio snapshot. The editor follow-up changes paused preparation actions and preserves a separate source identity. This task did not push, deploy or merge to main. Later shared audio-route, scratch and UI changes remain outside these measurements. The report does not qualify the current moving working tree.

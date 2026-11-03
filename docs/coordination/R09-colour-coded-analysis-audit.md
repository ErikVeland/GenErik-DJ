# R09: Colour-coded analysis audit

Reviewed 2 November 2026 against source `e5b3ee654dcaeba229170535900026e4df514aee`.

**Result: partial. All requested features are not implemented.** This is a source audit, not a new device test.

## Coverage

| Requested behaviour | Source finding | Remaining work |
| --- | --- | --- |
| Frequency-coloured waveform | `BandWaveform.swift` separates low, mid and high bands. `ReplicaView.swift` draws the bands. | Erik's iPad readability and playback acceptance. |
| Musical section colours | `TrackArrangement.swift` defines role colours and behaviour fallbacks. `ArrangementViews.swift` draws labels and colours. | Automatic musical labels remain absent. |
| Overview and detailed annotations | `ReplicaView.swift` connects `ArrangementWaveformOverlay` to both views. The overlay does not intercept touches. | Physical gesture and layout acceptance. |
| Automatic section boundaries | `TrackArrangement.prepare` compares neighbouring energy windows. It creates neutral `SECTION` labels. | Musical boundary evaluation on real tracks. Energy changes do not establish song structure. |
| Automatic verse, chorus, vocal, build and drop recognition | No classifier is connected to preparation. Automatic sections retain unknown roles and sustaining behaviour. | Implement and evaluate recognition with confidence and uncertain results. |
| Automatic mixing suitability and suggested regions | The model and editor support mix-in, mix-out and regions. Automatic preparation does not create them. | Generate and evaluate suggestions with reasons and confidence. |
| Landmarks and hot-cue promotion | The editor supports manual landmarks, accept/dismiss actions and exact-frame promotion to a free hot-cue slot. | Richer automatic landmarks and real-track acceptance. |
| Event and ending countdowns | `TrackArrangement.status` supports fixed/adaptive timing, seconds fallback, loop/slip handling and reverse indication. | Combined iPad playback acceptance. |
| Musical and rhythmic endings | Automatic preparation estimates the last audible waveform bin. Manual ending landmarks can override it. Automatic rhythmic ending remains nil. | Distinguish the rhythmic ending, musical ending and effect tail reliably. |
| Preparation persistence | `ArrangementModel.swift` loads and writes a separate cache. `retainCorrections` preserves manual corrections. | Device persistence acceptance. |
| Performance and accessibility | Preparation runs in a utility task. Views include reduced-motion handling and audible-deck pulse control. | A10X measurements, dark-room readability and accessibility checks. |

## Evidence limits

The existing `TrackArrangementTests`, `ArrangementTimingTests` and `ArrangementIntegrationTests` cover colours, timing, corrections and persistence. They were inspected, not rerun for this documentation change. The silence test explicitly checks that automatic preparation does not invent verse, chorus or vocal labels.

The retained waveform handover also records these implementation gaps. Its screenshot uses manually assigned sections on a synthetic fixture. That image does not demonstrate automatic recognition.

No application source changed during this audit. No new build or device installation was required. R09 remains partial. Finish each missing analysis capability as a focused iPad iteration, then obtain Erik's acceptance on real music.


## 3 November follow-up candidate

The new local structure pass adds spectral and pitch-class repetition, bass-attack changes and Apple's trained vocal classifier. It produces automatic section names and colours, vocal and arrangement landmarks, mix regions and estimated rhythmic endings. Verse and chorus roles remain inferred estimates, marked with `?`. The new code is not a trained song-form model.

The earlier table describes the 2 November source only. Current evidence and limits are in `../testing/checks/R09/2026-11-03-musical-structure/`. Real-library accuracy, physical display and uninterrupted playback still require Erik's acceptance. No new gig-readiness claim is made.

# R09, R29 and R30: Duo build 70

Source `4dfc867f889bf33a5cda2fdeeb2bc2ee57c6ccdc`. Signed build 70 installed and launched on GenErik Duo on 3 November 2026. Erik acceptance is pending.

The candidate adds local musical section suggestions, the existing role colours, vocal and arrangement landmarks, mix regions and estimated rhythmic endings. Old arrangement caches upgrade on load. Section starts fill free hot-cue slots with their names and colours. Existing cues and deliberate deletions remain protected. The eight-slot limit still applies.

Loading either deck now runs full musical analysis when preparation was deferred, BPM is absent or invalid, or the effective key is absent. The previous deferred-only check explains how an earlier completed analysis with no BPM could skip a retry. 3Cag still needs Erik's device test. Analysis reports unresolved values and preserves manual preparation.

The candidate retains build 66 continuous resizing. Decks start with 72% of the available height. The main waveform receives space after a compact header, overview and one status row. The calculated waveform height is 117.84 points at 619 available points. FX, EQ, Loop and Play stay in a vertical rail. Cue and headphone buttons are optional. Cued tracks show a headphone icon on their artwork, including controller-driven cue changes.

Ten focused production checks passed. These include actual generated PCM through Apple Sound Analysis, cancellation, repeated vocal passages, instrumental changes, mix regions, ending tails, silence, manual corrections, missing-value policy and cue allocation. The old structure dispatch produced 16 failed assertions. The new policy and allocator tests first failed because their APIs were absent.

The focused package-test attempt was blocked before execution by an existing macOS-only compile error. Standalone checks avoid the app UI. Build 68 exposed an imported library lookup compile error, which was corrected before build 70. All failed and superseded evidence remains available. No simulator or broad regression sweep ran.

Verse and chorus are inferred estimates, marked with `?`. The vocal detector is trained, but no trained song-form model is included. Endings and mixing suitability need real-music review. Fixture checks and signing do not establish audio continuity, A10X cost, recognition accuracy across Erik's library or gig readiness.

See `result.json` for the exact source and deployment identities. Device actions stopped after launch.

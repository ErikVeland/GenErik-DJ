# GenErik Audio Check

An authorised device session can launch one supported preset through `--audio-check=PRESET`. Ordinary launches keep the manual controls. Repeated or unsupported preset arguments do not start audio. Backgrounding cancels a running check, and every run keeps a unique result folder.

| Preset | Duration | Source fixture | Interface |
| --- | --- | --- | --- |
| loop60 | 60 seconds | 48 kHz, detected grid | Diagnostic controls |
| loop300 | 300 seconds | 48 kHz, detected grid | Diagnostic controls |
| sequential300 | 300 seconds | 48 kHz, sequential reading | Diagnostic controls |
| ui60 | 60 seconds | 48 kHz, detected grid | Static shared interface |
| ui-loop300-panels | 300 seconds | 48 kHz, detected grid | Moving panels |
| ui-sequential300-panels | 300 seconds | 48 kHz, sequential reading | Moving panels |
| loop60-near2x | 60 seconds | 48 kHz, manual 60 BPM | Diagnostic controls |
| loop300-near2x | 300 seconds | 48 kHz, manual 60 BPM | Diagnostic controls |
| ui-loop300-panels-near2x | 300 seconds | 48 kHz, manual 60 BPM | Moving panels |
| loop60-near2x-44100 | 60 seconds | 44.1 kHz, manual 60 BPM | Diagnostic controls |
| loop300-near2x-44100 | 300 seconds | 44.1 kHz, manual 60 BPM | Diagnostic controls |
| ui-loop300-panels-near2x-44100 | 300 seconds | 44.1 kHz, manual 60 BPM | Moving panels |

This is a separate iPad diagnostic app. It uses the shared `TDJRuntimeChecks` library and the production audio callback and recorder. It does not change the DJ app or its data.

The app has a distinct bundle ID, `org.generikdj.replica.audiocheck`, and its own Documents container. Each run uses a new `Documents/GenErikDJ-AudioChecks/run-<timestamp>-<UUID>` folder. Existing runs are never overwritten. No Music library or microphone permission is requested.

## Checks

- **60-second loop check:** synthetic looping audio, performance controls, recording, background analysis and search over 115,219 synthetic catalog entries.
- **5-minute continuous check:** the same production paths with continued source reading beyond the fixed PCM pool.
- **60-second live interface check:** the same loop workload displays the actual ReplicaView with FX on A and the mixer/filter on B. Controls remain read-only during this automatic check. A diagnostic Cancel control stays available. Bounded display-callback and observed snapshot-update data are saved separately. These do not establish every presented waveform frame or manual touch fidelity.
- **Cancel:** requests cancellation. Both start controls remain disabled until the shared runner finishes cleanup. Leaving the foreground also cancels the check.
- **Share results:** opens the system share sheet with the result JSON and recorded AIFF after completion. A thrown error or cancellation shares `failure.json` when available. Incomplete runs are never shown as passed.

Preparation and result saving take additional time. Long runs can retain substantial data. Share reports before removing run folders through Files. The app does not automatically delete evidence. The screen stays awake during a run and its prior idle-timer setting is restored when cleanup finishes.

Hardware audio output is silent. The saved recording contains the synthetic signal for numerical checks. This app does not establish listening quality, DJ gesture behavior, full interface frame pacing or fidelity to Traktor DJ. A simulator run cannot establish physical iPad performance. A successful build is not a completed device check.

## Build only

Run these build-only scripts from the Replica directory:

```sh
bash Scripts/build-ipad-validation-app.sh
bash Scripts/build-ipad-validation-device-app.sh
```

Both scripts compile Release builds with signing disabled and generic destinations. They use separate derived-data folders. They do not enumerate, boot, connect to, install on or run on any device. Signing, installation and physical acceptance are separate work and are not performed by these scripts. The separately authorised GenErik session is recorded under `Validation/GenErikAudioCheck-2026-10-29-01`. Original Traktor app/data operations remain outside that authorisation.


## Source identity

The generic build scripts hash `Package.swift`, package sources, diagnostic-app sources/project/docs, third-party notices and the diagnostic build helpers. Relative paths are sorted and their file hashes form one SHA256 fingerprint. Generated build/workspace/user files and `.DS_Store` are excluded. The fingerprint is embedded as `TDJValidationSourceSHA256`. `TDJValidationBuildConfiguration` records Release. The shared runtime report reads these values. Manual builds without a recorded fingerprint remain unrecorded.

Each build retains input manifests before and after compilation and rejects source mutation. The derived-data folder contains `audio-check-build-proof.json` and a separate attempt folder under `AudioCheckBuildProofs`. The proof includes the app executable hash, bundle identity and embedded source fingerprint. Earlier attempts are retained. This is build provenance, not device runtime acceptance. Run `python3 Scripts/validation_app_provenance.py self-test` for the input-guard checks.

`Preview/RenderPreview.swift` is the entry point for the primary package's `tdj-audio-check-preview` executable target. It renders the common model and SwiftUI screen offscreen on Mac without calling the timed runner or opening a window. UIKit sharing and idle-timer behaviour are excluded. Its images check geometry; native navigation, scrolling and sharing require iPad UI checks. They are not physical interaction or audio results.

The five-minute `loop300` preset repeats the existing loop and paired cue-recall workload. `sequential300` measures continuous read-ahead without cue recalls. Neither changes the audio/control pass limits.

The `ui-loop300-panels` and `ui-sequential300-panels` presets add five-minute live-interface workloads with a fixed sequence of FX, EQ and filter drawer slides. They retain the existing audio/control cadence and budgets. Inputs and Music/import actions stay disabled. Display reports retain full-lifecycle aggregates and add bounded timestamped gap events and requested panel transitions; they do not establish presented frames or touch fidelity.


## Explicit near-2× Keylock stress

`loop300-near2x` and `ui-loop300-panels-near2x` retain the existing five-minute workload and deadlines. `loop60-near2x` runs the same audio workload for one minute for shorter diagnostic checks. They apply a manual 60 BPM grid through the production model after both synthetic tracks load. The normal 120 ±8 BPM control sweep therefore exercises approximately 1.867–2.133 playback speed on both keylocked decks. Detected analysis remains recorded separately. The final report requires the actual native grids, sync, Keylock and observed speed sweep to match; the setup proof is saved before timing. These presets measure an explicit heavy workload, not detector accuracy or original-app fidelity. Existing presets retain their detected-grid behavior.

Explicit CPU tracing also records the first callback's wall time, thread identity and ARM floating-point control register. Keylock prime events retain the same thread context. The register is read without modification. These fields help investigate startup costs; traced runs remain ineligible for timing acceptance.

## Current implementation scope — 30 October 2026

[Status.md](../Status.md) records the last retained physical build and the current shared-source gap. The diagnostic app uses automated controls and silenced hardware output; its passing runs do not certify real-library use, manual touch, listening quality or a newer source. Editing this README changes the full diagnostic build-input fingerprint because that manifest includes diagnostic documentation. It does not change executable behaviour.

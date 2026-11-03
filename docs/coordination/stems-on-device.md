# On-device stem separation

Updated 4 November 2026.

Erik chose on-device separation of local tracks. Streaming remains deferred. The library must continue to show only audio files available on this device.

## Working design

- Separate each local track into vocals, drums, bass and other.
- Prepare stems in the background before performance. Do not run separation in the audio render callback.
- Cache outputs by source content hash, model identity and separation settings.
- Keep source audio and preparation unchanged. Do not rewrite the source file.
- Preserve one deck clock, beat grid, cue positions, loops and transport for all stems.
- Allow the performer to control each cached stem through the existing deck mixer path.
- Stop or defer separation when playback needs the available CPU/GPU budget.

The four outputs and background workflow are working assumptions. The app has no stem inference or playback route yet.

## Model candidate

HTDemucs separates vocals, drums, bass and other. The Meta repository reports the model family and its MIT license. A third-party Core ML conversion provides a 44.1 kHz stereo model with ten-second input chunks. Its README lists about 200 MB for FP16, while the model repository lists the package at 233 MB. The conversion recommends CPU/GPU units and warns against Neural Engine execution for its current model shapes. It supports iOS 17. See the [conversion README](https://huggingface.co/dexxdean/htdemucs-coreml/blob/main/README.md), [model package listing](https://huggingface.co/dexxdean/htdemucs-coreml/tree/main/HTDemucs_CoreML_FP16.mlpackage) and [Meta Demucs repository](https://github.com/facebookresearch/demucs).

This conversion is a candidate, not an A10X-validated dependency. The working delivery choice is a one-time model download to app support. This keeps the app build smaller. The download must use revision `8b4d481` and verify the model SHA-256 `307ddf24af60111ba821d4ad6bf2d1d987d6531ca2f487b6a95ec16a16a9c644` and weights SHA-256 `efab790ad07d93faeb5a19b6e1eedad8c37ad351563a891a153fce307811c099`. The model download does not download or change music tracks. Internet access is needed only to install the model for first use. After installation, separation runs on the device.

The repository does not bundle the model package and has no inference pipeline or stem playback route. This project has not checked the conversion or A10X performance. Build 81 does not include stem processing.

The first local installer is in `Replica/Sources/TDJInterface/StemModelRepository.swift`. It pins the model revision, verifies model and weight hashes, and compiles the package into a caller-provided local directory. Its single-file source check is in `../testing/checks/R17/2026-11-04-stem-model-installer/README.md`. The app does not call the installer yet.

## Implementation gates

1. Verify the model artefact, licence notices, checksum and delivery size.
2. Add cancellable background preparation for local source files and versioned stem caches.
3. Keep playback on the original single-source path until every stem file is complete and verified.
4. Add stem gain controls to the existing deck action and render path. Do not add model inference to playback callbacks.
5. Measure processing time, peak memory, cache storage, thermal effects and clean audio on the target iPad.
6. Retain the original track as the fallback when separation fails or the cache does not match.

The project cannot close the model or performance gates without the model artefact and target-device evidence. No stem-separation claim is made until those checks pass.

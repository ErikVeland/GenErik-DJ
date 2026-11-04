# R17 bundled stem-model source check

Date: 4 November 2026.

`StemModelRepository.swift` reconstructs the pinned Core ML model from bundled resources, checks its size and SHA-256 hashes, and compiles it into the caller's local storage directory.

## Source identity

- Source: `Replica/Sources/TDJInterface/StemModelRepository.swift`
- SHA-256: `c9b0d1ac3c3994687b225a765d3ce2fb633a81d1615cb43dcc3836f3a489cf0f`
- Bundled resource: `Replica/Sources/TDJInterface/StemModelAssets/HTDemucs_CoreML_FP16.mlpackage/`
- Model revision: `8b4d481`
- Model file SHA-256: `307ddf24af60111ba821d4ad6bf2d1d987d6531ca2f487b6a95ec16a16a9c644`
- Weights file SHA-256: `efab790ad07d93faeb5a19b6e1eedad8c37ad351563a891a153fce307811c099`
- Manifest SHA-256: `14606502456a841e914dd1231cefd357eaf4cf3e2e7323c939543ab49f661b4c`
- Total model package size: 232,987,792 bytes
- The 190,099,328-byte weights file is stored as three source resources because GitHub rejects files larger than 100 MB.

## Checks

- Model and weight byte counts and SHA-256 hashes match the pinned revision.
- The concatenated weight resources match the original weight SHA-256.
- `swiftc -frontend -parse Replica/Sources/TDJInterface/StemModelRepository.swift`: passed.
- Xcode 27.2 Swift 6.4.2 type-check against `MacOSX27.2.sdk`, using a temporary `Bundle.module` shim: passed.
- `git diff --check`: passed.
- STE linter: passed for the project-control notes and third-party notice.
- `swift package dump-package`: blocked because Xcode licence agreements are not accepted. The first attempt also used the Command Line Tools SDK, which does not match the Xcode Swift toolchain.

No app build, model compilation, separation run, test suite or device action was performed. The iOS target compile, final app bundle contents and model behaviour on A10X remain unverified.

## Earlier installer source check

Commit `541b099` had source SHA-256 `949f5a35e03710c2b4494a6f2ea650a1147c7c5c380013c86be9c5eac0832ed2`. Its first type-check attempt failed because the default module cache was not writable. A retry with a task-local module cache passed. This earlier installer was replaced after Erik chose to bundle the model.

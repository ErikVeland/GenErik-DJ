# R17 pinned stem-model installer source check

Date: 4 November 2026.

`StemModelRepository.swift` downloads the pinned Core ML model files, checks their sizes and SHA-256 hashes, writes the package manifest, and compiles the model into the caller's local storage directory.

## Source identity

- Source: `Replica/Sources/TDJInterface/StemModelRepository.swift`
- SHA-256: `949f5a35e03710c2b4494a6f2ea650a1147c7c5c380013c86be9c5eac0832ed2`
- Model revision: `8b4d481`
- Model file SHA-256: `307ddf24af60111ba821d4ad6bf2d1d987d6531ca2f487b6a95ec16a16a9c644`
- Weights file SHA-256: `efab790ad07d93faeb5a19b6e1eedad8c37ad351563a891a153fce307811c099`

## Checks

- `swiftc -frontend -parse Replica/Sources/TDJInterface/StemModelRepository.swift`: passed.
- Xcode 27.2 Swift 6.4.2 type-check of the single file against `MacOSX27.2.sdk`: passed with a writable module cache under `/private/tmp`.
- The first type-check attempt used the default module cache and failed because the environment denied access to `/Users/erikveland/.cache/clang/ModuleCache`. The retry used a task-local cache and passed.
- `git diff --check`: passed.

No app build, model download, separation run, test suite or device action was performed. The iOS target compile and the model's A10X behaviour remain unverified.

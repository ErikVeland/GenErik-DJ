# Application architecture

The app uses Swift 6, SwiftUI, AVFoundation and a native C/C++ audio engine. The active target is the A10X iPad on iPadOS 17. Shared Mac preview and diagnostic targets remain development tools.

| Target | Responsibility |
| --- | --- |
| `TDJCore` | Analysis, library storage, musical timing, preparation and transport control |
| `CTDJTransport` | Sample clock, command rings, streaming, mixing, FX and recording capture |
| `CTDJAudioSource` | Objective-C++ bridge from AVAudioSourceNode to the native renderer |
| `TDJInterface` | SwiftUI, touch ownership, deck loading and background work |
| `TDJTool` | Command-line analysis and preparation tools |
| `TDJRuntimeChecks` | Explicit runtime diagnostics, outside the normal app target |

[Build and install](../README.md#develop-and-test) from `main` through `tools/ipad_test.py`. It preserves numbered apps, logs and feedback. The app updates in place as `org.generikdj.replica.audiocheck`.

Use focused tests for each change:

```sh
swift test --package-path Replica -c release --no-parallel --filter '<test name>'
```

Native checks live in `Scripts/`. Full release qualification is separate from routine device iterations. Do not package the Mac app or build simulators during the iPad loop.

See [the documentation index](../DOCUMENTATION.md) for subsystem details. [Current work](../docs/coordination/README.md) controls priorities. [History](../docs/history.md) retains earlier designs, build logs and performance measurements.

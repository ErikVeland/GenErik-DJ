# GenErik DJ

A touch-first DJ app for Erik's 2017 10.5-inch iPad Pro (A10X). The goal is the most intuitive, fluid, multi-touch digital DJ app, with TDJ1 as the reference for feel and reliability. Clean, continuous audio comes first. Immediate, fluid touch control comes second. See the [project north star](docs/product-direction.md) and [performance acceptance](docs/coordination/release-gates.md).

The waveform is a performance map of individual hits, rhythm and groove. Musical readability takes priority over a literal signal trace.

## Develop and test

1. Open `Replica/iPad/GenErikDJ.xcodeproj` in Xcode.
2. Use the `GenErikDJ` scheme with an iPadOS 17 or later device.
3. Make changes on a `feature/` branch, then merge into `main`.
4. Build and install the next numbered test app:

```sh
python3 tools/ipad_test.py run --notes "Describe the change"
```

The helper reuses `.build-ipad/`, archives the signed app and records its source identity. Local signing settings are in `TestBuilds/ipad/config.json`. Use `build` to prepare without installation or `deploy --number N` to install a saved build. Erik tests sound and touch after each handover.

## Repository

| Path | Contents |
| --- | --- |
| `Replica/Sources/` | Swift application code, native audio engine and required resources |
| `Replica/Tests/` | Automated tests and fixtures |
| `Replica/iPad/` | iPad app project and assets |
| `Replica/Scripts/` | Native checks, build tools and explicit release qualification |
| `tools/` | iPad test loop, focused checks and reference tools |
| `Analysis/Traktor-DJ-1x/` | Original-app requirements, reference captures and fixtures |
| `docs/` | Current work, testing instructions and history access |

See [architecture and feature boundaries](ARCHITECTURE.md), [source layout](Replica/README.md), [current work](docs/coordination/README.md), [requests](docs/coordination/requests.md) and [documentation](DOCUMENTATION.md).

Run `python3 tools/check_repo.py` to check script syntax, generated files and documentation links. The source formatting rules are in `.swift-format`, `.clang-format` and `.editorconfig`.

Models and third-party code retain their licences. The stem model stays bundled for future work. [Historical records](docs/history.md) are preserved separately from the active project.

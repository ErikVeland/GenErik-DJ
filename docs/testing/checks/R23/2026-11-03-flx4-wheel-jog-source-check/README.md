# R23 DDJ-FLX4 wheel-side jog source check: 3 November 2026

Base application commit: `bd4d811dbd610a493ea7b263719127afd27d2155`.
Integrated source commit: `2ab4841701e6c0df7587dc9f1b8ec5447af9d02b`.

## Behaviour

The opt-in DDJ-FLX4 profile maps wheel-side CC 33 on both deck channels. It decodes the controller's binary-offset counts into a temporary playback-rate bend. The default bend is two percent per count, capped at plus or minus eight percent. It returns to normal after 150 ms without input. A platter touch takes control while active. Disconnect and profile changes clear the bend.

The mapping follows the official [DDJ-FLX4 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-flx4/ddj-flx4_midi_message_list_e1.pdf), which identifies CC 33 as wheel-side rotation and reports difference counts. Erik must calibrate the rate feel on hardware.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift syntax parse | PASS | Changed core, interface and test files parsed. |
| Standalone rate helper | PASS | The Swift helper compiled with a writable module cache. Assertions covered direction, neutral input, accumulation, bounds and non-finite values. |
| Repository focused test | BLOCKED | `Scripts/check.sh --filter ControllerJogBendTests` stopped before tests. Swift 6.3.3 crashed during interface code generation. The test target also reports that it cannot import `Testing`. Full outputs are in `focused-test.log` and `explicit-setter-test.log`. |
| Whitespace and STE checks | PASS | `git diff --check` and the prose linter passed. |
| iPad and controller check | PENDING | No iPad or controller was accessed. Erik owns hardware calibration and acceptance. |

The first focused build exposed a missing source-map name in `LibraryBrowserProjection`. The lookup now uses the existing source-ID map. The same build exposed an iOS-only navigation modifier in the macOS test target. That modifier now compiles only on iOS. The package attempts ran before the integration merge. They do not verify the merged source tree.

## Source identity

SHA-256 values for changed Swift files:

| File | SHA-256 |
| --- | --- |
| `Replica/Sources/TDJCore/ControllerJogBend.swift` | `42e4ac4e912a02a93e3296e0819c26b082f153c3069df122145e4c2e08ff059e` |
| `Replica/Tests/TDJCoreTests/ControllerJogBendTests.swift` | `cb114f62084dd34c4109cb9ee1843cdb08df809a6ee08ba19e4c74ab5d4c0da4` |
| `Replica/Sources/TDJCore/LibraryBrowserProjection.swift` | `fa63d1c7d3ddd8f948601a27d7fbeedbc85baefa378e164747c32aa0c6518715` |
| `Replica/Sources/TDJInterface/ControllerMIDIConnection.swift` | `3a0f9d1a6c835bd0e3945cba8a5825e2e0a7312fba45268d989334fd3cea7de0` |
| `Replica/Sources/TDJInterface/ControllerSettingsView.swift` | `e582e83b93373537ee535fca5ac235491b41584297db1e1d24eff517aba6818c` |
| `Replica/Sources/TDJInterface/ReplicaModel.swift` | `8f026f76537a45f1c6004e96d0fbffd4e026bde09231cb22ab8ffa89d8aac7b3` |
| `Replica/Sources/TDJInterface/KeyImportReviewView.swift` | `71de7681717123c0e336d2a5483d15ba1f9bc0d0f1b7ac2ca3f9f3f3c986c6e5` |

## Remaining work

Run the focused package tests with a supported Xcode toolchain. On a DDJ-FLX4, verify direction, bend strength, reset timing, touch priority, disconnect behaviour and uninterrupted audio. Controller acceptance remains pending.

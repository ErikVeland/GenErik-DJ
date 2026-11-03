# R23 simultaneous MIDI inputs source check: 3 November 2026

Application base: `42245bf0a9cae626d3a1dadcef064fb4ab247310`.

Changed source SHA-256:

- `Replica/Sources/TDJInterface/ControllerMIDIConnection.swift`: `aee4d4e7edc1d360d33e841fe3064d1761f3b9647b244fde2a0c24e52e5409ab`
- `Replica/Sources/TDJInterface/ControllerSettingsView.swift`: `1f54c4d320de2670f9851f24d549c5fd964228e223491eeef985a4436df6985c`

## Change

Multiple MIDI inputs can stay active at the same time. The user selects one input to configure or learn. Each source keeps separate mappings, decoder state and one momentary Shift layer.

The app stores the active input IDs. Disabling or disconnecting an input releases its held momentary actions and clears its decoder state. A shared momentary action stays active until every input that holds it releases.

## Checks

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The controller connection and settings view parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| Package tests | NOT RUN | No test command was requested. |
| Signed build and hardware check | NOT RUN | This work did not access an iPad or controller. |

## Remaining evidence

Verify two active controllers, source-specific learning and mappings, independent Shift buttons, held-action release after disconnect, bridge mode changes and MIDI 2.0 input on Erik's setup.

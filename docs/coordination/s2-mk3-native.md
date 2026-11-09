# S2 Mk3 native iPad adapter

R108 adds automatic connection to the S2 Mk3. Erik can test only the original Z1 physically. This increment uses documented packet layouts and the saved Traktor DJ 2 configuration.

## Protocol evidence

The preserved TDJ2 2.4.1 package declares `com.native-instruments.protocol.kontrols2mk3`. The accessory vtable at `0x102a7fcf8` points to startup at `0x100a95948`, report dispatch at `0x100a95958` and light output at `0x100a95a94`. See the [reference provenance](z1-native-accessory.md).

| Message | Report ID | Payload bytes | Sequence |
| --- | --- | --- | --- |
| Request buttons and jogs | `01` | 0 | Send when both streams open. |
| Buttons and jogs | `01` | 19 | Set the first button baseline and request `02`. |
| Request knobs and faders | `02` | 0 | Send after the first valid `01`. |
| Knobs and faders | `02` | 38 | Mark the connection ready. |
| Lights | `80` | 61 | Send changed feedback after startup. |

The read frame starts with `33 C3 00`. The write frame starts with `B3 C3 00`. The next two bytes give the little-endian length, including the report ID.

The [Mixxx S2 Mk3 implementation](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-S2-MK3-hid-scripts.js) documents control and LED offsets, 12-bit pots and the pad palette. The native payload lengths, control group offsets and 10-bit jog counter match the reference. The inspected reference file has SHA-256 `40cafdcd40ce8cdf3e9f228c695445b98a2fba9eafe10bf4ac490038c293b48b`. Read-only disassembly and test logs remain under `TestBuilds/r100/s2/`.

## Controls and lights

The app opens the native session on discovery. The wired audio profile selects main 1–2 and headphones 3–4. No MIDI Learn or app routing setting is required.

Play, Cue, Sync, Keylock, headphone cue, Hot Cues, Shift plus Hot Cue delete, loop size and toggle, Move, Flux and Reverse use existing deck actions. Platter touch enables scratch, and rim movement bends tempo. Channel faders, crossfader, trim, EQ, filter amount, tempo and cue blend use pickup. A held startup button does not fire. Disconnect releases scratch, reverse and temporary jog bend.

Pad 8 on each deck displays the blue beat pulse in three palette levels. The amber warning takes priority every four beats from 30 seconds, then every beat from 10 seconds. The timing follows the shared beat grid and remaining playback time. A paused deck restores its cue indication. Loops suppress the warning. Pad input remains available. Play, Sync, Keylock, headphone cue, Flux, Hot Cue presence and level meters have dedicated feedback.

Browser encoders and load buttons, alternate pad modes, hardware FX selection, grid editing and microphone controls remain open. The app applies its existing Cue action when the transport CUE button is pressed.

The stream uses the existing bounded reads and latest-feedback queue. The playback monitor sends light changes at its normal interval. Analog mixer messages reuse the renderer queue without an extra UI refresh for each knob. Actual connection, jog feel, palette brightness, audible cue separation and sustained A10X performance remain unverified on S2 Mk3 hardware.

Thirty-five focused host tests passed across 41 cases on the signed source. [Build 173](../testing/builds/173.json) installed on the A10X iPad, and iPadOS accepted launch.

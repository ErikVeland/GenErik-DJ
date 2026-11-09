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

R108 maps the transport CUE button to the existing Cue action. R110 adds browser controls, pad modes, FX selection, grid editing and microphone input.

The stream uses the existing bounded reads and latest-feedback queue. The playback monitor sends light changes at its normal interval. Analog mixer messages reuse the renderer queue without an extra UI refresh for each knob. Actual connection, jog feel, palette brightness, audible cue separation and sustained A10X performance remain unverified on S2 Mk3 hardware.

Thirty-five focused host tests passed across 41 cases on the signed source. [Build 173](../testing/builds/173.json) installed on the A10X iPad, and iPadOS accepted launch.

## R110 browser, pads, FX, grid and microphone

The new bindings use the report addresses in the Mixxx reference and the factory gestures in the [NI S2 Mk3 manual](https://www.bhphotovideo.com/lit_files/627706.pdf). The hardware connection still starts without app setup.

| Control | App action |
| --- | --- |
| Browse encoder | Select and scroll to a song in the visible iPad list. Hold Shift to change category. |
| Browse press and View | Load the selected song into the matching deck. View expands or closes the browser. |
| Prep | Add the selected song to the prep list. Hold Shift to add it at the start. |
| Hot Cues and Samples | Select the pad mode independently on each deck. Mode lights follow the selection. |
| Sample pad | Load a clip from the selected song into an empty slot. Press a loaded slot to play it from the start. Hold Shift to stop a playing sample or clear an idle slot. SAMPLE controls the bank level. |
| FX 1–4 | Select Filter, Reverb, Delay and Flanger in the factory order. Hold a deck's Shift to target it. The amount knob combines the selected GenErik effect with the filter. |
| Grid and jog | Hold Grid on a paused deck and turn the jog to move the grid. Release Grid to save. Hold Shift with Grid to align the bar start to the playhead. |
| Quantize | Toggle quantize for S2 Hot Cue and loop actions. Sync keeps its own setting. |
| MIC | Toggle the S2 input in the master and recording mix. The first activation needs iPadOS microphone permission and paused decks. |

The sampler uses 16 resident slots. Each slot takes up to four seconds from a playable local track. The app prepares one clip at a time while playback is idle and cancels preparation when playback starts. The sample and mic paths feed the master bus. The headphone blend can include them through its master side. The cue-only side stays separate.

Microphone input requires an iPadOS route that exposes the S2 microphone. The app verifies the input and output device before accepting MIC. The render callback reads a bounded input ring and converts the input rate as needed. Audio recovery mutes the mic if the graph must be rebuilt. The app does not request mic permission at startup.

The grid edit uses a draft until release. It checks the deck generation and the saved grid before committing. Grid locks remain authoritative. The cue metronome, Shift plus Browse eject and Move press loop-roll are outside this increment. The app's Delay supplies the third FX button.

Physical USB or iOS cable input availability, live audio, FX response, sample latency, jog feel and controller brightness still require hardware acceptance.

# Controller implementation knowledge

Reviewed 3 November 2026. Request R23 now covers **all NI controllers and class-compliant MIDI controllers**, including hardware marketed for Serato, Pioneer DJ/AlphaTheta and other DJ systems. Z1 Mk1 remains first. A hardware bridge is allowed. The app target remains the A10X iPad.

## Evidence rules

Use the manufacturer's MIDI/protocol manual for addresses and units. Use maintained implementation/protocol research where the manufacturer does not publish them. Record a source and a separate implementation/hardware result. Do not infer full support from USB detection, an audio device, a brand name or another application's compatibility badge.

The generic input layer must remain independent of vendor profiles. A controller profile defines messages, value encoding, modifiers, deck/layer assignment, jog/touch interpretation and output behaviour. It must not contain executable downloaded code. Unknown handshakes and raw reports remain unsupported until verified.

## Primary source register

| Source | Knowledge used | Implementation implication |
| --- | --- | --- |
| [NI controller setup guide](https://support.native-instruments.com/support/solutions/articles/69000879434-traktor-controller-setup-guide) | Current and discontinued Traktor families, with model-specific manuals. | Preserve individual Mk variants and their different protocols. |
| [NI MIDI-mode guide](https://support.native-instruments.com/support/solutions/articles/69000880031-native-instruments-switching-your-controller-to-midi-mode) | Native versus MIDI operation, including Traktor, Maschine, Komplete, Kore and Rig Kontrol hardware. | MIDI mode does not itself establish an iPad-accessible endpoint. Do not treat a desktop helper/driver as present on iPad. |
| [NI original Z1 manual](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_z1_manual_english_1119.pdf) | Native Z1 use and modes. | Retain TDJ-style button behaviour through the existing native action mapper. |
| [Mixxx maintained Z1 documentation](https://manual.mixxx.org/2.7/en/hardware/controllers/native_instruments_traktor_kontrol_z1.html) | HID control transport, distinct audio routing and hardware-only volume controls. This is a development-version manual. | Keep input, lights and audio as separate capabilities. Do not use Mixxx's secondary button mapping as proof of TDJ behaviour. |
| [Mixxx Z1 implementation](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-Z1-scripts.js) and [report notes](https://github.com/mixxxdj/mixxx/wiki/Native-Instruments-Traktor-Kontrol-Z1/c5c948a256d9da65cecc5591bf3fda4fedab48b2) | Input/light report structure and calibration evidence. | Independently encode the factual protocol. Preserve 12-bit input and actual crossfader calibration. |
| [MIDI Association CC table](https://midi.org/midi-1-0-control-change-messages) | MSB controls and their paired LSB controllers. | Explicit paired-14-bit decoding, separate from ordinary CCs. |
| [Serato MIDI data types](https://support.serato.com/hc/en-us/articles/225065768-MIDI-Data-Types) | Absolute and several relative encodings vary by model. | Expose explicit encoding selection. No brand-wide relative default. |
| [Serato MIDI platter guidance](https://support.serato.com/hc/en-us/articles/225065788-MIDI-Platters) | Platters have model-specific message behaviour. | Do not equate generic Learn with working scratch/jog support. |
| [Pioneer DDJ-FLX4 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-flx4/ddj-flx4_midi_message_list_e1.pdf) | Manufacturer message catalogue and exceptional button/output behaviour. Direct retrieval returned 403; the search index exposes the official document. | Use the verified full document or actual captures before claiming a factory profile. Do not rely on a community reformat alone. |
| [Denon DJ Serato-controller troubleshooting](https://support.denondj.com/en/support/solutions/articles/69000850131-troubleshooting-common-issues-with-serato-controllers) | Driver/class-compliance differences exist within marketed controller groups. | Classify transport per model. Serato compatibility is not one hardware protocol. |
| [Apple iPadOS DriverKit](https://developer.apple.com/documentation/driverkit/creating-drivers-for-ipados) | DriverKit requires an M-series iPad. | Use Core MIDI, a verified accessory protocol or a bridge on A10X. |
| [Linux MIDI gadget](https://www.kernel.org/doc/html/latest/usb/gadget-testing.html) and [hidraw](https://www.kernel.org/doc/html/latest/hid/hidraw.html) | USB-host HID reports and an iPad-facing USB MIDI gadget can be handled on suitable bridge hardware. | The relay requires an actual configured host/device bridge. It does not turn an adapter cable into a USB host. |

The upstream controller scripts were inspected as protocol references. They are not bundled or executed by this app. Internet examples remain evidence, not instructions to run vendor configuration commands.

## Coverage beyond Traktor

| Hardware group | Route into the app | Still required |
| --- | --- | --- |
| NI Traktor controllers | Per-model native transport/profile, MIDI fallback where exposed, or allowed bridge. | See the 18-variant Traktor inventory. Only original Z1 native report groundwork and the new development relay are implemented. |
| NI Maschine/pad controllers | Reachable MIDI input, or an implemented native/bridge adapter. | Native pad modes, displays, LEDs, modifiers and per-device driver requirements. |
| NI Komplete/Kontrol keyboards, M32/A/S families | Reachable MIDI inputs mapped to DJ actions. Notes, pressure, CCs and program changes have generic paths. | Native screen/light-guide integration, template identity and device-specific access. |
| NI legacy Kore/Rig Kontrol hardware | MIDI if exposed, otherwise a researched adapter. | Legacy USB protocols, hardware availability and bridge/driver feasibility. |
| Pioneer DJ / AlphaTheta | Manufacturer MIDI maps, model-specific HID/native adapters where required. | Factory profiles, jog/touch scaling, LEDs/displays and audio acceptance. |
| Serato-compatible hardware | The actual manufacturer's MIDI/HID/native protocol. | Per-model startup, controls, feedback, motors, audio and driver requirements. A Serato badge does not supply a common protocol. |
| Denon, Numark, Rane, Reloop, Roland, Hercules, Vestax, Allen & Heath and other vendors | The same shared input layer and verified profiles. | No blanket claim for every product or Mk variant. Native-only features need their own adapters. |
| Other class-compliant MIDI 1 controllers | MIDI Learn using notes, CCs, pitch bend, pressure and program buttons, with explicit value decoding. | Physical endpoint, mappings, modifiers, output feedback and actual DJ behaviour. Native MIDI 2/UMP-specific support is not established by the legacy input implementation. |

## Implemented increment

- Absolute MIDI controls and full pitch-bend values.
- Explicit paired-14-bit CCs. Partial low-byte state cannot operate a control before its MSB.
- Three relative encodings with reversible direction. Continuous controls are coalesced per input drain.
- Note buttons, poly/channel pressure and program-change button events.
- Existing transport, mixer, filter, FX, ±8% tempo, loops, Beat Jump, Freeze and eight hotcues per deck exposed to Learn.
- User-configured generic MIDI Note/Control Change feedback, scoped to the selected output destination.
- Original Z1 development bridge framing, Linux HID relay, calibration, native input and light/meter output route.

This does not finish all controller support. Verified model profiles, jog/touch and modifier support, simultaneous input selection, soft takeover, native displays/motors and actual bridge audio remain open. Physical Z1 and bridge acceptance remain with Erik.

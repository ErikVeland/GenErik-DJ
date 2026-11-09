# Controller coverage

Request R23. Updated 3 November 2026. Erik owns an original Z1 and allows a hardware bridge when direct iPad access is unavailable. The A10X iPad remains the app target. Erik remains the sole acceptance tester.

## Scope

Cover all NI controllers and class-compliant MIDI controllers, including hardware marketed for Serato, Pioneer DJ/AlphaTheta and other systems. Z1 Mk1 remains first. The Traktor inventory below includes 18 model variants, not the whole expanded scope. NI keyboards/pads and other brands use the shared MIDI layer where their endpoints are reachable, and need verified native adapters for other protocols. See [controller implementation knowledge](controller-research.md) for sources and scope.

| Model family | Variants in scope | Published MIDI-mode position | App state |
| --- | --- | --- | --- |
| S2 | Mk1, Mk2, Mk3 | MIDI mode documented | Generic MIDI input/learn and configurable note/CC output. Model mappings and iPad endpoint access unverified. |
| S3 | S3 | MIDI mode documented | Same. |
| S4 | Mk1, Mk2 | MIDI mode documented | Same. |
| S4 | Mk3 | No MIDI mode in NI's supported-mode table | Native-protocol/bridge work required. No working route claimed. |
| S5, S8 | Both | MIDI mode documented | Generic MIDI input/learn and configurable note/CC output. Screens/native features remain unfinished. |
| X1 | Mk1, Mk2, Mk3 | MIDI mode documented | Generic MIDI input/learn and configurable note/CC output. Model mappings remain unverified. |
| Z1 | Original, Mk2 | MIDI mode documented | Original Z1 has native HID groundwork and a development bridge path. Direct iPad transport, Mk2 mapping and hardware acceptance remain unverified. |
| F1, D2, Z2 | All three | MIDI mode documented | Generic MIDI input/learn and configurable note/CC output. Remix/stem/display/audio features need separate implementation. |
| MX2 | MX2 | MIDI mode documented | Generic MIDI input/learn and configurable note/CC output. Model mapping, feedback behaviour and audio remain unverified. |
| DDJ-FLX4 | DDJ-FLX4 | Published MIDI message list | Opt-in profile maps transport, mixer, Hot Cue pads in Hot Cue pad mode, platter jog and touch, and wheel-side temporary rate bend. A separate output profile maps play, sync, headphone-cue and Hot Cue lights. Touch-rate calibration, endpoint access and hardware acceptance remain unverified. |
| DDJ-REV1 | DDJ-REV1 | Published MIDI message list | Opt-in profile maps dual-deck transport, mixer, tempo, loop controls, one momentary Shift layer, Hot Cue pads in Hot Cue mode, platter jog/touch and wheel-side jog. A separate output profile maps play, sync, headphone-cue and Hot Cue lights. Endpoint access and hardware acceptance remain unverified. |
| DDJ-REV5 | DDJ-REV5 | Published MIDI message list | Opt-in two-deck profile maps transport, mixer, tempo, loop controls, one momentary Shift layer, Hot Cue pads in Hot Cue mode, platter jog/touch and wheel-side jog. A separate output profile maps play, sync, headphone-cue and Hot Cue lights. Deck 3/4 controls and other pad modes are not mapped. Endpoint access, calibration and hardware acceptance remain unverified. |
| DDJ-1000 | DDJ-1000 | Published MIDI message list | Opt-in profile maps Deck 1/2 transport, mixer, tempo, four-beat loop, one momentary Shift layer, Hot Cue pads in Hot Cue mode, platter touch/jog and headphone controls. A separate output profile maps play, sync, headphone-cue and Hot Cue lights with one fixed Hot Cue colour. Deck 3/4 and shifted pad pages are not mapped. Endpoint access and hardware acceptance remain unverified. |
| DDJ-FLX10 | DDJ-FLX10 | Published MIDI message list | Opt-in two-deck profile maps transport, mixer, tempo, loop controls, Beat Jump, one momentary Shift layer, Hot Cue pads in Hot Cue mode, platter jog/touch and wheel-side jog. A separate output profile maps play, sync, headphone cue and Hot Cue lights with a fixed Hot Cue colour. Deck 3/4 and stem controls are not mapped. Endpoint access, calibration and hardware acceptance remain unverified. |

Sources: [NI controller setup guide](https://support.native-instruments.com/support/solutions/articles/69000879434-traktor-controller-setup-guide), [NI MIDI-mode guide](https://support.native-instruments.com/support/solutions/articles/69000880031-native-instruments-switching-your-controller-to-midi-mode), [MX2 product details](https://www.native-instruments.com/products/traktor-mx2), [DDJ-1000 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-1000/ddj-1000_midi_message_list_e1.pdf).

MIDI mode on a computer does not establish a class-compliant iPad MIDI endpoint. NI's original TDJ support list is evidence about its app, not proof that our app has its accessory protocol.

## R100 automatic Traktor setup on iPad

Erik requires automatic connection, controls, audio routing and custom lights. Only the original Z1 is available for physical checks. Record protocol evidence and software checks separately from hardware acceptance.

| Model | Native iPad accessory identifier in TDJ2 | GenErik DJ status |
| --- | --- | --- |
| Z1 Mk1 | `com.native-instruments.traktordj.kontrolz1` | Native controls, automatic audio, blue beat pulse and amber track-end warning. Physical acceptance remains open. |
| S2 Mk2 | `com.native-instruments.traktordj.kontrols2mk2` | Automatic split audio. Native session, controls and lights remain open. |
| S2 Mk3 | `com.native-instruments.protocol.kontrols2mk3` | Automatic split audio. Native session, controls and lights remain open. |
| S3 | `com.native-instruments.protocol.kontrols3` | Automatic split audio. Native session, deck layers, controls and lights remain open. |
| S4 Mk2 | `com.native-instruments.traktordj.kontrols4mk2` | Automatic split audio. Native session, deck layers, controls and lights remain open. |
| MX2, Z1 Mk2, X1 Mk3 | No identifier in the preserved TDJ2 build | Verify a direct iPad connection. Implement factory mappings and feedback for a documented transport. |
| Other Traktor variants | No identifier in the preserved TDJ2 build | Verify transport, per-model control and feedback reports, and audio where fitted. See the variant list above. |

The first increment recognises the four named NI audio devices when iPadOS selects them as the sole wired output. It assigns main to channels 1–2 and headphones to 3–4. The audio session checks for four channels before playback. The controller session is separate.

NI lists the four controllers in its [TDJ2 iPad compatibility guide](https://support.native-instruments.com/support/solutions/articles/69000879425-traktor-dj-2-ios-audio-interface-compatibility). The preserved TDJ2 2.4.1 package declares their accessory identifiers. Its audio table initialisation at `0x1003c6738` pairs each exact device name with zero-based output pairs `[0, 1]` and `[2, 3]`, in the same order as the original Z1. The output constants start at `0x1021b9128`, `0x1021b9158`, `0x1021b9188` and `0x1021b91b8` respectively. See [reference provenance](z1-native-accessory.md).

Use the S2 Mk3 as the next native adapter. Establish its iPad startup and report framing before mapping controls. Use existing deck timing for the blue beat pulse and amber track-end warning. Map those states to the device's verified LED report. Preserve the loop, pause and gesture rules. Record any hardware limits on colour, brightness, screens or motors. No controller has a full support claim from an audio profile alone.

## Required capabilities for each model

Track these separately. None is implied by a name appearing in this table:

1. Connection: the iPad receives the controller through Core MIDI, a verified accessory protocol or an implemented bridge.
2. Input: buttons, modifiers, faders, encoders, jogs and touch contacts have verified decoding and mappings.
3. Behaviour: held controls, takeover, deck assignment and touch/hardware coexistence work correctly.
4. Feedback: lights, meters, displays and motor/haptic features have implemented output where the hardware supports them.
5. Audio: available master/headphone channels, routing, rates and disconnect behaviour work on the actual setup.
6. Acceptance: Erik has checked the available hardware. Unowned models retain explicit hardware-verification gaps.

## Connection architecture

The app uses one controller action route into the existing touch playback/mixer commands. Core MIDI input is opt-in. Multiple sources can stay active while the user selects one source for Learn or a model profile. Mappings and decoder state are scoped to each input and UMP group. Each input has one momentary Shift layer. The generic path maps MIDI 1.0 and MIDI 2.0 channel voice messages. It keeps 16-bit note velocity and 32-bit control, pressure, pitch and parameter values through the action path. It also maps MIDI 2.0 registered and assignable controllers, their relative forms, per-note registered and assignable controllers, and per-note pitch bend. Parameter and per-note mappings retain their identifiers. MIDI 1.0 sources are converted by Core MIDI to UMP. The Z1 SysEx bridge uses its separate legacy byte input. Unmapped UMP message types, including per-note management, are ignored. Input buffering is bounded. The receive path does not run new work in the audio render callback. Absolute continuous controls use soft takeover: input waits until it reaches the current app value within 0.02 normalized units or crosses it. Buttons and jog controls remain immediate. Generic MIDI feedback is opt-in and uses MIDI 1.0 output. Each output destination has its own mappings. The user selects each action's channel, number and button values. DDJ-FLX4, DDJ-REV1, DDJ-REV5, DDJ-1000 and DDJ-FLX10 play, sync, headphone-cue and Hot Cue lights have separate optional profiles. Other model feedback profiles are not implied.

The first increment covers note buttons, absolute control changes and pitch-bend values. The expanded increment adds paired-14-bit CCs, three relative encodings, reversed direction, pressure/program inputs, soft takeover and more existing deck actions. A development Z1 bridge route carries native input, calibration and light/meter feedback. User-configured generic feedback can send note and Control Change states to a selected MIDI destination. One momentary Shift layer per input can select alternate learned mappings. Multiple MIDI inputs can stay active together. Opt-in DDJ-FLX4, DDJ-REV1, DDJ-REV5, DDJ-1000 and DDJ-FLX10 profiles map published two-deck transport, mixer, Hot Cue, jog and touch messages. The FLX4 wheel-side jog applies a temporary rate bend of up to eight percent and returns to normal after 150 ms without input. The REV1 profile maps published loop controls and its second wheel-side jog message. The REV5 profile maps published loop controls and paired high-resolution mixer controls. The DDJ-1000 profile maps its published paired high-resolution mixer/tempo controls and four-beat loop. The FLX10 profile maps published loop controls, Beat Jump and paired high-resolution mixer and tempo controls. Separate profiles map play, sync, headphone-cue and Hot Cue light states for FLX4, REV1, REV5, DDJ-1000 and FLX10. The FLX10 Hot Cue profile uses one fixed colour. Touch-rate calibration, model-specific modifiers, other native model adapters and physical acceptance remain unfinished. This does not complete support for every model.

Where direct transport is unavailable, the allowed bridge acts as USB host for the controller and presents an iPad-accessible connection. The first Linux Z1 relay, matching app framing and opt-in configfs MIDI gadget helper are implemented under `tools/controller_bridge/`. The helper requires Linux bridge hardware and USB IDs assigned to that bridge. Other model adapters, bridge audio, and physical testing remain open. The relay does not forward audio. A generic MIDI cable alone cannot turn proprietary USB traffic into a MIDI controller.

Apple restricts iPadOS DriverKit to M-series devices. The A10X cannot use that route. See [Apple's driver documentation](https://developer.apple.com/documentation/driverkit/creating-drivers-for-ipados). The app will not label inaccessible raw USB hardware as supported.

## Z1 next test

Prepared build 49 introduced **Settings → Controllers**. The expanded candidate adds the bridge and value modes described above. Connect the Z1 with its required power/cable. Enable controller input and inspect the source list. The page separately shows accessory and audio connections and can share those details. Use generic Learn for a real MIDI endpoint. Use the explicit GenErik bridge mode only with the matching relay, input and feedback output. Direct native accessory communication remains unimplemented. Do not invent a MIDI source or protocol identifier.

The original Z1's native report decoder and Mac HID implementation remain preserved. They establish useful protocol groundwork, not A10X transport support. No Mac app development or testing is resumed by this controller work.

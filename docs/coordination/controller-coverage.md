# Controller coverage

Request R23. Updated 10 November 2026. Erik owns an original Z1 and allows a hardware bridge when direct iPad access is unavailable. The A10X iPad remains the app target. Erik remains the sole acceptance tester.

## Scope

Cover all NI controllers and class-compliant MIDI controllers, including hardware marketed for Serato, Pioneer DJ/AlphaTheta and other systems. Z1 Mk1 remains first. The Traktor inventory below includes 18 model variants, not the whole expanded scope. NI keyboards/pads and other brands use the shared MIDI layer where their endpoints are reachable, and need verified native adapters for other protocols. See [controller implementation knowledge](controller-research.md) for sources and scope.

| Model family | Variants in scope | Published MIDI-mode position | App state |
| --- | --- | --- | --- |
| S2 | Mk1, Mk2, Mk3 | MIDI mode documented | Mk2 and Mk3 have native iPad mappings. Mk1 has a native HID and audio bridge. |
| S3 | S3 | MIDI mode documented | Native four-deck iPad mapping. |
| S4 | Mk1, Mk2 | MIDI mode documented | Mk2 has a native four-deck iPad mapping. Mk1 uses a native control and audio bridge. |
| S4 | Mk3 | No MIDI mode in NI's supported-mode table | A Linux bridge implementation is available for A10X. See [R123](#r123-s4-mk3-connection). |
| S5, S8 | Both | MIDI mode documented | Native controls, lighting, screen status and split audio through the Linux bridge. |
| X1 | Mk1, Mk2, Mk3 | MIDI mode documented | All three have native bridge adapters. |
| Z1 | Original, Mk2 | MIDI mode documented | The original Z1 has a native iPad mapping. Mk2 has a native HID and audio bridge. |
| F1, D2, Z2 | All three | MIDI mode documented | Native bridge adapters. D2 shows deck status. Z2 uses split audio. |
| MX2 | MX2 | MIDI mode documented | Native control, split audio and lighting through the Linux bridge. |
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
| S2 Mk1 | No identifier in the preserved TDJ2 build | Linux bridge carries native controls, four-channel audio and custom lighting. See [R126](#r126-s2-mk1). |
| S2 Mk2 | `com.native-instruments.traktordj.kontrols2mk2` | Automatic split audio, native deck and mixer controls, and blue and amber lights on pad 4. See [scope and checks](s2-mk2-native.md). |
| S2 Mk3 | `com.native-instruments.protocol.kontrols2mk3` | Automatic split audio and native deck and mixer controls. Pad 8 shows the blue beat pulse and amber warning. See [scope and checks](s2-mk3-native.md). |
| S3 | `com.native-instruments.protocol.kontrols3` | Automatic split audio, native four-deck controls and blue and amber jog rings. See [scope and checks](s3-native.md). |
| S4 Mk1 | No identifier in the preserved TDJ2 build | Linux CAIAQ bridge carries native four-deck controls, split audio and blue and amber lighting. See [R128](#r128-s4-mk1). |
| S4 Mk2 | `com.native-instruments.traktordj.kontrols4mk2` | Automatic split audio, native four-deck controls and blue and amber Hot Cue lighting. See [scope and checks](s4-mk2-native.md). |
| S4 Mk3 | No identifier in the preserved TDJ2 build | Linux bridge carries four-deck controls, lighting and four-channel audio. Hardware verification remains open. See [R123](#r123-s4-mk3-connection). |
| Z1 Mk2 | No identifier in the preserved TDJ2 build | Linux bridge carries four-deck mixer controls, audio and custom lights. See [R125](#r125-z1-mk2-and-x1-mk3). |
| X1 Mk3 | No identifier in the preserved TDJ2 build | Linux bridge carries four-deck transport, browse, FX and custom lights. See [R125](#r125-z1-mk2-and-x1-mk3). |
| X1 Mk1, X1 Mk2, F1, D2, Z2, S5, S8, MX2 | No identifiers in the preserved TDJ2 build | The app detects each named bridge and loads its factory mapping. See [R137](#r137-remaining-traktor-variants) for scope and open checks. |

The first increment recognises the four named NI audio devices when iPadOS selects them as the sole wired output. It assigns main to channels 1–2 and headphones to 3–4. The audio session checks for four channels before playback. The controller session is separate.

NI lists the four controllers in its [TDJ2 iPad compatibility guide](https://support.native-instruments.com/support/solutions/articles/69000879425-traktor-dj-2-ios-audio-interface-compatibility). The preserved TDJ2 2.4.1 package declares their accessory identifiers. Its audio table initialisation at `0x1003c6738` pairs each exact device name with zero-based output pairs `[0, 1]` and `[2, 3]`, in the same order as the original Z1. The output constants start at `0x1021b9128`, `0x1021b9158`, `0x1021b9188` and `0x1021b91b8` respectively. See [reference provenance](z1-native-accessory.md).

[Build 164](../testing/builds/164.json) installed on the A10X iPad. iPadOS accepted launch. Ten focused tests passed across thirteen cases. The new controller audio profiles have no physical listening result.

The [S2 Mk3](s2-mk3-native.md) and [S3](s3-native.md) adapters use the same beat and warning timing as the Z1.

## R123 S4 Mk3 connection

NI's iOS connectivity table gives the S4 Mk3 no supported iPad connection. The preserved Traktor DJ 2.4.1 app lists the S4 Mk2 accessory protocol and has no Mk3 entry. NI's MIDI-mode table also has no S4 Mk3 entry. USBDriverKit requires an M-series iPad, so it cannot provide raw USB access on the A10X. [NI iOS connectivity](https://support.native-instruments.com/support/solutions/articles/69000879456-how-to-connect-your-ni-controller-audio-interface-to-an-ios-device) · [NI MIDI-mode table](https://support.native-instruments.com/support/solutions/articles/69000880031-native-instruments-switching-your-controller-to-midi-mode) · [Apple USBDriverKit](https://developer.apple.com/documentation/usbdriverkit)

Mixxx uses the vendor HID interface `17cc:1720`, interface `03`, for input and LED output. Its desktop audio mapping assigns master to channels 1–2 and headphones to 3–4. These mappings require a connection that exposes the controls and audio to the app. [Mixxx HID preset](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor%20Kontrol%20S4%20MK3.hid.xml) · [Mixxx audio mapping](https://manual.mixxx.org/2.5/en/hardware/controllers/native_instruments_traktor_kontrol_s4_mk3)

The S4 Mk3 bridge keeps the controller in HID mode. It presents USB MIDI and four-channel USB Audio to the iPad. GenErik DJ detects the bridge automatically. The mapping covers four-deck playback, mixer controls, browse and load, Preview, jog touch, loops, Hot Cues, samples, Grid and two FX units. The jog rings use the shared blue beat pulse and amber warning. Motors, displays and capture remain open. [Bridge setup and verification limits](../../tools/controller_bridge/README.md#s4-mk3-audio-and-control-bridge)

The separate M-series DriverKit scheme adds a direct USB transport for the same app mapping. It needs a signed driver and hardware verification. [DriverKit build and verification](s4-mk3-driverkit.md)

Twenty-two focused Swift tests and thirteen bridge tests passed. Build 186 passed local iOS signing and runtime checks. The physical bridge and iPad were outside this verification. [Build record](../testing/builds/186.json)

## R125 Z1 Mk2 and X1 Mk3

Both models use their documented native HID reports through the Linux bridge. The app connects automatically when the matching bridge appears. The Z1 Mk2 bridge also supplies four audio channels. GenErik DJ assigns master to 1–2 and headphones to 3–4. The audio route also recognises the Z1 Mk2 when iPadOS exposes its wired audio output directly. Direct USB audio does not provide native HID controls. [Bridge setup](../../tools/controller_bridge/README.md#z1-mk2-and-x1-mk3-bridges) · [Z1 Mk2 audio specifications](https://www.native-instruments.com/products/traktor-z1)

- **Z1 Mk2.** A/B and C/D mixer layers, gain, EQ, channel faders, crossfader, headphone cue and blend, mixer FX and level meters. The Z1 controls its own master and headphone volume when it supplies the audio output. GenErik DJ uses filter and four mixer FX presets. The app does not map Stem mode or the OLED displays. [NI control guide](https://docs.native-instruments.com/online-guides/traktor-z1-mk2-manual/en/using-the-z1-with-traktor) · [HID report map](https://github.com/infifox/mixxx-traktor-controllers/blob/a9e8f8ea8adbed29c4d86d224049990ec8ba21ca/doc/TraktorZ1MK2.spec.md)
- **X1 Mk3.** Menu switches between A/B and C/D. The two sides map transport, held Cue, nudge, reverse, Hot Cues, loops, browse, load and FX groups. Shift turns browse into group navigation and selects the mapped secondary transport actions. Displays, mixer mode and Pattern Player remain open. The X1 Mk3 has no audio interface. [NI hardware guide](https://docs.native-instruments.com/online-guides/traktor-x1-mk3-manual/en/hardware-overview) · [HID report map](https://github.com/infifox/mixxx-traktor-controllers/blob/36dc56869f3ad681e9b12f10f3dd15d0c4d540e6/doc/TraktorX1MK3.spec.md)

The bottom LEDs on both models use the shared blue beat pulse and amber track-end warning. Local checks cover report decoding, deck changes, light values, gadget creation and selection of the split audio route. Physical controller behaviour, bridge audio and A10X performance remain open. These models are outside the S4 Mk3 DriverKit entitlement request.

Thirty-five focused Swift tests and sixteen bridge tests passed. [Build 187](../testing/builds/187.json) passed local signing and runtime framework checks. Verification stayed off the iPad. The build history retains the failed local attempts.

The remaining Traktor models without a factory adapter are S5, S8, X1 Mk1, X1 Mk2, F1, D2, Z2 and MX2. Mixxx has HID mappings for F1 and MX2. Encdr has hardware references for X1 Mk1, X1 Mk2, S5, S8, D2 and Z2. [Mixxx controller mappings](https://github.com/mixxxdj/mixxx/tree/main/res/controllers) · [Encdr hardware references](https://github.com/RufusIbiza/Encdr/tree/a5414658a69c4330d10b95f2359371dfc8550326/docs/hardware)

## R126 S2 Mk1

The Linux bridge uses HID interface 03 on USB device `17cc:1101`. It reads the button, analogue and factory calibration reports. The app detects the bridge and selects master 1–2 and headphones 3–4. The controller mixes its microphone into the physical output. The bridge sends no microphone audio to the app. [Bridge setup](../../tools/controller_bridge/README.md#s2-mk1-bridge) · [Mixxx report map](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-S2-MK1-hid-scripts.js) · [Audio routing](https://manual.mixxx.org/2.5/en/hardware/controllers/native_instruments_traktor_kontrol_s2_mk1.html#audio-routing)

The mapping covers A/B transport, held Cue, jog scratch and rim nudge, browse and load, loop in and out, loop move and size, Hot Cues, samples, tempo lock, mixer controls and FX groups. GenErik DJ keeps its saved Sync behaviour. Shift+GAIN adjusts the app filter. See [R127](#r127-s2-mk1-shift-and-loop-controls) for deck cloning, loop trimming and crossfader assignment. [Native Instruments S2 Mk1 manual](https://images-eu.ssl-images-amazon.com/images/I/C1z6RGpnVTS.pdf)

Pad 4 on each deck shows the blue beat pulse. The separate amber Alert lamp shows the track-end warning for either deck. The pads have blue and green emitters. Pad feedback restores the stored cue, loop or sample colour after the beat pulse. [Hardware report reference](https://github.com/RufusIbiza/Encdr/blob/a5414658a69c4330d10b95f2359371dfc8550326/docs/hardware/ni_kontrol_s2_mk1.md)

Twenty-four focused Swift tests and seventeen bridge tests passed. [Build 188](../testing/builds/188.json) passed local signing and runtime framework checks. Verification stayed off the iPad. Physical controls, lighting, audio and bridge latency remain unverified.

## R127 S2 Mk1 Shift and loop controls

- **Shift+Load A/B** copies the opposite deck's track and its playhead position at the time of the press. The destination must be stopped and stays ready to play with its own saved Sync setting. A streamed clone uses an independent decoder or read-ahead buffer.
- **Loop In or Out + jog** moves only the held edge of an active loop. The app combines jog ticks in each poll and keeps the edges inside the track. The transport still applies Sync. Stored cues and loops retain their saved positions.
- **Shift+FX 1/2** assigns the channel to the left or right crossfader side. Press the same side again to unlink the channel. The FX buttons show that assignment while Shift is held. The audio engine smooths the change and keeps headphone cue independent. Recovery auto-mix requires the default left and right assignments.

The bridge uses the same reports. GenErik DJ requires no settings for these controls. [NI S2 Mk1 manual](https://images-eu.ssl-images-amazon.com/images/I/C1z6RGpnVTS.pdf) · [NI deck duplication reference](https://docs.native-instruments.com/ni-tech-manuals/traktor-pro-manual/en/preferences)

Twenty-six focused Swift tests and seventeen bridge tests passed. [Build 189](../testing/builds/189.json) passed local signing and runtime framework checks. Verification stayed off the iPad. Physical operation remains unverified.

## R128 S4 Mk1

The S4 Mk1 (USB `17cc:baff`) uses Native Instruments' CAIAQ USB protocol. The Linux kernel driver supplies native controls, LED brightness and four-channel playback. GenErik DJ detects the named [S4 Mk1 bridge](../../tools/controller_bridge/README.md#s4-mk1-bridge) and selects master 1–2 and headphones 3–4. [Linux input driver](https://github.com/torvalds/linux/blob/master/sound/usb/caiaq/input.c) · [Linux LED driver](https://github.com/torvalds/linux/blob/master/sound/usb/caiaq/control.c) · [Linux audio driver](https://github.com/torvalds/linux/blob/master/sound/usb/caiaq/audio.c)

The mapping includes A/C and B/D deck layers, fixed A–D mixer channels, transport, held Cue, Sync, keylock, jog scratch and rim nudge, browse and load, headphone preview and seek, Shift+Load, Hot Cues, sample pads, loop in and out, loop size, Move, tempo pickup and lock, Snap, Quantize and two FX units. Shift+FX assigns the mixer channel to either crossfader side. The loop display and channel meters follow the app. [NI S4 Mk1 manual](https://manualzz.com/doc/22304763/native-instruments-traktor-kontrol-s4-manual) · [Backspn mapping](https://github.com/suitux/Backspn/blob/71668201f3d0ff6658cfd72fb5386dba9ebb789f/crates/control/src/kontrol/s4mk1.rs)

Pad 4 on each selected deck shows the blue beat pulse. The shared amber Alert lamp follows the track-end warning for all four playing decks. The pad returns to its stored Hot Cue or loop colour between pulses.

Thirty-six focused Swift tests and nineteen bridge tests passed. [Build 191](../testing/builds/191.json) passed local signing and framework checks. The first compile of build 190 caught a missing tempo feedback value. Its log is in `TestBuilds/r128/build-190-first-attempt.log`. The corrected [build 190](../testing/builds/190.json) passed before the Browse preview change. All checks stayed off the iPad.

R134 adds the Loop Recorder, footswitch, FX Mode, clock master, jog loop trimming, Browse and Copy controls, and audio capture. See [R134](#r134-s4-mk1-remaining-controls).

## R134 S4 Mk1 remaining controls

- **Loop Recorder.** SIZE cycles through 4, 8, 16 and 32 beats. REC and the footswitch use the same record or overdub action. Initial capture starts at the next master beat. PLAY starts or stops playback. UNDO deletes a stopped loop or toggles the most recent overdub. DRY/WET blends the recorded loop with the live master mix.
- **FX.** MODE switches each unit between Single and Group. Shift+MODE saves the Single effect's parameter defaults for the current connection. Shift+FX buttons select effects. The app uses its own effect parameters in both modes.
- **Clock.** MASTER selects the internal clock. Shift+SYNC selects a deck with a beat grid as the tempo reference. The app preserves each deck's saved Sync choice and preserves clock phase while another synced deck is active.
- **Loop trim.** Hold LOOP IN or LOOP OUT and turn the jog wheel during an active loop. The app adjusts only the selected edge. It keeps the loop within the track.
- **Browse and Copy.** Tap BROWSE to toggle Browse mode. Mixer CUE loads tracks. Sample Play loads samples. Hold BROWSE and select a source and target to copy a track between decks or a sample between pads. Loop Recorder PLAY selects the recorded loop as a copy source. The pad plays the copy as a one-shot sample.
- **Audio.** The bridge returns four input channels. Inputs 1–2 feed the empty C mixer channel. Inputs 3–4 feed stereo AUX, and MIC VOL controls that pair. The controller switches inputs 3–4 to the microphone when it is plugged in. The system may ask for microphone permission.

Fifty-one focused Swift tests and twenty bridge tests passed on the source for [build 195](../testing/builds/195.json). The build passed local signing and framework checks. [Build 194](../testing/builds/194.json) passed those checks before Loop Recorder copy was added. All checks stayed off the iPad. Logs are in `TestBuilds/r134/`.

The Loop Recorder uses Main as its fixed source. Alternate Loop Recorder sources remain open. Physical checks remain open for both playback and capture channel order, latency, drift, control feel and reconnect behavior. [NI S4 Mk1 manual](https://manualzz.com/doc/22304763/native-instruments-traktor-kontrol-s4-manual) · [Linux CAIAQ audio driver](https://github.com/torvalds/linux/blob/master/sound/usb/caiaq/audio.c)

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

## R137 remaining Traktor variants

These factory adapters cover the eight remaining Traktor models in the 18-model inventory. The app detects the Linux bridge by its MIDI device name. It needs no MIDI Learn or app setting. The bridge requires its own setup. [Setup](../../tools/controller_bridge/README.md#x1-mk1-x1-mk2-f1-d2-z2-s5-s8-and-mx2)

| Models | Mapped functions | Lighting and output |
| --- | --- | --- |
| X1 Mk1 and X1 Mk2 | A/B transport, held Cue, Sync, browse and load, loops, Hot Cues and two FX units. Mk2 also maps the touch strip. | Mk1 uses fixed-colour lamps for the beat and warning. Mk2 uses the two-colour strip. |
| F1 | Sixteen sample cells, column stop, browse, Sync and Quantize. | Sample pads show state. Pad 16 shows the blue beat and amber warning for deck C. |
| D2 | Selectable deck, transport, browse and load, loops, pads, touch strip, Grid and FX. | Touch-strip lights show blue and amber. The screen shows deck and track status. |
| Z2 | Four-deck mixer, deck selection, Hot Cues, Sync, browse and load, loop size displays, FX and cue mix. | RGB pad lighting, channel meters and split audio. |
| S5 and S8 | Four-deck mixing, two deck surfaces, browse and load, loops, pads, FX and touch strips. S8 also maps mixer switches and Grid. | Channel meters, blue and amber strips, split audio and deck status on both screens. |
| MX2 | Two-deck transport, jog and touch, browse and load, headphone Preview, loop rolls, Hot Cues, mixer and FX. | Blue and amber light strips, channel meters and split audio. |

For Z2, S5, S8 and MX2, the gadget presents master on 1–2 and headphones on 3–4. The relay sends these four channels to the controller's ALSA playback device. NI documents headphones on channels 3–4 for its integrated Traktor interfaces. Check the physical output order, latency and reconnect behavior before live use. No physical controller or bridge was available for R137. [NI channel routing](https://support.native-instruments.com/support/solutions/articles/69000879976-using-a-native-instruments-audio-interface-as-system-audio-output).

Open functions include full Remix Deck editing and F1 per-slot faders and filters, stems and Pattern Player, Z2 timecode and analogue capture, and MX2/S8 microphone capture. The colour panels show title, time, BPM and playback state. Waveforms and the controller's on-screen browser remain open. The existing S4 Mk3 motor, display and capture limits still apply.


Eleven focused Swift tests and 23 bridge tests passed on the source for [build 200](../testing/builds/200.json). A host check rendered a colour panel with a non-ASCII track title. The signed build passed the runtime framework check. Builds [198](../testing/builds/198.json) and [199](../testing/builds/199.json) record earlier candidates. All R137 checks stayed off the iPad. Logs are in `TestBuilds/r137/`.

Sources. [NI older manuals](https://support.native-instruments.com/support/solutions/articles/69000879398-traktor-manuals-for-older-devices) · [X1 Mk1 USB mapping](https://github.com/Opa-/x1-mk1-usb2midi/blob/main/board.yml) · [Backspn report layouts](https://github.com/suitux/Backspn/tree/e0244b9c3ef16409d8c26fa2d27af3b7156204c5/crates/control/src/kontrol) · [Backspn screen protocol](https://github.com/suitux/Backspn/blob/e0244b9c3ef16409d8c26fa2d27af3b7156204c5/crates/control/src/s4mk3/screen.rs) · [Encdr endpoint descriptors](https://github.com/RufusIbiza/Encdr/tree/a5414658a69c4330d10b95f2359371dfc8550326/encdr/descriptors) · [Mixxx MX2 mapping](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-MX2-hid-scripts.js).

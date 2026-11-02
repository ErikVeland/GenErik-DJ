# Traktor controller coverage

Request R23. Updated 2 November 2026. Erik owns an original Z1 and allows a hardware bridge when direct iPad access is unavailable. The A10X iPad remains the app target. Erik remains the sole acceptance tester.

## Scope

Cover current and discontinued Native Instruments Traktor-branded controller models, including models that never supported TDJ iOS. This inventory includes 18 model variants. It does not turn every third-party Traktor mapping into a supported controller.

| Model family | Variants in scope | Published MIDI-mode position | App state |
| --- | --- | --- | --- |
| S2 | Mk1, Mk2, Mk3 | MIDI mode documented | Generic MIDI input/learn layer prepared. Model mappings and iPad endpoint access unverified. |
| S3 | S3 | MIDI mode documented | Same. |
| S4 | Mk1, Mk2 | MIDI mode documented | Same. |
| S4 | Mk3 | No MIDI mode in NI's supported-mode table | Native-protocol/bridge work required. No working route claimed. |
| S5, S8 | Both | MIDI mode documented | Generic input layer only. Screens/native features remain unfinished. |
| X1 | Mk1, Mk2, Mk3 | MIDI mode documented | Generic input layer only. Model mappings/feedback unverified. |
| Z1 | Original, Mk2 | MIDI mode documented | Original Z1 has existing native HID groundwork. Direct iPad transport and hardware acceptance remain unverified. Mk2 is separate. |
| F1, D2, Z2 | All three | MIDI mode documented | Generic input layer only. Remix/stem/display/audio features need separate implementation. |
| MX2 | MX2 | MIDI mode documented | Generic input layer only. Mapping, feedback and audio unverified. |

Sources: [NI controller setup guide](https://support.native-instruments.com/support/solutions/articles/69000879434-traktor-controller-setup-guide), [NI MIDI-mode guide](https://support.native-instruments.com/support/solutions/articles/69000880031-native-instruments-switching-your-controller-to-midi-mode), [MX2 product details](https://www.native-instruments.com/products/traktor-mx2).

MIDI mode on a computer does not establish a class-compliant iPad MIDI endpoint. NI's original TDJ support list is evidence about its app, not proof that our app has its accessory protocol.

## Required capabilities for each model

Track these separately. None is implied by a name appearing in this table:

1. Connection: the iPad receives the controller through Core MIDI, a verified accessory protocol or an implemented bridge.
2. Input: buttons, modifiers, faders, encoders, jogs and touch contacts have verified decoding and mappings.
3. Behaviour: held controls, takeover, deck assignment and touch/hardware coexistence work correctly.
4. Feedback: lights, meters, displays and motor/haptic features have implemented output where the hardware supports them.
5. Audio: available master/headphone channels, routing, rates and disconnect behaviour work on the actual setup.
6. Acceptance: Erik has checked the available hardware. Unowned models retain explicit hardware-verification gaps.

## Connection architecture

The app uses one controller action route into the existing touch playback/mixer commands. Core MIDI input is opt-in. Mappings are scoped to an input identity, retained locally and learned without executing the control. Unsupported MIDI message types are ignored. Input buffering is bounded. It does not run new work in the audio render callback.

The first controller increment covers note buttons, absolute control changes and pitch-bend values. Relative encoders, high-resolution paired CCs, jog touch/rate, output feedback and native model profiles are unfinished. This is not complete support for any model by itself.

Where direct transport is unavailable, the allowed bridge acts as USB host for the controller and presents an iPad-accessible connection. Model adapters must decode verified device reports and translate app feedback back to the device. A generic MIDI cable alone cannot turn proprietary USB traffic into a MIDI controller. Bridge hardware and firmware still need implementation and testing.

Apple restricts iPadOS DriverKit to M-series devices. The A10X cannot use that route. See [Apple's driver documentation](https://developer.apple.com/documentation/driverkit/creating-drivers-for-ipados). The app will not label inaccessible raw USB hardware as supported.

## Z1 next test

Prepared build 49 adds **Settings → Controllers**. Connect the Z1 with its required power/cable. Enable controller input and inspect the source list. The page separately shows accessory and audio connections and can share those details. If a usable MIDI input appears, learn controls and check their behaviour. If it does not, retain that result and implement the verified accessory or bridge route. Do not invent a MIDI source or protocol identifier.

The original Z1's native report decoder and Mac HID implementation remain preserved. They establish useful protocol groundwork, not A10X transport support. No Mac app development or testing is resumed by this controller work.

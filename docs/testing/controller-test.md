# Original Z1 native iPad test

R82 replaces the MIDI fallback with the Z1 Mk1's native accessory connection. No MIDI Learn or bridge is required. The connection remains a hardware test candidate until Erik verifies it.

1. Stop playback in Traktor DJ and close it from the app switcher.
2. Open GenErik DJ.
3. Connect and power the original Z1 using its normal iPad cable.
4. If iPadOS asks to open Traktor DJ, cancel the prompt.
5. Open **Settings → Controllers**.
6. Check that **Connect original Z1 directly** is on.
7. Wait for **Z1 native controls connected**.
8. Move each channel fader and check the corresponding on-screen volume.
9. Move the crossfader and check both endpoints and the centre.
10. Check gain, EQ, filter, headphone cue and cue blend.
11. Check MODE plus cue for deck playback and pause.
12. Check MODE plus filter ON for filter/FX selection.
13. Check the cue/filter lights and level meters during playback.

Native discovery starts automatically and remembers an explicit off choice. Leave the separate MIDI input and bridge switches off for this test. The MAIN and headphone volume knobs are hardware audio controls.

If startup fails, close Traktor DJ and reconnect the Z1. You can also switch **Connect original Z1 directly** off and on. Share **controller connection details** if the failure continues. Report the exact native status, accessory firmware and protocol.

## Audio and reconnect

1. Reduce the speaker and headphone levels.
2. Stop both decks before changing audio routing.
3. Open the speaker button and expand **Routing and headphones**.
4. If the Z1 exposes four channels, select **Master 1–2 / Headphones 3–4**.
5. Play a track and check the main output.
6. Check headphone cue separately.
7. Check audio continuity and touch response while moving multiple controls.
8. Stop playback before the first unplug/reconnect check.
9. Reconnect the Z1 and confirm that calibration and control input resume.

Audio detection alone does not establish working controls. Compilation, installation and launch do not establish performance readiness. See the [protocol evidence and remaining work](../coordination/z1-native-accessory.md).

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
2. Connect the Z1 before starting playback.
3. Open the speaker button and check **Z1 OUTPUT → Automatic**.
4. Expand **Routing and headphones** and check **Z1 main and headphones · Automatic**.
5. Play a track and check the main output.
6. Check headphone cue separately.
7. Check audio continuity and touch response while moving multiple controls.
8. Stop playback before the first unplug/reconnect check.
9. Reconnect the Z1 and confirm that calibration, control input and automatic headphone routing return.

R97 selects main 1–2 and headphones 3–4 automatically for the original Z1.
No routing switch or picker is required. Repeat the headphone check after closing and reopening the app.
During an active disconnect, the app holds audio to prevent an unexpected switch to the iPad speaker.
Press Play to resume.

Audio detection alone does not establish working controls. Compilation, installation and launch do not establish performance readiness. See the [protocol evidence and remaining work](../coordination/z1-native-accessory.md).

## Beat and warning lights

1. Load a track with a valid beat grid on each deck.
2. Play both decks and check the small blue pulse on each channel's filter/FX ON button.
3. Change the tempo and check that the pulses follow each deck's beat.
4. Move a track to just before 30 seconds remaining.
5. Check that amber pulses every four beats after the 30-second boundary.
6. Check that amber pulses every beat after the 10-second boundary.
7. Toggle MODE plus ON, then test the filter and selected FX controls during the warning.
8. Enable a loop near the end. Check that blue continues and amber warnings stop.
9. Pause the deck. Check that the normal filter/FX status light returns.
10. Check audio continuity and touch response with both channels pulsing.

The countdown follows playback speed. Each deck needs a valid beat grid for these pulses.
The warning has visual priority over the blue accent. Physical brightness and colour still need this test.

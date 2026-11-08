# First original Z1 test on iPad

R81 prepares the connection test. Direct Z1 accessory control on iPad is not implemented. The existing MIDI Learn path can receive controls only if iPadOS exposes a MIDI input. Audio detection does not prove controller support.

## Connect to GenErik DJ first

1. Stop playback in Traktor DJ and close it from the app switcher.
2. Open GenErik DJ.
3. Open **Settings → Controllers**.
4. Enable **controller input**.
5. Connect and power the original Z1 using its normal iPad cable.
6. If iPadOS asks to open Traktor DJ, cancel that prompt.
7. Keep GenErik DJ in the foreground.
8. Read **First Z1 test** at the top of Controllers.

Cancelling the prompt avoids opening Traktor DJ. It does not assign the accessory to GenErik DJ. [Apple requires a supported accessory protocol and matching session code](https://developer.apple.com/library/archive/featuredarticles/ExternalAccessoryPT/Introduction/Introduction.html). GenErik DJ cannot yet claim the Z1's native iPad connection.

## Check control input

1. If a Z1 MIDI input appears, select it under **Input to configure**.
2. Keep **Original Z1 through GenErik bridge** off for a direct cable connection.
3. Choose **Learn** beside **A · Volume**.
4. Move the Z1's left channel fader.
5. Check that **Last input** shows changing values and that Learn saves the assignment.
6. Move the fader again and check the on-screen volume response.

Learning does not operate the deck. Soft takeover can require the fader to cross the current software value before it changes volume. Test other controls only after this first control works.

If no MIDI input appears, try MODE plus both headphone cue buttons with playback stopped. NI documents this combination with **Enable MIDI mode via Mode + Cues** enabled in Traktor on a computer. This does not establish iPad compatibility. See the [original Z1 manual](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_z1_manual_english_1119.pdf).

Select **Refresh connection details** after changing the cable or mode. The panel also refreshes on accessory changes, audio-route changes and return to the foreground. Select **Share controller connection details** to report the build, MIDI ports, last input, accessory protocols and audio channels.

If only the accessory or audio output appears, stop the control test and report those details. The native accessory protocol or a verified bridge remains required. Do not select a Pioneer profile for the Z1.

## Check audio separately

1. Reduce the speaker and headphone levels.
2. If the Z1 exposes four output channels, stop both decks.
3. Open the speaker button and expand **Routing and headphones**.
4. Select **Master 1–2 / Headphones 3–4**.
5. Play a track and check the main output.
6. Use the on-screen headphone cue and check the headphone output separately.
7. Check for audio gaps and delayed touch controls.

Physical channel routing, faders, EQ, filter/FX, cue buttons, lights and disconnect behaviour remain unverified. A successful connection test does not establish performance readiness.

## Optional development bridge

Use the [original Z1 bridge guide](../../tools/controller_bridge/README.md) only with a configured Linux USB host/device bridge. Select its MIDI input, enable **Original Z1 through GenErik bridge**, then select its feedback output. Verify calibration before testing the crossfader.

The bridge has not passed a physical hardware test. It does not forward Z1 audio.

# Original Z1 connection test

Use build 51, prepared but not installed by this chat. This test establishes the connection route first. It does not certify complete Z1 support.

1. Connect and power the original Z1 using its normal iPad connection.
2. Open **Settings → Controllers**.
3. Enable controller input.
4. Check the input list and the accessory/audio connection details.
5. If no MIDI input appears, try the documented original Z1 MIDI-mode combination: MODE plus both headphone cue buttons.
6. Refresh the connections.
7. Report the listed MIDI inputs and accessory/audio details in this chat. The share button can copy the details.

If a usable MIDI input appears:

1. Select that input.
2. Choose **Learn** beside a volume or EQ action.
3. Move the corresponding hardware control.
4. Confirm that learning saves the assignment without operating the deck.
5. Move the control again and check its response.
6. Test transport buttons only when ready for them to operate playback.

Start with absolute knobs/faders and momentary buttons. Build 51 also supports paired 14-bit CCs, three relative encoder formats, pressure and program-change buttons. Select the correct encoding and reverse direction when required. Generic jog/touch behaviour, lights and displays remain open. Input overload disconnects controller input instead of processing an unlimited backlog.

If the Z1 appears only as an accessory or audio route, report that result. Do not treat audio routing as proof of button/fader support. That result directs the accessory-protocol or permitted bridge implementation.

## Optional development bridge

Use the [original Z1 bridge guide](../../tools/controller_bridge/README.md) only with a configured Linux USB host/device bridge. Select its MIDI input, enable **Original Z1 through GenErik bridge**, then select its feedback output. Verify calibration before testing the crossfader.

This bridge software has not been tested with physical hardware. It does not forward Z1 audio. Use a separate supported iPad audio route until audio bridging is implemented and tested.

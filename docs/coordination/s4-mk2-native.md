# R117 Traktor Kontrol S4 Mk2 on iPad

The app opens the S4 Mk2 accessory automatically. It uses the existing four-deck engine and the R100 route. Master uses outputs 1–2. Headphones use outputs 3–4. Preview goes to headphones. The S4 Mk2 uses its own power supply and the NI Lightning cable. [NI iOS connection guide](https://support.native-instruments.com/hc/en-us/articles/210280705-How-to-Connect-your-NI-Controller-Audio-Interface-to-an-iOS-Device)

| Control | App action |
| --- | --- |
| Deck C and D buttons | Switch the left controls between A and C, or the right controls between B and D. The four physical mixer strips keep their deck assignments. Tempo uses pickup after each switch. |
| Transport and jog | Play, Cue, Sync, Shift+Cue, key lock, Flux, scratch, and temporary pitch bend. Shift+Sync starts or ends grid editing. The jog adjusts grid phase and the four Hot Cue buttons select the downbeat. |
| Hot Cue and Remix | Store, recall, or delete four deck cues. The four Remix buttons on each side use the app's sample bank. |
| Loop controls | Set IN and OUT, change size, toggle or recall a loop, or move the loop. MOVE does beat jumps when the deck has no active loop. |
| Browser | Browse opens the library, the encoder moves through entries, Shift+turn changes category, and LOAD sends the selection to the active layer. Shift+LOAD ejects a paused deck. The Preview button toggles headphone preview. |
| Mixer | Four faders, EQ, filters, gain encoders, headphone cue, crossfader, and cue blend. The controller handles master and headphone volume. |
| FX | Channel buttons assign the two FX sections to deck FX. The three buttons and knobs use the deck's three effect slots. DRY/WET sets the Y value. FX 1 has priority when both units enable the same slot on one deck. |
| Other controls | Record starts or stops master recording. SNAP applies to new cue and loop positions. QUANT switches quantized cue recall. Hold MASTER and turn BROWSE to adjust master tempo. |

The fourth Hot Cue LED on each side shows the blue beat pulse and amber track-end warning for the selected deck layer. Its normal cue indication returns when the pulse ends. Transport, layer, loop size, channel meters and assigned FX have native feedback. The existing monitor sends feedback only when the report changes. The audio render path has no S4-specific work.

The archived Traktor DJ 2.4.1 app identifies the S4 Mk2 as `com.native-instruments.traktordj.kontrols4mk2`. Its accessory startup requests `D0` through `D5`, then receives 98 payload bytes in report `01`. Its LED writer sends 174 payload bytes in report `83`. The Mixxx USB mapping supplies the control and LED field assignments. Native iPad reports use a different frame and combine the USB fields. [NI manual](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_s4_mk2_manual_english.pdf) · [Mixxx hardware mapping](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-S4-MK2-hid-scripts.js)

Physical connection, calibration, audio, jog response and LED output remain open. R119 extends the mapping below.

Eleven focused host tests passed. Five S4 Mk2 tests cover startup, calibration, layer switching, blue and amber feedback, and route selection. Existing S3 framing and Z1 routing tests also passed.

[Build 181](../testing/builds/181.json) installed on the A10X iPad. iPadOS accepted the launch request.

## R119 Freeze, Loop Slicer, Cue and external input

Press MOVE to enter Freeze. If a loop is active, MOVE enters Loop Slicer instead. Press MOVE again to exit. Hot Cue 1–4 play slices 1–4. Remix 1–4 play slices 5–8. In Freeze, turn MOVE to move the bank and hold Shift while turning it to resize the bank. In Loop Slicer, turning MOVE moves the loop. Holding a pad repeats its slice. Release the pad to return to the underlying loop. The blue and amber pulse still uses Hot Cue 4.

On a stopped deck, hold CUE to play from the floating cue. Release CUE to stop at the cue. Press PLAY during the hold to continue. On a playing deck, CUE stops and returns to the floating cue. A deck layer change or controller disconnect ends a hold. The app keeps the saved Sync choice.

The app requests the S4 inputs automatically while playback is idle. iPadOS can ask for microphone permission. With four channels, line 1–2 goes to the C mixer strip and line 3–4 goes to the D mixer strip. A loaded track takes over its strip. With six channels, the mono mic pair also goes to the master and recording. The rear hardware gain adjusts the input. R120 maps the front MIC VOL control. If iPadOS does not expose the required channels, the app keeps normal playback available. [NI manual, sections 5.2 and 6.8](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_s4_mk2_manual_english.pdf) · [NI input channel assignments](https://support.native-instruments.com/support/solutions/articles/69000879459-how-to-use-a-microphone-with-the-traktor-kontrol-s4)

Physical Lightning input exposure, control response and sustained A10X performance remain open.

Fifteen focused host tests passed across 17 cases. They cover MOVE and pad report edges, slice bounds and lighting, Cue park and continuation, four- and six-channel input routing, loaded-deck priority, and regression checks for Sync, waveform release, S2 mic and S3 input.

[Build 182](../testing/builds/182.json) installed on the A10X iPad. iPadOS accepted the launch request.

## R120 Front MIC VOL

MIC VOL controls the mono microphone contribution to master and recording. The first valid report sets the level. The mic starts muted until that report arrives. The renderer ramps later changes from mute to unity and the app clears the setting when the accessory disconnects. Both line pairs keep their own mixer levels.

NI's Controller Editor 2.2.4 factory map names the control `PotiMicVol` and assigns NHL analogue ID `0x20000004`. The assignment is in `KontrolS4MK2::Map::Map` at `0x100395c7b–0x100395cca` in the macOS Controller Editor binary. The adjacent Cue Mix assignment uses ID `0x20000003`. [NI factory installer](https://support.native-instruments.com/support/solutions/articles/69000879400-traktor-pro-legacy-installers-for-older-operating-systems)

In Traktor DJ 2.4.1 on iPad, the S4 decoder starts the analogue block at payload offset `0x1a` and reads consecutive little-endian 16-bit values in analogue index order. Analogue index 4 therefore uses zero-based payload offsets `0x22–0x23` in report `01`. The reader starts at `0x100a99454` and receives the block from `0x100a96d90`. The app uses its existing S4 pot normalisation. [NI manual, section 6.9](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_s4_mk2_manual_english.pdf)

Physical knob response and Lightning mic input exposure remain open.

Fourteen focused host tests passed. They cover the report byte positions, adjacent fields, first valid report, mute, gain ramps, recorded level and line isolation. Existing S2 and S3 capture checks also passed.

[Build 183](../testing/builds/183.json) installed on the A10X iPad. iPadOS accepted the launch request.

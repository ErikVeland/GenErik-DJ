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

Physical connection, calibration, audio, jog response and LED output remain open. TDJ Freeze and Loop Slicer pad modes, momentary transport Cue preview, and external mic and line input also remain open.

Eleven focused host tests passed. Five S4 Mk2 tests cover startup, calibration, layer switching, blue and amber feedback, and route selection. Existing S3 framing and Z1 routing tests also passed.

[Build 181](../testing/builds/181.json) installed on the A10X iPad. iPadOS accepted the launch request.

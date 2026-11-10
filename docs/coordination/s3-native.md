# S3 native iPad adapter

R113 adds automatic S3 controls and lights on the two playback decks. The wired audio profile selects main 1–2 and headphones 3–4. No app setup or MIDI Learn is required.

## Protocol evidence

The preserved Traktor DJ 2 2.4.1 package declares `com.native-instruments.protocol.kontrols3`. Its S3 accessory table starts at `0x102a7feb0`. Startup is at `0x100a96138`, input dispatch at `0x100a96148`, and light output at `0x100a96334`. See [reference provenance](z1-native-accessory.md).

| Message | Report ID | Payload bytes | App action |
| --- | --- | --- | --- |
| Buttons, encoders and jogs | `01` | 21 | Request when both streams open. Use the first report as a baseline. |
| Knobs and faders | `02` | 62 | Request after the first button report. Mark the session ready on receipt. |
| Buttons, pads and jog rings | `80` | 82 | Send when these lights change. |
| Level meters | `81` | 78 | Send when these lights change. |

The transport uses the same five-byte length header as the S2 Mk3. The TDJ2 iPad dispatcher uses the shared 10-bit jog counter and 22-bit timer at `0x100a99514`. The desktop [Mixxx S3 mapping](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-S3-hid-scripts.js) uses a different jog encoding. It documents the control and light offsets, 12-bit faders and colour palette. The inspected Mixxx script has SHA-256 `bb2a392513067fb4e423d2d73b839182e0b2605aca44b0986f93bb30863fc89a`. Read-only inspection logs are in `TestBuilds/r113/`.

## Controls and lights

| S3 control | App action |
| --- | --- |
| A/B transport and jogs | Play, Cue, Sync, Keylock, Flux, held reverse, JOG mode, scratch and rim bend. Shift plus Play or Cue stops and parks the deck. |
| Browse and pads | Scroll the track list and press to load. Shift plus press ejects a stopped deck. View expands the browser. Focus switches between categories and rows. Hold Star or Shift while turning to browse categories. Hot Cues and Samples each use the deck's eight pads. |
| Loop, Move and GRID | Set or resize a loop. Move jumps or shifts an active loop. Shift plus Move changes jump length. Hold Move for a roll. Hold GRID with mixer CUE enabled to hear the tick. Pause to edit the grid. |
| A/B mixer | Use the inner channel faders, trim, EQ and cue buttons. The crossfader, tempo, headphone blend and headphone level use pickup. Master level is hardware-controlled. Shift plus Master also adjusts software gain. |
| Mixer FX | The factory four buttons select Filter, Reverb, Delay and Flanger. The dedicated Filter button also selects Filter. Tap to assign both decks. Hold a selection and press the channel FX button to assign one deck. A channel FX button on its own toggles that channel. |

The [NI S3 manual](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/TRAKTOR_KONTROL_S3_MK1_Manual_English_0120.pdf) documents the two physical deck sections, mixer and ring. The app uses the jog rings for the blue beat pulse and amber track-end warning. Amber pulses every four beats from 30 seconds, then every beat from 10 seconds. The pads retain Hot Cue or Sample feedback. A/B channel meters have their own output report. The app keeps one unsent packet per report ID and completes partial writes in order.

R114 covers the Preview Player, EXT input and hardware master meter. C/D playback layers and outer mixer strips remain open. Physical S3 connection, audio, jog response and ring brightness remain unverified.

Twenty-eight focused controller and audio tests passed. [Build 178](../testing/builds/178.json) installed on the A10X iPad. iPadOS accepted launch.


## R114 Preview, EXT and master meter

| S3 control | App action |
| --- | --- |
| Hold Preview | Audition the selected playable track in the S3 headphones. Turn Browse on the same side to scrub by 1.25% per detent. Release Preview to stop. |
| EXT | Toggle external capture. Shift + EXT selects the mic or line input. The D trim and fader set the master level. D CUE monitors the input before the fader. |
| Master meter | Show the rendered left and right master levels in report `81`. Each channel has a separate clip hold. |

The [Mixxx S3 mapping](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-S3-hid-scripts.js) documents the Preview, EXT and D-strip control offsets and the stereo meter positions. The TDJ2 S3 accessory at `0x100a96254` confirms a 32-byte payload for report `F4`. It starts with `20 08` for mic and `20 00` for line. The app starts in mic mode. See the [NI S3 manual](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/TRAKTOR_KONTROL_S3_MK1_Manual_English_0120.pdf).

Preview reads ahead into a bounded stereo buffer. It feeds the headphones and stays out of the master mix and recording. The first EXT activation requires iPadOS microphone permission, an S3 input and output route, and paused decks. EXT feeds the master and recording mix, and D CUE feeds the headphones. Disconnect clears Preview and EXT.

The playback engine has two source slots. Independent C/D need two more transport and mixer channels with their own streamed-source ownership, Sync alignment, recording attribution and route recovery. The outer D controls in this increment operate EXT. C/D playback and four-deck A10X performance verification remain open.

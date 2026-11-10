# Traktor Kontrol S2 Mk2 on iPad

R121 follows build 183. The app opens the native accessory session automatically. It uses the existing audio profile when iPadOS selects the S2 Mk2. The master uses outputs 1–2. Headphones use outputs 3–4.

| Surface | App behavior |
| --- | --- |
| Decks A and B | Play, cue, Sync, Flux, jog touch, scratch, pitch bend and tempo. Shift+Play toggles Keylock. |
| Browse and Load | Browse opens the library. Turn to select a track. Shift+turn changes categories. Load selects the target deck. Shift+Load ejects. |
| Mixer | Faders, EQ, headphone cue, cue blend and crossfader. Gain/Filter turns the filter. Shift+turn adjusts gain, and Shift+press resets it. The hardware controls its master and headphone volumes. |
| Loops and pads | Loop In, Loop Out, Loop Size, beat jump and waveform zoom. The four pads per deck serve Hot Cues, Remix, Freeze or Loop Slicer. Move opens Freeze or Loop Slicer according to the loop state. |
| Grid | Shift+Sync opens or closes grid mode. Jog adjusts phase and pads select the downbeat. Move scans four beats at a time. The app's existing grid locks apply. |
| FX | Channel assignment, two unit enable buttons, effect slot buttons and their four knobs per unit. These use the app's effect slots. |
| Feedback | Deck, mixer and FX indicators. Pad 4 shows the blue beat pulse and amber track-end warning on each deck. It shows its normal cue, sample or slice colour between indications. |

## Mapping evidence

The preserved Traktor DJ 2.4.1 iPad app declares `com.native-instruments.traktordj.kontrols2mk2`. Its startup and input handlers at `0x100a9496c` and `0x100a9497c` request four 32-byte calibration blocks from `D0` through `D3`. The session then receives report `01` with 66 payload bytes. The jog reader at `0x100a99514` uses a 10-bit position and a 22-bit timer for each deck. The feedback writer at `0x100a94ce0` sends report `83` with 69 payload bytes.

The NI manual describes the iPad controls in chapter 5. The Mixxx mapping supplies the USB field assignments. On iPad, one native input report combines the jog, button, encoder and analogue fields. The RGB section begins at payload byte 37 in the native feedback report. [NI S2 Mk2 manual](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_s2_mk2_manual_english.pdf) · [Mixxx USB mapping](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-S2-MK2-hid-scripts.js)

## Verification

Twenty-two focused host tests passed at `2cbbc5d23`. They covered report startup, control fields, four-pad slicing, RGB feedback and the automatic route. They also checked the shared S4 Mk2 and Z1 paths.

The first build 184 attempt stopped at an iPad-only filter encoder compilation error. The corrected build passed signature and runtime checks. The app installed on the A10X iPad, and iPadOS accepted launch. [Build record](../testing/builds/184.json)

Physical S2 Mk2 connection, audio, platter feel and LED brightness remain open. The S2 Mk2 microphone path remains outside this increment. Browse uses the app's library categories and track list. It does not duplicate the Traktor DJ recommendation tree.


## R122 MIC ENGAGE

MIC ENGAGE toggles the rear microphone input. The mapping uses report `01`, payload byte `9` (zero-based), mask `0x08`. The Mixxx HID mapping calls this report offset `0x0A` and toggles on a press. The NI manual documents the front button and rear gain knob. The published USB descriptor lists the mono mic as input channel 1. [NI manual, section 11.2](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_s2_mk2_manual_english.pdf) · [Mixxx HID mapping](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-S2-MK2-hid-scripts.js) · [Published USB descriptor](https://github.com/mixxxdj/mixxx/wiki/Native-Instruments-Traktor-Kontrol-S2-Mk2#usb-descriptors)

The app opens only the matching wired input. It sends the mono signal to both master channels and leaves it out of the headphone cue. iPadOS can ask for microphone permission the first time. The rear gain knob sets the input level.

The first press waits for idle audio if the app needs to open the input. Press again to cancel a pending activation. Once the input is open, the switch can mute and unmute the microphone during playback. If the input route disappears, the app mutes the mic.

Thirteen focused host tests passed. Build 185 passed the local iOS signature and runtime checks. It was prepared for verification only. Physical S2 Mk2 input availability over the iPad connection remains unverified. [Build record](../testing/builds/185.json)

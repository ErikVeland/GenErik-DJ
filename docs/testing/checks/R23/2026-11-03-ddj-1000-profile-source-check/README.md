# R23 DDJ-1000 profile source check: 3 November 2026

Application base: `e6db00bfc51cdbc717bae734688f148921e3f46e`.

Changed source SHA-256:

- `Replica/Sources/TDJInterface/ControllerMIDIConnection.swift`: `a10d1fa729ae39a18e0b5df4b1c5118342b8240d2c4ef441e56349fed0fa0239`
- `Replica/Sources/TDJInterface/ControllerSettingsView.swift`: `8955b3dc3654867d5fcb11f05405b2db1740cde22dce443e6d2926d45e5885f0`

## Change

The opt-in input profile maps published DDJ-1000 messages for decks 1 and 2: transport, headphone cue, sync, four-beat loop, paired 14-bit tempo and mixer controls, Hot Cue pads, platter jog/touch and one momentary Shift layer. It also maps the published crossfader and master/headphone controls. Decks 3 and 4, shifted pad pages and other pad modes are not mapped.

The optional output profile maps play, sync, headphone-cue and Hot Cue lights. Hot Cue output uses one fixed colour. Feedback remains disabled until the user enables it.

Source: Pioneer DJ's [published DDJ-1000 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-1000/ddj-1000_midi_message_list_e1.pdf).

## Checks

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The controller connection and Settings view parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The request ledger and controller coverage passed. |
| Package tests | NOT RUN | No test command was requested. |
| iPad and controller check | NOT RUN | No device was accessed. |

## Remaining evidence

Verify endpoint access, control assignments, jog feel, Shift behaviour, pad mode, LED colours, feedback routing and audio on the supported DDJ-1000 and iPad setup. No hardware compatibility claim is made from source mappings alone.

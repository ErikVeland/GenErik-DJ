# R23 DDJ-FLX4 profile source check: 3 November 2026

Application source: `3044a3bf1cdc196cacb87cc7d911726a771869fe`.

Changed Swift source diff SHA-256 from `7c8f678`: `b034919cd53005c47bd4a2d944a664a76912bdc5e1c51ad4bd920a51ca39bbdb`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | `ControllerMIDIConnection.swift` and `ControllerSettingsView.swift` parsed. |
| `git diff --check` | PASS | No whitespace errors were reported for the source changes. |
| STE linter | PASS | The request ledger and controller research records passed the skill linter. |
| Type-check, app build and tests | NOT RUN | This pass kept to source checks. No iPad or simulator was accessed. |

The opt-in profile maps the official [DDJ-FLX4 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-flx4/ddj-flx4_midi_message_list_e1.pdf): deck play, cue return, headphone cue and sync; paired 14-bit trim, EQ, channel level, master, headphone mix, headphone level and crossfader; and eight Hot Cue pads per deck. The pads require Hot Cue mode. Applying the profile replaces mappings for the selected MIDI input only, after confirmation.

The profile does not map jog rotation, platter touch, FX controls, pad modes, light feedback or audio routing. Source parsing does not prove that iPadOS exposes the controller's MIDI endpoint or that its controls behave as expected on hardware.

## Next evidence

On the available DDJ-FLX4, confirm MIDI input access. Apply the profile, verify each mapped control, test all Hot Cue pads in Hot Cue mode, and check that mappings for other inputs remain unchanged. Record jog, touch, lights and audio as separate results.

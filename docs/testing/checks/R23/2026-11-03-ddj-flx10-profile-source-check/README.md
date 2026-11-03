# R23 DDJ-FLX10 profile source check: 3 November 2026

Application base commit: `94e2745`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The controller, Settings view and focused profile tests parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The request ledger, controller coverage and research records passed. |
| Focused package check | BLOCKED | `bash Replica/Scripts/check.sh --filter ControllerMIDIProfileTests` stopped before tests ran. Swift 6.3.3 crashed with `SmallVector unable to grow`; the compiler also reported `no such module 'Testing'`. The output and exit status are preserved here. |
| iPad and controller check | NOT RUN | The user asked for development without iPad access. No iPad or controller was accessed. |

The input and output profiles use Pioneer’s [published DDJ-FLX10 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-flx10/ddj-flx10_midi_message_list_e1.pdf). Input maps two-deck transport, mixer, tempo, loop, Beat Jump, Hot Cue, jog and touch messages. Output maps play, sync, headphone cue and Hot Cue lights. The Hot Cue lights use a fixed colour. Both profiles omit decks 3/4 and stem controls. Either physical Shift button selects the same momentary layer. Releasing one Shift button leaves the layer active while the other remains held.

The profile source assignments match the published table. Core MIDI endpoint access, jog calibration, pad-mode behaviour, feedback colour tuning and hardware acceptance remain open. The profile tests were added but did not execute.

## Files

- `source-sha256.txt` binds this check to the controller, Settings view and test source.
- `parse-status.txt`, `diff-check-status.txt` and `ste-lint-status.txt` record successful checks.
- `package-check-status.txt` and `package-check.log` preserve the blocked focused package check.

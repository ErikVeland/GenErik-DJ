# R23 MIDI soft takeover source check: 3 November 2026

Application base commit: `387c336`.

## Behaviour

Absolute continuous mappings wait until controller input reaches the current software value within 0.02 normalized units, or crosses it. They then keep control until the mapping or connection resets. Buttons, relative encoders and jog controls stay immediate. If the app has no current value for an action, input stays immediate.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The controller and focused profile test files parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The R23 ledger and controller research records passed. |
| Focused package check | BLOCKED | `bash Replica/Scripts/check.sh --filter ControllerMIDIProfileTests` stopped before tests ran. Swift 6.3.3 crashed with `SmallVector unable to grow`; the compiler also reported `no such module 'Testing'`. The output and exit status are preserved here. |
| iPad and controller check | NOT RUN | The user asked for development without iPad access. No iPad or controller was accessed. |

## Files

- `source-sha256.txt` binds this check to the controller and focused profile test source.
- `parse-status.txt`, `diff-check-status.txt` and `ste-lint-status.txt` record successful checks.
- `package-check-status.txt` and `package-check.log` preserve the blocked focused package check.

# R15 key-shift check attempt — 3 November 2026

Application source: `1de04c2529042d598cca353b27663bd3a128096d`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| `swiftc -frontend -parse` on the changed Swift files | PASS | Syntax parsing completed. This does not type-check or link the app. |
| `bash Scripts/check.sh --filter KeyShiftTests` with the selected Command Line Tools | BLOCKED | Swift crashed with `SmallVector unable to grow`, then could not import the `Testing` module. No tests ran. |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash Scripts/check.sh --filter KeyShiftTests` | BLOCKED | Xcode returned exit 69 because its licence has not been accepted. No tests ran. |

No test pass is claimed. The iPad signing configuration is also absent from this checkout. No signed build or device operation occurred for R15.

## Next evidence

After Erik accepts the Xcode licence and restores the local signing team/device configuration, run the focused tests and prepare the signed iPad candidate. Erik must then check pitch shift, same-mode matching and sound on real music.

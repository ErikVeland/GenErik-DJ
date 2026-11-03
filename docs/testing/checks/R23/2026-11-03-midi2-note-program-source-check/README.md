# R23 MIDI 2.0 bank and note source check: 3 November 2026

Application source: `c2174e415bd8fc5e7f2a519db1aaaa347adc4de0`.

Changed source diff SHA-256 from `164bcb3`: `0bcabc964e137f2edb187abacd83bdb9a9372cc0a278567dbb6141d66203f83c`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | Both changed Swift files parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The R23 request ledger and controller notes passed the skill linter. |
| Swift type-check | BLOCKED | Command Line Tools Swift 6.3.3 does not match the installed SDK's Swift 6.3.2. |
| Tests, signed iPad build and controller access | NOT RUN | No tests or build ran. No iPad or controller was accessed. |

MIDI 2.0 Program Change now retains its bank when the Bank Valid flag is set. MIDI 1.0 Note On with zero velocity remains a Note Off. MIDI 2.0 Note On with zero velocity remains a Note On and can trigger a learned button. MIDI 2.0 Note Off releases the button. The [MIDI 2.0 UMP specification](https://amei-music.github.io/midi2.0-docs/amei-pdf/M2-104-UM_v1-1-2_UMP_and_MIDI_2-0_Protocol_Specification.pdf) defines the bank flag and note velocity semantics.

## Next evidence

Use a matching Xcode SDK to type-check the app. Then verify bank-specific Program Change bindings and zero-velocity Note On behaviour with MIDI 2.0 sources. Confirm MIDI 1.0 note release still works. Erik owns physical controller and iPad acceptance.

# R23 DDJ-FLX4 Hot Cue feedback source check: 3 November 2026

Application source: `c368e07e76e8ac9c0f87c16db5b2a4f058ee0dd0`.

Changed Swift source diff SHA-256 from `4554846`: `d5448d34c2e207f2305580ea7e7fcd9e2c7d5bd844a81e763bf2ed036888818e`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The controller connection and Settings view files parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The request ledger and controller coverage records passed the skill linter. |
| Type-check and app build | BLOCKED | The active developer directory is Command Line Tools. `xcrun` cannot locate an iOS SDK. |
| Tests | NOT RUN | No tests were requested. |
| Controller and iPad check | PENDING | Erik owns the physical LED review. No device was accessed. |

The optional profile now maps play, sync, headphone-cue and all eight Hot Cue lights on both decks. Hot Cue lights reflect the saved cue slots for the loaded track. The profile sends Note On with velocity zero for off states, as shown in the official [DDJ-FLX4 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-flx4/ddj-flx4_midi_message_list_e1.pdf). It replaces only its listed mappings and stays disabled until the user enables feedback.

## Next evidence

On a DDJ-FLX4, confirm the deck channels, pad numbers, saved-slot states, note-on/off behaviour, and preservation of unrelated output mappings. Confirm that feedback remains off after loading the profile.

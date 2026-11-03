# R23 DDJ-FLX4 jog and touch source check: 3 November 2026

Application source: `231a3b4eac8961a9ebe20cadce394a1fd1a56301`.

Changed Swift source diff SHA-256 from `45ad0dc`: `086e65400bbd0ce0ba6bb26b4a10c00c2ec2747333164b2b48a83291fddec228`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The controller connection, Settings view and model files parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The request ledger and controller coverage records passed the skill linter. |
| Type-check, app build and tests | NOT RUN | The local Swift compiler and installed SDK versions do not match. No tests were requested. |
| Controller and iPad check | PENDING | Erik owns the physical jog and touch review. No device was accessed. |

The opt-in profile uses the official [DDJ-FLX4 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-flx4/ddj-flx4_midi_message_list_e1.pdf). It maps the vinyl-on platter encoder and touch note for both decks. Encoder movement changes the touch playback rate while touch is held. Rate is clamped to four times normal speed. Input loss releases the touch action.

## Next evidence

On a DDJ-FLX4, confirm platter direction, touch state, rate feel, release after disconnect and ordinary playback after release. Wheel-side and vinyl-off jog remain unmapped.

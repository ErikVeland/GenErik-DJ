# R23 DDJ-FLX4 platter vinyl-mode source check: 3 November 2026

Application base: `3ae9b39`.

Changed Swift source diff SHA-256: `bc3b0bc11df40742a946199976aabe526e90653b374db91e099de75e5455ca72`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The controller connection and Settings view parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| Profile source review | PASS | CC 34 and CC 35 use the same bounded binary-offset jog action for both decks. |
| Type-check, app build and tests | NOT RUN | The local Xcode licence and signing setup block an iPad build. No tests were requested. |
| Controller check | PENDING | Erik owns the physical jog review. No controller was accessed. |

The mapping follows the official [DDJ-FLX4 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-flx4/ddj-flx4_midi_message_list_e1.pdf). It defines CC 34 for vinyl-on platter movement and CC 35 for vinyl-off movement. Wheel-side jog remains unmapped.

## Next evidence

On a DDJ-FLX4, check platter direction and rate in both vinyl modes. Check touch release and normal playback after release.

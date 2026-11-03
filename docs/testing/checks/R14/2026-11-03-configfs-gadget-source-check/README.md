# R14 USB MIDI gadget source check — 3 November 2026

Application source: `d369c239a4ad829c3300d541ea286539ff61a3d8`.

Changed source: `tools/controller_bridge/configure_midi_gadget.py`.

SHA-256: `c7322554cf3e014141b027b4455c0d14c004ec019199e6aa2c71719781b419e3`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Python AST parse | PASS | The setup helper parsed without syntax errors. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The changed project records and bridge guide passed the skill linter. |
| Linux configfs, UDC enumeration and ALSA MIDI discovery | NOT RUN | This host is macOS. No bridge hardware was accessed. |
| App build, tests, iPad access and physical controller check | NOT RUN | This change only adds a Linux bridge setup helper. No iPad or controller was accessed. |

The helper creates one new configfs gadget only after `--apply`. It requires root, a mounted configfs MIDI function, a listed UDC, and USB IDs assigned to the bridge. The source check does not prove that a board exposes both USB host and device ports, that iPadOS enumerates the gadget, or that the relay carries controls and feedback correctly.

## Next evidence

On the intended Linux bridge, configure the gadget with assigned IDs. Confirm ALSA creates its MIDI node. Then connect the original Z1 and iPad, verify input, calibration and light feedback, and record audio routing separately. Erik owns physical acceptance.

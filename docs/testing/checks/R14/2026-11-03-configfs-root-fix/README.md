# R14 USB MIDI gadget configfs root fix: 3 November 2026

Base commit: `8db72e9`.

## Change

Linux creates `functions`, `configs` and `strings` inside each gadget directory. The setup helper now checks that the USB gadget configfs root exists instead of looking for those directories at the root. A simulated configfs test confirms the gadget is created only after `--apply`, with its function and configuration link inside the gadget. The [Linux gadget guide](https://docs.kernel.org/usb/gadget_configfs.html) describes this directory layout.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Controller bridge unit tests | PASS | All nine tests passed, including gadget setup and the Z1 relay framing checks. Output is in `unittest.log`. |
| Configfs simulation | PASS | The fixture used a temporary filesystem and mocked the kernel-created gadget directories. No system configfs or USB hardware was changed. |
| Whitespace check | PASS | `git diff --check` reported no errors. |
| Linux gadget and Z1 hardware | PENDING | No Linux bridge, Z1 or iPad was accessed. |

The initial test fixture lacked the configuration's kernel-created `strings` directory and failed. The fixture now models that configfs directory before rerunning the suite.

## Source identity

| File | SHA-256 |
| --- | --- |
| `tools/controller_bridge/configure_midi_gadget.py` | `253c3cde0beef6df75875d92a4ac82b60a534ac086d9472ae1d93536219e47d0` |
| `tools/controller_bridge/test_configure_midi_gadget.py` | `316380db87889115e0a56549cd3efff787f29eaa0da5ad5d512ff0d0f6315be7` |

## Remaining work

Run the helper on the intended Linux bridge with bridge-assigned USB IDs. Confirm the ALSA MIDI endpoint and original Z1 control and feedback path. Audio routing remains a separate check.

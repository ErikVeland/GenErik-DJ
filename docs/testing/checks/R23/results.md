# Controller checks — build 51

Application source: `a437cec2bc37506fa24c63e666e97ec53d570ed8`. Request R23 covers all NI and class-compliant MIDI controllers, with original Z1 first.

## Verified software increment

- Swift MIDI stream checks passed: fragmentation, running status, note release, system/clock handling, pitch bend, pressure and program events.
- Swift value checks passed: paired 14-bit CCs and three relative encodings, including incomplete pairs and direction.
- Swift bridge framing checks passed: packing, fragmentation, clock, checksum/length rejection and recovery.
- Python Z1 relay checks passed: seven cases covering codec/report validation, partial HID writes and late app attachment.
- Signed iPad build 51 completed in 31.89 seconds. Saved app version, source fingerprint, app hash and strict signature verification match its tracked build record.

The final build log has an existing iPad orientation warning. It has no compiler error diagnostics. No Mac application, simulator or full-suite run was used. The Swift checks compile only the small protocol sources.

## Hardware acceptance pending

Build 51 is prepared only. This chat did not install it or interrupt the installed test app. No physical Z1 bridge, MIDI Learn response, LED timing or controller audio has been accepted. The Linux relay needs a configured USB MIDI gadget. It does not forward audio.

Other models need verified profiles and, where applicable, native adapters. Generic Learn does not establish jog/touch, display, motor or audio support. See the [research register](../../../coordination/controller-research.md) and [controller test](../../controller-test.md).

Local logs: `TestBuilds/ipad/build-51.log`; focused pre-implementation failures under `/tmp/generik-controller-*-red.log` and `/tmp/generik-z1-bridge-python-red.log`. These are local evidence, not portable build artifacts.

## Earlier increment


Source: `430177c4ff036278c0c1d5dec0bad327391b1b74`.

The standalone Swift MIDI packet checks passed. They cover packet fragmentation, running status, note-off and zero-velocity release, interleaved MIDI clock, rejection of system data, pitch-bend endpoints, one-byte channel messages and separate input state. The initial empty decoder failed the note/release expectation before implementation. No Mac application or full package test suite was built for this check.

The first device compilation failed because a mutable MIDI packet pointer was assigned to an immutable pointer variable. That type error was corrected. A later prepared candidate added a per-tick input budget. Build 49 compiles/signs successfully, with clean application sources at the recorded commit. Its build record retains the output hash and 53.39-second build duration.

The original failed compile log is local at `TestBuilds/ipad/build-47-pointer-failure.log`. The focused red output is local at `/tmp/generik-controller-midi-red.log`. The candidate log is `TestBuilds/ipad/build-49.log`.

Build 49 is not installed. No actual Z1 MIDI endpoint, learned control, native accessory protocol, output feedback or bridge hardware has been accepted. Use `docs/testing/controller-test.md` for Erik’s next check. Models other than Z1 remain unowned/unverified hardware.

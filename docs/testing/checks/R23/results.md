# Controller input checks

Source: `430177c4ff036278c0c1d5dec0bad327391b1b74`.

The standalone Swift MIDI packet checks passed. They cover packet fragmentation, running status, note-off and zero-velocity release, interleaved MIDI clock, rejection of system data, pitch-bend endpoints, one-byte channel messages and separate input state. The initial empty decoder failed the note/release expectation before implementation. No Mac application or full package test suite was built for this check.

The first device compilation failed because a mutable MIDI packet pointer was assigned to an immutable pointer variable. That type error was corrected. A later prepared candidate added a per-tick input budget. Build 49 compiles/signs successfully, with clean application sources at the recorded commit. Its build record retains the output hash and 53.39-second build duration.

The original failed compile log is local at `TestBuilds/ipad/build-47-pointer-failure.log`. The focused red output is local at `/tmp/generik-controller-midi-red.log`. The candidate log is `TestBuilds/ipad/build-49.log`.

Build 49 is not installed. No actual Z1 MIDI endpoint, learned control, native accessory protocol, output feedback or bridge hardware has been accepted. Use `docs/testing/controller-test.md` for Erik’s next check. Models other than Z1 remain unowned/unverified hardware.

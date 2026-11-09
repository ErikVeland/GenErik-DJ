# R82: Original Z1 native iPad connection

Erik requires direct original Z1 control on the A10X iPad. The Mk1 does not expose MIDI to this iPad. R81's MIDI fallback did not meet this requirement. R82 uses External Accessory and the Z1's native protocol. It needs no MIDI Learn, computer relay or separate bridge.

## Reference and provenance

The preserved local package is **Traktor DJ 2, version 2.4.1, build 2.4.1.478**, bundle `com.native-instruments.tmnt`. It is not the original TDJ1 reference. Its Z1 accessory implementation supplies transport facts only. Existing GenErik DJ mapping retains TDJ1-style actions.

Local package: `/Users/veland/GenErik DJ Archive/2026-11-04/Source/Traktor DJ.app/Wrapper/Traktor DJ.app`.

| File | SHA-256 |
| --- | --- |
| `Info.plist` | `f8e53bd802955a4f90b91dd0040af29c8e2e72c3dd64ba224ec74ac17628cb95` |
| `Traktor DJ` executable | `abcaae97f4854164dea50010ed97a8bf3c6e371abbe5edea1600e6302d3fc39f` |

Inspection was read-only. The original app was not launched or modified. The independently written Swift code contains protocol facts, not copied application code. Private inspection evidence remains under ignored `TestBuilds/r82/`.

The plist declares `com.native-instruments.traktordj.kontrolz1`. The readable `NHL_EASessionController` metadata identifies an `EASession`, input/output streams and an accessory listener. The Z1-specific listener table at `0x102a80298` links the following operations:

| Operation | Reference address | Observed contract |
| --- | --- | --- |
| Startup | `0x100a97dd4` | Read firmware revision. Request D0 first. |
| Firmware parsing | `0x100a99bf0` | Parse three decimal components. The third component below 8 selects the legacy header. Unreadable revision defaults to the newer header. |
| Input framing | `0x100a97e5c`, `0x100a990dc` | Native prefix and report framing described below. |
| Report dispatch | `0x100a97f38` | D0, D1 and D2 each contain 32 bytes. Report 01 contains 29 bytes. |
| Calibration | `0x100a98108` | D2 bytes 28–31 contain the crossfader endpoint words. |
| Feedback | `0x100a98254` | Report 80 contains 21 light/meter values. |
| Read request | `0x100a9a994` | Prefix 33 C3. Report ID follows the selected header. |
| Output packet | `0x100a9aa10` | Prefix B3 C3. Report ID follows the selected header. |

## Wire format

All values below are hexadecimal bytes. Multi-byte integers are little-endian.

| Message | Firmware third component below 8 | Newer firmware |
| --- | --- | --- |
| Read D0 | `33 C3 D0` | `33 C3 00 01 00 D0` |
| Read D1 | `33 C3 D1` | `33 C3 00 01 00 D1` |
| Read D2 | `33 C3 D2` | `33 C3 00 01 00 D2` |
| Start input | `33 C3 01` | `33 C3 00 01 00 01` |
| Input report | `33 C3 01` + 29 bytes | `33 C3 00 1E 00 01` + 29 bytes |
| Calibration reply | `33 C3 Dx` + 32 bytes | `33 C3 00 21 00 Dx` + 32 bytes |
| Light output | `B3 C3 80` + 21 bytes | `B3 C3 00 16 00 80` + 21 bytes |

The newer length includes the report ID and payload. Startup advances only after the expected calibration reply. After D2, the app validates the crossfader endpoints and requests report 01. Input contains fourteen 12-bit control words followed by five button bits. This matches the payload consumed by the existing Z1 mapper.

D0 and D1 are read for the startup exchange. This increment uses D2's crossfader calibration. Other knobs retain the existing 12-bit scaling. Full native analogue calibration curves remain outside this increment.

## App behaviour

- Register the exact protocol in the iPad plist and enable external-accessory background support.
- Enable direct Z1 discovery by default when the playback monitor starts. Remember an explicit off choice.
- Match the exact advertised protocol. Open its `EASession` and both streams.
- Complete the calibration exchange before applying controls or sending light feedback.
- Use the existing mixer, cue, MODE-plus-cue transport and filter/FX actions. Do not enable MIDI input for this path.
- Keep one native connection. Native and bridge modes are mutually exclusive.
- Close streams and reset calibration on disconnect or failure. Reconnect after a new accessory connection event.
- Limit each input read to 1024 bytes. Preserve fragmented packets and separate combined packets.
- Reject malformed headers, unsupported legacy reports, invalid calibration and oversized input.
- Keep partial output packets intact. Keep only the latest pending light state and bound the command queue.
- Stop startup after five seconds without progress. Do not stop deck audio when the controller fails.

The main run loop owns the streams. There is no new polling timer. Existing playback snapshots supply light feedback at about 30 Hz. Physical measurements must establish the A10X cost under live playback.

## Verification and remaining work

Focused checks cover both wire formats, every two-part packet split, one-byte delivery, combined reports, startup order, crossfader calibration, held-button suppression, malformed packets and overload. All 13 focused host tests passed. Build 142 passed signed iPad compilation and installation. iPadOS accepted launch. Failed build 141 and the two earlier host compile failures remain preserved.

Hardware acceptance remains open: session access, the reported firmware format, real calibration, all physical controls, lights, master/headphone routing, disconnect/reconnect and uninterrupted A10X audio. No physical success follows from a host test or build. Use the [native test steps](../testing/controller-test.md).

Apple's [External Accessory guide](https://developer.apple.com/library/archive/featuredarticles/ExternalAccessoryPT/Introduction/Introduction.html) documents protocol registration and session streams. The native packet facts above come from the preserved local NI package, not from that generic guide.

## R83/R84: beat and end-warning lights

The original Z1's filter/FX ON button has separate amber and blue brightness outputs for each channel.
The existing report uses byte positions 17/20 for amber and 18/21 for blue, including the report ID.
NI calls the FX colour orange in the preserved original Z1 manual. User-facing notes call it amber.
Cue lights, meters, MODE feedback and all input actions retain their existing behaviour.

During normal playback, blue hits on each beat and fades more slowly as it approaches the next beat.
An active filter stays visibly lit between pulses. In FX mode, blue gives a small beat accent alongside the amber status.
At 30 seconds remaining, amber pulses every four beats, aligned to the deck's downbeat.
At 10 seconds remaining, amber pulses on every beat. Amber fades during the first half of each pulse cycle.
During the warning, the blue accent peaks at 24 of 127 and fades in the first fifth of the beat.
The active FX light keeps a dim amber floor.
The light overlay does not select, enable or disable the filter or any effect.

Each deck uses its own current playback beat position, including its adaptive grid.
Remaining time uses the active audio instance's full length and playback speed.
With adaptive Sync, the countdown uses the remaining beat distance at the current playback BPM.
Seeking changes the pulse position immediately. There is no elapsed-time oscillator or extra timer.
The existing feedback loop runs at about 30 Hz and retains only the latest pending native light state.

Loops keep the blue beat pulse and suppress amber end warnings.
Pausing, ending, scratching, braking or reverse playback restores the normal status lights.
Tracks without a valid beat grid retain normal status lights. Unknown audio length disables only the end warning.

Twenty-one focused host tests passed across 24 cases. They cover both thresholds, both pulse rates, downbeat offsets,
blue brightness, tempo changes, adaptive timing, seeks, loops, pause/end/manual transport, independent channels,
current audio length, native framing and unchanged control actions. Evidence is under `TestBuilds/r83-r84/`.
Physical colour, brightness, beat alignment and uninterrupted A10X playback remain Erik's checks.

Signed [build 144](../testing/builds/144.json) installed on the A10X iPad. iPadOS accepted launch.
No device actions followed. Erik performs the physical light and playback checks.

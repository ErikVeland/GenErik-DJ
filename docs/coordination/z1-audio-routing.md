# R97: Automatic original Z1 audio routing

Erik reported silent Z1 headphones on 9 November 2026. Build 155 is assumed from the recorded install history.
He requires TDJ-style automatic setup. A routing setting is not an acceptable prerequisite.

## Cause and reference

Native Z1 accessory control and audio output use separate connections. The native control path was automatic.
The audio path defaulted to stereo master, which omits the headphone bus.

NI documents [automatic Z1 audio setup in TDJ2](https://support.native-instruments.com/support/solutions/articles/69000879425-traktor-dj-2-ios-audio-interface-compatibility).
Its [original Z1 routing reference](https://support.native-instruments.com/support/solutions/articles/69000879502-how-to-use-the-traktor-kontrol-z1-as-a-midi-controller-and-audio-interface-with-ableton-live)
specifies main on 1–2 and cue on 3–4. The latter reference uses Ableton, but documents the same physical outputs.
The preserved local TDJ package is version 2.4.1, not TDJ1. These facts do not establish identical analogue response or latency.

## Behaviour

- Identify the original Z1 by its name on the active USB or line-output audio route.
- Select main 1–2 and headphones 3–4 before the output engine starts.
- Request four channels after session activation, then check the actual hardware format.
- Show automatic Z1 routing instead of a routing switch or picker.
- Restore this routing after reconnect. Preserve the existing output-recovery and Sync rules.
- Keep cue audio out of the main mix and set recording.
- Keep MAIN and headphone volume under their existing hardware controls.

Apple requires an active session before [requesting the output channel count](https://developer.apple.com/documentation/avfaudio/avaudiosession/setpreferredoutputnumberofchannels(_:)).
An unavailable four-channel Z1 route reports a failure rather than silently dropping the headphone bus.
An active Z1 disconnect preserves the deck state and requires Play before sending audio to another output.
Generic interfaces retain their manual routing choice. Accessory controls alone cannot claim a speaker or Bluetooth output.

## Verification

The regression test reproduced stereo-only startup before the fix. Nine focused host tests passed.
They cover automatic selection, manual-choice isolation, reconnect, interruption permission, deck position and Sync preservation,
sample continuity during repeated detection, and cue isolation from master and recording outputs.
Logs remain under `TestBuilds/r97/`, including the failing regression run.
Hardware listening, actual iPad port identification and A10X touch acceptance remain open.

Signed [build 160](../testing/builds/160.json) includes this change from `eedd347ed`.
The A10X accepted installation and launch. No device actions followed.

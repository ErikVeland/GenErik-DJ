# Original Z1 development bridge

This relay carries the original Z1's HID input, crossfader calibration and light/meter feedback over a USB MIDI connection. It uses the app's existing native Z1 mapping, including MODE combinations and touch/FX axis coexistence. It is not a generic firmware adapter for every NI controller.

The relay is implemented and has software framing/report checks. No physical Linux bridge, USB MIDI gadget or Z1 relay session has been tested. Direct iPad accessory communication remains separate.

## Required setup

- A Linux bridge with simultaneous USB host and USB device/gadget ports.
- The original Z1, USB vendor/product `17cc:1210`, connected to the bridge's host side.
- A configured USB MIDI gadget facing the iPad.
- Access to the Z1 HID character device and the gadget's ALSA raw MIDI character device.

The relay does not configure the gadget, install drivers or change host services. The kernel documents the MIDI gadget function in its [gadget testing guide](https://www.kernel.org/doc/html/latest/usb/gadget-testing.html) and [configfs MIDI interface](https://github.com/torvalds/linux/blob/master/Documentation/ABI/testing/configfs-usb-gadget-midi). Use a board whose host/device ports can operate together.

## Audio boundary

**This relay does not forward audio.** When the Z1's USB connection terminates at the bridge, its audio interface is on the bridge side. Do not assume the iPad can also use it directly. A composite audio bridge needs separate implementation, clock/latency work and hardware testing. Alternatively, use an independently supported iPad audio route.

Z1 Main and Cue Vol are hardware audio controls. They do not emit HID controls and cannot be made into app parameters by inventing MIDI messages. Their audible effect depends on routing audio through the Z1. See [Mixxx's maintained Z1 description](https://manual.mixxx.org/2.7/en/hardware/controllers/native_instruments_traktor_kontrol_z1.html).

## Run the relay

Inspect the board's actual device nodes first. The following paths are examples, not discovered hardware:

```sh
python3 tools/controller_bridge/z1_bridge.py --hidraw /dev/hidraw0 --midi /dev/snd/midiC1D0
```

The relay verifies the original Z1's USB identity. It forwards only valid 30-byte input reports and valid 22-byte light reports. Invalid or unknown reports do not reach the controller. Failed or partial light writes stop the relay. Slow output stops the relay instead of accumulating stale controls.

If crossfader feature calibration is unavailable, the app keeps crossfader input disabled. The relay does not substitute an assumed range. Restart the relay after a Z1 disconnection.

## Connect the app

1. Open **Settings → Controllers** in the matching bridge-capable app build.
2. Enable controller input.
3. Select the bridge's MIDI input.
4. Enable **Original Z1 through GenErik bridge**.
5. Select the bridge's feedback output.
6. Check that the app reports valid Z1 calibration and input.

The app requests state/calibration when it connects. The relay resends its latest input for a late app connection. Normal MIDI Learn is separate from this mode. Choose the generic path for ordinary MIDI controllers.

## Wire format

The private development SysEx prefix is `F0 7D 47 44 4A 01`. It is followed by report kind, raw payload length, seven-bit-packed payload, a seven-bit checksum and `F7`. Each group contains a high-bit mask and up to seven low bytes. The checksum is `(kind + raw length + sum(raw bytes)) & 0x7F`.

| Kind | Raw size | Direction | Meaning |
| --- | ---: | --- | --- |
| 1 | 30 | Bridge → app | Original Z1 input report, including report ID 1. |
| 2 | 22 | App → bridge | Original Z1 light report, including report ID 0x80. |
| 3 | 32 | Bridge → app | Feature D2 payload, without its report ID. |
| 4 | 1 | Both | 0 disconnected, 1 connected, 2 calibration unavailable, 3 app state request. |

The parser bounds frames, handles fragmented packets and interleaved MIDI clock, checks lengths/checksum and ignores other manufacturers or unknown versions. This framing is our private bridge protocol, not an NI protocol or a Serato compatibility handshake.

Protocol references: [maintained Z1 implementation](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-Z1-scripts.js), [Z1 report notes](https://github.com/mixxxdj/mixxx/wiki/Native-Instruments-Traktor-Kontrol-Z1/c5c948a256d9da65cecc5591bf3fda4fedab48b2), [Linux hidraw documentation](https://www.kernel.org/doc/html/latest/hid/hidraw.html).

## Software checks

```sh
python3 -m unittest discover -s tools/controller_bridge -p 'test_*.py'
```

The companion Swift checks are `Replica/Scripts/check-controller-bridge.swift`, `check-controller-midi.swift` and `check-controller-values.swift`. These checks do not establish hardware compatibility, latency, sound or gig acceptance.

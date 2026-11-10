# Original Z1 development bridge

This relay carries the original Z1's HID input, crossfader calibration and light/meter feedback over a USB MIDI connection. It uses the app's existing native Z1 mapping, including MODE combinations and touch/FX axis coexistence. It is not a generic firmware adapter for every NI controller.

The relay and an opt-in USB MIDI gadget setup helper are implemented. No physical Linux bridge, USB MIDI gadget or Z1 relay session has been tested. Direct iPad accessory communication remains separate.

## Required setup

- A Linux bridge with simultaneous USB host and USB device/gadget ports.
- The original Z1, USB vendor/product `17cc:1210`, connected to the bridge's host side.
- A USB device controller that can expose a USB MIDI gadget to the iPad.
- Access to the Z1 HID character device and the gadget's ALSA raw MIDI character device.

The helper creates one new MIDI gadget under configfs. It refuses an existing gadget path and does not change host services. You must provide USB IDs assigned to your bridge. It does not choose or claim vendor IDs. The kernel documents [gadget configfs](https://www.kernel.org/doc/html/latest/usb/gadget_configfs.html) and the [MIDI function attributes](https://github.com/torvalds/linux/blob/master/Documentation/ABI/testing/configfs-usb-gadget-midi). Use a board whose host/device ports can operate together.

## Audio boundary

**This relay does not forward audio.** When the Z1's USB connection terminates at the bridge, its audio interface is on the bridge side. Do not assume the iPad can also use it directly. A composite audio bridge needs separate implementation, clock/latency work and hardware testing. Alternatively, use an independently supported iPad audio route.

Z1 Main and Cue Vol are hardware audio controls. They do not emit HID controls and cannot be made into app parameters by inventing MIDI messages. Their audible effect depends on routing audio through the Z1. See [Mixxx's maintained Z1 description](https://manual.mixxx.org/2.7/en/hardware/controllers/native_instruments_traktor_kontrol_z1.html).

## Configure the USB MIDI gadget

Run the helper on the Linux bridge. It needs root access, mounted configfs, the MIDI gadget function and a USB device controller. Supply USB IDs assigned to your bridge and a unique serial number.

```sh
sudo python3 tools/controller_bridge/configure_midi_gadget.py \
  --vendor-id 0x1234 --product-id 0x0001 \
  --manufacturer 'Assigned bridge manufacturer' \
  --serial 'Unique bridge serial' --udc '<device-controller-name>' --apply
```

Replace every example identity value before you run the command. The helper refuses to reuse an existing gadget name. To stop it, unbind the gadget by writing an empty value to its `UDC` file. Remove only its own configfs links and directories after unbinding. The helper does not configure boot-time startup.

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

## S4 Mk3 audio and control bridge

The S4 Mk3 stays in native HID mode. A Linux host reads its control reports and sends its LED reports. The bridge presents USB MIDI and four-channel USB Audio to the iPad. GenErik DJ detects the bridge automatically, with no MIDI Learn or app settings.

### Recommended board

Choose a **Raspberry Pi 4 Model B, 2 GB**. Its USB-A ports use a separate host controller for the S4 Mk3. Its USB-C port can act as the gadget port to the iPad. This is the board to start with for hardware verification. The full S4 Mk3 setup remains untested. [Raspberry Pi 4 specifications](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/) · [Raspberry Pi USB hardware](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#usb) · [Buy in Australia](https://core-electronics.com.au/raspberry-pi-4-model-b-2gb.html)

Use Raspberry Pi OS Lite on a microSD card. Follow Raspberry Pi's peripheral-mode instructions for the USB-C port. Use `dtoverlay=dwc2,dr_mode=peripheral` and let the GenErik script create the gadget. Use a powered USB hub between the iPad host adapter and the Pi to supply the Pi with power. Raspberry Pi documents its USB 3 Hub for this arrangement. Connect the separately powered S4 Mk3 to a Pi USB-A port. [Raspberry Pi OTG guide](https://pip-assets.raspberrypi.com/categories/685-app-notes-guides-whitepapers/documents/RP-009276-WP-1-Using%20OTG%20mode%20on%20Raspberry%20Pi%20SBCs) · [Raspberry Pi powered hub guidance](https://www.raspberrypi.com/news/usb-gadget-mode-in-raspberry-pi-os-ssh-over-usb/)

### Configure the bridge

Use a Linux board that can run a USB host and a high-speed USB device controller at the same time. The board needs the configfs MIDI and UAC2 gadget functions, ALSA USB audio support and `alsaloop` with libsamplerate support. Power the S4 Mk3 from its own supply.

1. Connect the S4 Mk3 to the bridge's host port.
2. Create the S4 Mk3 gadget with the bridge's assigned USB vendor and product IDs.
3. Connect the gadget port to the iPad through its USB host adapter.
4. Identify the S4 Mk3 HID interface 03, the gadget's raw MIDI node and its ALSA capture PCM.
5. Run the relay with those nodes. The relay finds the playback PCM on the same USB device as the S4 Mk3 HID interface.

```sh
sudo python3 tools/controller_bridge/configure_midi_gadget.py \
  --s4-mk3 --vendor-id 0x1234 --product-id 0x0001 \
  --manufacturer 'Assigned bridge manufacturer' --serial 'Unique bridge serial' \
  --udc '<device-controller-name>' --apply

python3 tools/controller_bridge/s4_mk3_bridge.py \
  --hidraw /dev/hidrawN --midi /dev/snd/midiCND0 \
  --audio-in hw:CARD=UAC2Gadget,DEV=0
```

Replace the example IDs, serial, device controller and node names. Use `arecord -l` to find the gadget's capture card. Use a user with access to the HID and ALSA character devices. On kernels with the UAC2 function-name attribute, the gadget uses the same name for both USB functions. The app expects the product name `GenErik S4 Mk3 Bridge`.

The audio relay forwards channels 1–2 to master and 3–4 to headphones. It resamples for clock drift at 48 kHz with a 20 ms requested latency. The app drives the jog rings from its beat and track-end state. The bridge accepts panel and ring lighting reports. Motors, displays and external capture are outside this implementation.

If the relay exits, restart it with the current device nodes. Check that the Controllers page shows the bridge as connected. Keep the master and headphones separate during the first listening test. Physical enumeration, channel order, latency, drift and recovery still need hardware verification. [Linux UAC2 gadget](https://docs.kernel.org/usb/gadget-testing.html#uac2-function) · [ALSA loopback options](https://github.com/alsa-project/alsa-utils/blob/master/alsaloop/alsaloop.1) · [Mixxx S4 Mk3 reports](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-S4-MK3.js)

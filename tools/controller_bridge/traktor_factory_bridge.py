#!/usr/bin/env python3
"""Relay factory Traktor reports through a GenErik USB MIDI gadget."""
import argparse
from contextlib import ExitStack
import fcntl
import os
from pathlib import Path
import select
import stat
import subprocess
import sys
import time
from typing import NamedTuple

from s4_mk3_bridge import audio_command, playback_pcm
from traktor_factory_screens import PANELS, ScreenWorker
from z1_bridge import Decoder, encode, write_all

STATUS, INPUT, LIGHTS, SCREEN = 11, 16, 17, 18
CHUNK = 100
LENGTHS = {STATUS: 1, INPUT: CHUNK + 3, LIGHTS: CHUNK + 3, SCREEN: 64}


class Model(NamedTuple):
    name: str
    product: int
    interface: int | None
    inputs: dict
    lights: tuple
    audio: bool = False
    startup: bytes = b''

    @property
    def gadget(self):
        return f'GenErik {self.name} Bridge'


MODELS = {
    'x1-mk1': Model('X1 Mk1', 0x2305, None, {1: (24,)}, (33,)),
    'x1-mk2': Model('X1 Mk2', 0x1220, 0, {1: (31, 32)}, (52, 91)),
    'f1': Model('F1', 0x1120, 0, {1: (22,)}, (81,)),
    'd2': Model('D2', 0x1400, 0, {1: (17, 64), 2: (25, 64)}, (123,)),
    'z2': Model('Z2', 0x1130, 4, {1: (9, 64), 2: (53, 64)}, (95, 41), True, b'\xf1\x93\x40'),
    's5': Model('S5', 0x1420, 3, {1: (30, 64), 2: (79, 128)}, (105, 105, 74), True),
    's8': Model('S8', 0x1370, 5, {1: (41, 64), 2: (109, 128)}, (119, 119, 74), True),
    'mx2': Model('MX2', 0x2420, 3, {1: (15, 79, 80), 2: (53, 117, 118), 3: (20, 84, 85)}, (106,), True),
}


def fragments(kind, report):
    for offset in range(0, len(report), CHUNK):
        yield encode(kind, bytes((report[0], len(report), offset)) +
                     report[offset:offset + CHUNK].ljust(CHUNK, b'\0'), LENGTHS)


class LightReports:
    def __init__(self, model):
        self.sizes = dict(enumerate(model.lights, 0x80))
        self.pending = bytearray()

    def append(self, payload):
        report_id, size, offset = payload[:3]
        if offset == 0:
            self.pending.clear()
        if (size != self.sizes.get(report_id) or offset >= size or offset != len(self.pending)
                or (self.pending and self.pending[0] != report_id)
                or (offset == 0 and payload[3] != report_id)):
            self.pending.clear()
            return None
        self.pending.extend(payload[3:3 + min(CHUNK, size - offset)])
        if len(self.pending) == size:
            report = bytes(self.pending)
            self.pending.clear()
            return report
        return None


class HID:
    def __init__(self, model, path, sysfs=Path('/sys')):
        def matches(candidate):
            device = (sysfs / 'class/hidraw' / candidate.name / 'device').resolve(strict=True)
            identity = f'HID_ID=0003:000017CC:{model.product:08X}'
            interface = device.parent
            if identity in (device / 'uevent').read_text().splitlines() and (
                    model.interface is None or int((interface / 'bInterfaceNumber').read_text(), 16) == model.interface):
                return interface.parent
            return None

        candidates = [path.resolve(strict=True)] if path else sorted(Path('/dev').glob('hidraw*'))
        choices = [(candidate, parent) for candidate in candidates if (parent := matches(candidate))]
        if len(choices) != 1:
            raise ValueError(f'Connect one {model.name} or select its control node with --hidraw.')
        path, self.usb_parent = choices[0]
        if not stat.S_ISCHR(path.stat().st_mode):
            raise ValueError('Select a HID character device.')
        self.fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)

    def close(self):
        os.close(self.fd)

    def initial(self, report_id, size):
        report = bytearray(size)
        report[0] = report_id
        request = (3 << 30) | (size << 16) | (ord('H') << 8) | 0x0a
        try:
            count = fcntl.ioctl(self.fd, request, report, True)
        except OSError:
            return None
        return bytes(report[:count]) if count and report[0] == report_id else None

    def feature(self, report):
        request = (3 << 30) | (len(report) << 16) | (ord('H') << 8) | 0x06
        try:
            if fcntl.ioctl(self.fd, request, bytearray(report), True) == len(report):
                return
        except OSError:
            pass
        self.write(report)

    def read(self):
        try:
            report = os.read(self.fd, 256)
        except BlockingIOError:
            return None
        if not report:
            raise OSError('The controller disconnected.')
        return report

    def write(self, report):
        if not select.select([], [self.fd], [], 0.05)[1] or os.write(self.fd, report) != len(report):
            raise OSError('The controller did not accept a complete light report.')


class X1MK1USB:
    def __init__(self, model):
        import usb.core
        import usb.util

        self.usb = usb
        devices = list(usb.core.find(find_all=True, idVendor=0x17cc, idProduct=model.product))
        if len(devices) != 1:
            raise ValueError('Connect one original X1.')
        self.device = devices[0]
        try:
            config = self.device.get_active_configuration()
        except usb.core.USBError:
            self.device.set_configuration()
            config = self.device.get_active_configuration()
        interfaces = [interface for interface in config if {0x01, 0x81, 0x84}
                      <= {endpoint.bEndpointAddress for endpoint in interface}]
        if len(interfaces) != 1:
            raise ValueError('The X1 USB control endpoints were not found.')
        interface = interfaces[0]
        self.number = interface.bInterfaceNumber
        self.detached = self.device.is_kernel_driver_active(self.number)
        if self.detached:
            self.device.detach_kernel_driver(self.number)
        try:
            usb.util.claim_interface(self.device, self.number)
            self.device.set_interface_altsetting(self.number, interface.bAlternateSetting)
            self.write(bytes([0x80]) + bytes(32))
        except BaseException:
            self.close()
            raise
        self.fd = None

    def close(self):
        self.usb.util.dispose_resources(self.device)
        if self.detached:
            try:
                self.device.attach_kernel_driver(self.number)
            except self.usb.core.USBError:
                pass

    def initial(self, report_id, size):
        return None

    def read(self):
        try:
            report = bytes(self.device.read(0x84, 24, timeout=8))
        except self.usb.core.USBTimeoutError:
            return None
        return b'\x01' + report[1:] if len(report) == 24 else None

    def write(self, report):
        packet = b'\x0c' + report[2:]
        if self.device.write(0x01, packet, timeout=50) != len(packet):
            raise OSError('The X1 did not accept the complete light report.')
        try:
            self.device.read(0x81, 1, timeout=50)
        except self.usb.core.USBTimeoutError:
            pass


def relay(model, device, midi, audio, screens=None):
    latest = {}
    sent_lights = {}
    lights = LightReports(model)
    decoder = Decoder(LENGTHS)
    heartbeat = None

    def accept(report):
        if not report or len(report) not in model.inputs.get(report[0], ()) or latest.get(report[0]) == report:
            return
        if model == MODELS['mx2'] and report[0] == 3:
            # The report clock changes even when both platters are still.
            report = b'\x03' + bytes(7) + report[8:12] + bytes(4) + report[16:20]
            if latest.get(3) == report:
                return
        latest[report[0]] = report
        if heartbeat is not None:
            for frame in fragments(INPUT, report):
                write_all(midi, frame)

    if model.startup:
        device.feature(model.startup)
    for report_id, sizes in model.inputs.items():
        accept(device.initial(report_id, max(sizes)))

    while audio is None or audio.poll() is None:
        fds = [midi] if device.fd is None else [midi, device.fd]
        ready = select.select(fds, [], [], 0 if device.fd is None else 0.05)[0]
        if device.fd is None or device.fd in ready:
            accept(device.read())
        if midi in ready:
            try:
                data = os.read(midi, 4096)
            except BlockingIOError:
                continue
            if not data:
                return
            for kind, payload in decoder.append(data):
                if kind == STATUS and payload == b'\x03':
                    write_all(midi, encode(STATUS, b'\x01', LENGTHS))
                    heartbeat = time.monotonic()
                    lights.pending.clear()
                    sent_lights.clear()
                    for report in latest.values():
                        for frame in fragments(INPUT, report):
                            write_all(midi, frame)
                if heartbeat is not None and kind == SCREEN and screens is not None:
                    screens.submit(payload)
                if heartbeat is not None and kind == LIGHTS:
                    report = lights.append(payload)
                    if report and sent_lights.get(report[0]) != report:
                        device.write(report)
                        sent_lights[report[0]] = report
        if heartbeat is not None and time.monotonic() - heartbeat >= 0.5:
            write_all(midi, encode(STATUS, b'\x01', LENGTHS))
            heartbeat = time.monotonic()
    raise RuntimeError(f'The controller audio relay exited with status {audio.returncode}.')


def stop_audio(audio):
    if audio.poll() is None:
        audio.terminate()
        try:
            audio.wait(timeout=2)
        except subprocess.TimeoutExpired:
            audio.kill()
            audio.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('model', choices=MODELS)
    parser.add_argument('--hidraw', type=Path)
    parser.add_argument('--midi', type=Path, required=True)
    parser.add_argument('--audio-in', default='hw:CARD=UAC2Gadget,DEV=0')
    args = parser.parse_args()
    if not sys.platform.startswith('linux'):
        parser.error('Run the relay on Linux bridge hardware.')
    if not stat.S_ISCHR(args.midi.stat().st_mode):
        parser.error('Select an ALSA raw MIDI character device.')
    model = MODELS[args.model]
    with ExitStack() as stack:
        device = X1MK1USB(model) if args.model == 'x1-mk1' else HID(model, args.hidraw)
        stack.callback(device.close)
        midi = os.open(args.midi, os.O_RDWR | os.O_NONBLOCK)
        stack.callback(os.close, midi)
        audio = subprocess.Popen(audio_command(args.audio_in, playback_pcm(device.usb_parent))) if model.audio else None
        if audio is not None:
            stack.callback(stop_audio, audio)
        screens = None
        if args.model in PANELS:
            try:
                screens = ScreenWorker(args.model, device.usb_parent)
                stack.callback(screens.close)
            except (OSError, ValueError) as error:
                print(f'{model.name} screens could not start. {error}', file=sys.stderr)
        try:
            relay(model, device, midi, audio, screens)
        finally:
            try:
                write_all(midi, encode(STATUS, b'\x00', LENGTHS))
            except (OSError, TimeoutError):
                pass


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except (OSError, RuntimeError, ValueError, ImportError, TimeoutError) as error:
        sys.exit(str(error))

#!/usr/bin/env python3
"""Relay Z1 Mk2 or X1 Mk3 native reports through a GenErik USB MIDI gadget."""
import argparse
import fcntl
import os
from pathlib import Path
import select
import stat
import subprocess
import sys
import time
from contextlib import nullcontext
from typing import NamedTuple

from s4_mk3_bridge import audio_command, playback_pcm
from z1_bridge import Decoder, encode, write_all

INPUT, LIGHTS, STATUS = 9, 10, 11
LENGTHS = {INPUT: 36, LIGHTS: 51, STATUS: 1}


class Model(NamedTuple):
    product: int
    input_size: int
    light_size: int
    audio: bool


Z1_MK2 = Model(0x2400, 35, 47, True)
X1_MK3 = Model(0x2200, 25, 50, False)
MODELS = {"z1-mk2": Z1_MK2, "x1-mk3": X1_MK3}


def input_frame(model, report):
    if len(report) != model.input_size or report[0] != 1:
        return None
    return encode(INPUT, bytes([len(report)]) + report.ljust(35, b'\0'), LENGTHS)


def feedback(model, payload):
    if len(payload) != LENGTHS[LIGHTS] or payload[0] != model.light_size or payload[1] != 0x80:
        return None
    report = payload[1:1 + model.light_size]
    return report if all(value <= 0x7e for value in report[1:]) else None


def controller_usb_parent(model, hid_path, sysfs=Path('/sys')):
    device = (sysfs / 'class/hidraw' / hid_path.name / 'device').resolve(strict=True)
    identity = f'HID_ID=0003:000017CC:{model.product:08X}'
    if identity not in (device / 'uevent').read_text().splitlines():
        raise ValueError(f'Select the HID device with USB ID 17cc:{model.product:04x}.')
    return device.parent.parent


def initial_input(model, hid):
    report = bytearray([1] + [0] * (model.input_size - 1))
    request = (3 << 30) | (len(report) << 16) | (ord('H') << 8) | 0x0a
    try:
        count = fcntl.ioctl(hid, request, report, True)
    except OSError:
        return None
    return input_frame(model, bytes(report[:count]))


def relay(model, hid, midi, audio):
    latest = initial_input(model, hid)
    decoder = Decoder(LENGTHS)
    heartbeat = None
    last_lights = None
    while audio is None or audio.poll() is None:
        for fd in select.select([hid, midi], [], [], 0.05)[0]:
            try:
                data = os.read(fd, model.input_size + 1 if fd == hid else 4096)
            except BlockingIOError:
                continue
            if not data:
                return
            if fd == hid:
                frame = input_frame(model, data)
                if frame is not None and frame != latest:
                    latest = frame
                    if heartbeat is not None:
                        write_all(midi, frame)
            else:
                for kind, payload in decoder.append(data):
                    if kind == STATUS and payload == b'\x03':
                        write_all(midi, encode(STATUS, b'\x01', LENGTHS))
                        heartbeat = time.monotonic()
                        last_lights = None
                        if latest is not None:
                            write_all(midi, latest)
                    if heartbeat is not None and kind == LIGHTS:
                        report = feedback(model, payload)
                        if report is not None and report != last_lights:
                            if not select.select([], [hid], [], 0.05)[1] or os.write(hid, report) != len(report):
                                raise OSError('The controller did not accept a complete light report.')
                            last_lights = report
        if heartbeat is not None and time.monotonic() - heartbeat >= 0.5:
            write_all(midi, encode(STATUS, b'\x01', LENGTHS))
            heartbeat = time.monotonic()
    raise RuntimeError(f'The Z1 Mk2 audio relay stopped with exit status {audio.returncode}.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('model', choices=MODELS)
    parser.add_argument('--hidraw', required=True, type=Path)
    parser.add_argument('--midi', required=True, type=Path)
    parser.add_argument('--audio-in', default='hw:CARD=UAC2Gadget,DEV=0', help='Z1 Mk2 USB audio gadget capture PCM')
    args = parser.parse_args()
    if not sys.platform.startswith('linux'):
        parser.error('Run the relay on Linux bridge hardware.')
    model = MODELS[args.model]
    hid_path = args.hidraw.resolve(strict=True)
    usb_parent = controller_usb_parent(model, hid_path)
    if not all(stat.S_ISCHR(path.stat().st_mode) for path in (hid_path, args.midi)):
        parser.error('Both paths must identify character devices.')
    command = audio_command(args.audio_in, playback_pcm(usb_parent)) if model.audio else None
    hid = os.open(hid_path, os.O_RDWR | os.O_NONBLOCK)
    try:
        midi = os.open(args.midi, os.O_RDWR | os.O_NONBLOCK)
        try:
            with subprocess.Popen(command) if command else nullcontext() as audio:
                try:
                    relay(model, hid, midi, audio)
                finally:
                    if audio is not None and audio.poll() is None:
                        audio.terminate()
                        try:
                            audio.wait(timeout=2)
                        except subprocess.TimeoutExpired:
                            audio.kill()
        finally:
            try:
                write_all(midi, encode(STATUS, b'\x00', LENGTHS))
            except (OSError, TimeoutError):
                pass
            os.close(midi)
    finally:
        os.close(hid)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except (OSError, RuntimeError, ValueError, TimeoutError) as error:
        sys.exit(str(error))

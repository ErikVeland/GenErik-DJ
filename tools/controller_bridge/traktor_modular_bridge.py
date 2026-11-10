#!/usr/bin/env python3
"""Relay Traktor native reports through a GenErik USB MIDI gadget."""
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
S2_MK1_INPUT, S2_MK1_LIGHTS = 12, 13
LENGTHS = {INPUT: 36, LIGHTS: 51, STATUS: 1, S2_MK1_INPUT: 53, S2_MK1_LIGHTS: 62}
S2_MK1_CALIBRATION = range(0xd0, 0xd5)


class Model(NamedTuple):
    product: int
    input_size: int
    light_size: int
    audio: bool
    analog_size: int = 0


Z1_MK2 = Model(0x2400, 35, 47, True)
X1_MK3 = Model(0x2200, 25, 50, False)
S2_MK1 = Model(0x1101, 16, 62, True, analog_size=52)
MODELS = {"z1-mk2": Z1_MK2, "x1-mk3": X1_MK3, "s2-mk1": S2_MK1}


def input_frame(model, report):
    if model == S2_MK1:
        if not report:
            return None
        sizes = {1: model.input_size, 2: model.analog_size}
        size = 33 if report[0] in S2_MK1_CALIBRATION else sizes.get(report[0])
        if len(report) != size:
            return None
        return encode(S2_MK1_INPUT, bytes([len(report)]) + report.ljust(52, b'\0'), LENGTHS)
    if len(report) != model.input_size or report[0] != 1:
        return None
    return encode(INPUT, bytes([len(report)]) + report.ljust(35, b'\0'), LENGTHS)


def feedback(model, payload):
    if model == S2_MK1:
        if len(payload) == model.light_size and payload[0] == 0x80 and all(value <= 0x1f for value in payload[1:]):
            return payload
        return None
    if len(payload) != LENGTHS[LIGHTS] or payload[0] != model.light_size or payload[1] != 0x80:
        return None
    report = payload[1:1 + model.light_size]
    return report if all(value <= 0x7e for value in report[1:]) else None


def controller_usb_parent(model, hid_path, sysfs=Path('/sys')):
    device = (sysfs / 'class/hidraw' / hid_path.name / 'device').resolve(strict=True)
    identity = f'HID_ID=0003:000017CC:{model.product:08X}'
    if identity not in (device / 'uevent').read_text().splitlines():
        raise ValueError(f'Select the HID device with USB ID 17cc:{model.product:04x}.')
    interface = device.parent
    if model == S2_MK1 and (interface / 'bInterfaceNumber').read_text().strip() != '03':
        raise ValueError('Select the S2 Mk1 HID control interface 03.')
    return interface.parent


def initial_input(model, hid, report_id, size, feature=False):
    report = bytearray([report_id] + [0] * (size - 1))
    request = (3 << 30) | (size << 16) | (ord('H') << 8) | (0x07 if feature else 0x0a)
    try:
        count = fcntl.ioctl(hid, request, report, True)
    except OSError:
        return None
    return input_frame(model, bytes(report[:count])) if count and report[0] == report_id else None


def relay(model, hid, midi, audio):
    latest = {}
    calibration = []
    light_kind = LIGHTS
    first = initial_input(model, hid, 1, model.input_size)
    if first is not None:
        latest[1] = first
    if model == S2_MK1:
        light_kind = S2_MK1_LIGHTS
        for report_id in S2_MK1_CALIBRATION:
            frame = initial_input(model, hid, report_id, 33, feature=True)
            if frame is not None:
                calibration.append(frame)
        analog = initial_input(model, hid, 2, model.analog_size)
        if analog is not None:
            latest[2] = analog
    decoder = Decoder(LENGTHS)
    heartbeat = None
    last_lights = None
    while audio is None or audio.poll() is None:
        for fd in select.select([hid, midi], [], [], 0.05)[0]:
            try:
                data = os.read(fd, max(model.input_size, model.analog_size) + 1 if fd == hid else 4096)
            except BlockingIOError:
                continue
            if not data:
                return
            if fd == hid:
                frame = input_frame(model, data)
                if frame is not None and data[0] in (1, 2) and frame != latest.get(data[0]):
                    latest[data[0]] = frame
                    if heartbeat is not None:
                        write_all(midi, frame)
            else:
                for kind, payload in decoder.append(data):
                    if kind == STATUS and payload == b'\x03':
                        write_all(midi, encode(STATUS, b'\x01', LENGTHS))
                        heartbeat = time.monotonic()
                        last_lights = None
                        for frame in calibration:
                            write_all(midi, frame)
                        for _, frame in sorted(latest.items()):
                            write_all(midi, frame)
                    if heartbeat is not None and kind == light_kind:
                        report = feedback(model, payload)
                        if report is not None and report != last_lights:
                            if not select.select([], [hid], [], 0.05)[1] or os.write(hid, report) != len(report):
                                raise OSError('The controller did not accept a complete light report.')
                            last_lights = report
        if heartbeat is not None and time.monotonic() - heartbeat >= 0.5:
            write_all(midi, encode(STATUS, b'\x01', LENGTHS))
            heartbeat = time.monotonic()
    raise RuntimeError(f'The controller audio relay stopped with exit status {audio.returncode}.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('model', choices=MODELS)
    parser.add_argument('--hidraw', required=True, type=Path)
    parser.add_argument('--midi', required=True, type=Path)
    parser.add_argument('--audio-in', default='hw:CARD=UAC2Gadget,DEV=0', help='USB audio gadget capture PCM')
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

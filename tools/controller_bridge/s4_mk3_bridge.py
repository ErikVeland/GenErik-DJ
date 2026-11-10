#!/usr/bin/env python3
"""Relay S4 Mk3 HID controls, lights and four-channel audio on a Linux bridge."""
import argparse
import fcntl
import os
from pathlib import Path
import select
import stat
import subprocess
import sys
import time

from z1_bridge import Decoder, encode, write_all
from traktor_factory_screens import ScreenWorker

INPUT, LIGHTS, RING, STATUS = 5, 6, 7, 8
SCREEN, SCREEN_CONTENT = 18, 19
LENGTHS = {INPUT: 96, LIGHTS: 95, RING: 41, STATUS: 1, SCREEN: 64, SCREEN_CONTENT: 103}
MIN_INPUT_LENGTH = {1: 23, 2: 79, 3: 44}
RING_INIT = bytes([0x30, 0, 1, 3] + [0] * 23)
ID = [3, 0x17CC, 0x1720]


def frame(kind, report):
    if kind == INPUT:
        if not valid_input(report):
            raise ValueError("Invalid S4 Mk3 input report.")
        report = bytes([len(report)]) + report.ljust(95, b'\x00')
    return encode(kind, report, LENGTHS)


def valid_input(report):
    return bool(report) and report[0] in MIN_INPUT_LENGTH and MIN_INPUT_LENGTH[report[0]] <= len(report) <= 95


def valid_feedback(kind, report):
    if kind == LIGHTS:
        return len(report) == 95 and report[0] == 0x80 and all(value <= 127 for value in report[1:])
    return (kind == RING and len(report) == 41 and report[0] == 0x32 and report[1] < 2
            and report[2] in (0, 5) and not any(report[3:9])
            and all(value == 0 or 12 <= value <= 15 or 44 <= value <= 47 for value in report[9:])
            and (report[2] == 5 or not any(report[9:])))


def write_hid(hid, report):
    if not select.select([], [hid], [], 0.05)[1] or os.write(hid, report) != len(report):
        raise OSError("The S4 Mk3 did not accept a complete light report.")


def initial_input(hid, report_id):
    report = bytearray([report_id] + [0] * 94)
    request = (3 << 30) | (len(report) << 16) | (ord('H') << 8) | 0x0a
    try:
        count = fcntl.ioctl(hid, request, report, True)
    except OSError:
        return None
    result = bytes(report[:count])
    return result if valid_input(result) and result[0] == report_id else None


def controller_usb_parent(hid_path, sysfs=Path('/sys')):
    device = (sysfs / 'class/hidraw' / hid_path.name / 'device').resolve(strict=True)
    identity = next((line.split('=', 1)[1] for line in (device / 'uevent').read_text().splitlines()
                     if line.startswith('HID_ID=')), '')
    if not identity or [int(value, 16) for value in identity.split(':')] != ID:
        raise ValueError("The HID device is not a Traktor Kontrol S4 Mk3 (17cc:1720).")
    interface = device.parent
    if (interface / 'bInterfaceNumber').read_text().strip() != '03':
        raise ValueError("Select the S4 Mk3's HID control interface 03.")
    return interface.parent


def controller_pcm(usb_parent, direction, sysfs=Path('/sys')):
    matches = [node.name for node in (sysfs / 'class/sound').glob(f'pcmC*D*{direction}')
               if usb_parent in node.resolve(strict=True).parents]
    if len(matches) != 1:
        raise ValueError("The controller must expose one ALSA device for this direction.")
    card, device = matches[0][4:-1].split('D')
    return f'plughw:{card},{device}'


def playback_pcm(usb_parent, sysfs=Path('/sys')):
    return controller_pcm(usb_parent, 'p', sysfs)


def audio_command(capture, playback, channels=4):
    return ['alsaloop', '-C', capture, '-P', playback, '-c', str(channels), '-r', '48000', '-f', 'S32_LE',
            '-t', '20000', '-S', '4']


def relay(hid, midi, audio, screens=None):
    latest = {report[0]: report for report_id in (1, 2)
              if (report := initial_input(hid, report_id)) is not None}
    write_hid(hid, RING_INIT)
    write_hid(hid, RING_INIT[:1] + b'\x01' + RING_INIT[2:])
    decoder = Decoder(LENGTHS)
    announced = False
    last_heartbeat = last_analogs = time.monotonic()
    sent = {}
    feedback = {}
    while audio.poll() is None:
        readable = select.select([hid, midi], [], [], 0.01)[0]
        for fd in readable:
            try:
                data = os.read(fd, 96 if fd == hid else 4096)
            except BlockingIOError:
                continue
            if not data:
                return
            if fd == hid:
                if valid_input(data):
                    latest[data[0]] = data
                    if announced and data[0] == 1 and sent.get(1) != data:
                        write_all(midi, frame(INPUT, data))
                        sent[1] = data
            else:
                for kind, report in decoder.append(data):
                    if kind == STATUS and report == b'\x03':
                        announced = True
                        write_all(midi, frame(STATUS, b'\x01'))
                        last_heartbeat = time.monotonic()
                        sent.clear()
                        feedback.clear()
                        for report_id, current in sorted(latest.items()):
                            write_all(midi, frame(INPUT, current))
                            sent[report_id] = current
                    elif announced and screens is not None and kind in (SCREEN, SCREEN_CONTENT):
                        screens.submit(report, content=kind == SCREEN_CONTENT)
                    elif announced and valid_feedback(kind, report):
                        key = (kind, report[1] if kind == RING else 0)
                        if feedback.get(key) != report:
                            write_hid(hid, report)
                            feedback[key] = report
        now = time.monotonic()
        if announced and now - last_analogs >= 0.01:
            for report_id in (2, 3):
                current = latest.get(report_id)
                if current is not None and sent.get(report_id) != current:
                    write_all(midi, frame(INPUT, current))
                    sent[report_id] = current
            last_analogs = now
        if announced and now - last_heartbeat >= 0.5:
            write_all(midi, frame(STATUS, b'\x01'))
            last_heartbeat = now
    raise RuntimeError(f"The S4 Mk3 audio relay stopped with exit status {audio.returncode}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--hidraw', required=True, type=Path, help='S4 Mk3 interface 03 character device')
    parser.add_argument('--midi', required=True, type=Path, help='USB gadget raw MIDI character device')
    parser.add_argument('--audio-in', default='hw:CARD=UAC2Gadget,DEV=0', help='USB audio gadget capture PCM')
    args = parser.parse_args()
    if not sys.platform.startswith('linux'):
        parser.error("Run the relay on Linux bridge hardware.")
    hid_path = args.hidraw.resolve(strict=True)
    usb_parent = controller_usb_parent(hid_path)
    playback = playback_pcm(usb_parent)
    if not all(stat.S_ISCHR(path.stat().st_mode) for path in (hid_path, args.midi)):
        parser.error("Both paths must identify character devices.")
    hid = os.open(hid_path, os.O_RDWR | os.O_NONBLOCK)
    try:
        midi = os.open(args.midi, os.O_RDWR | os.O_NONBLOCK)
        try:
            with subprocess.Popen(audio_command(args.audio_in, playback)) as audio:
                screens = None
                try:
                    screens = ScreenWorker('s4-mk3', usb_parent)
                except (OSError, ValueError) as error:
                    print(f'S4 Mk3 screens could not start. {error}', file=sys.stderr)
                try:
                    relay(hid, midi, audio, screens)
                finally:
                    if screens is not None:
                        screens.close()
                    if audio.poll() is None:
                        audio.terminate()
                        try:
                            audio.wait(timeout=2)
                        except subprocess.TimeoutExpired:
                            audio.kill()
        finally:
            try:
                write_all(midi, frame(STATUS, b'\x00'))
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

#!/usr/bin/env python3
"""Original Z1 HID to the GenErik development MIDI bridge. Linux hardware only."""
import argparse
import fcntl
import os
from pathlib import Path
import select
import stat
import struct
import sys
import time

LENGTHS = {1: 30, 2: 22, 3: 32, 4: 1}
PREFIX = bytes([0x7d, 0x47, 0x44, 0x4a, 1])


def encode(kind, payload):
    if kind not in LENGTHS or len(payload) != LENGTHS[kind]:
        raise ValueError("Invalid bridge report type or length.")
    result = bytearray(b'\xf0' + PREFIX + bytes([kind, len(payload)]))
    for start in range(0, len(payload), 7):
        group = payload[start:start + 7]
        result.append(sum((value >> 7) << bit for bit, value in enumerate(group)))
        result.extend(value & 0x7f for value in group)
    result.extend([(kind + len(payload) + sum(payload)) & 0x7f, 0xf7])
    return bytes(result)


class Decoder:
    def __init__(self):
        self.buffer = bytearray()
        self.collecting = False

    def append(self, data):
        frames = []
        for value in data:
            if value >= 0xf8:
                continue
            if value == 0xf0:
                self.buffer.clear()
                self.collecting = True
            elif value == 0xf7:
                frame = self.decode(self.buffer) if self.collecting else None
                if frame is not None:
                    frames.append(frame)
                self.collecting = False
                self.buffer.clear()
            elif self.collecting:
                if value >= 128 or len(self.buffer) >= 128:
                    self.buffer.clear()
                    self.collecting = False
                else:
                    self.buffer.append(value)
        return frames

    @staticmethod
    def decode(data):
        if len(data) < 8 or data[:5] != PREFIX:
            return None
        kind, count = data[5:7]
        if LENGTHS.get(kind) != count or len(data) != 8 + count + (count + 6) // 7:
            return None
        raw = bytearray()
        index = 7
        while len(raw) < count:
            length = min(7, count - len(raw))
            mask = data[index]
            index += 1
            if mask >> length:
                return None
            for bit in range(length):
                raw.append(data[index] | (((mask >> bit) & 1) << 7))
                index += 1
        if data[index] != (kind + count + sum(raw)) & 0x7f:
            return None
        return kind, bytes(raw)


def valid_input(report):
    return (len(report) == 30 and report[0] == 1 and report[29] & ~0x1f == 0
            and all(value <= 4095 for value in struct.unpack('<14H', report[1:29])))


def valid_output(report):
    return len(report) == 22 and report[0] == 0x80 and all(value <= 127 for value in report[1:])


def calibration(hid):
    report = bytearray([0xd2] + [0] * 32)
    request = (3 << 30) | (len(report) << 16) | (ord('H') << 8) | 0x07
    try:
        fcntl.ioctl(hid, request, report, True)
    except OSError:
        return None
    if report[0] != 0xd2:
        return None
    minimum, maximum = struct.unpack('<HH', report[29:33])
    return bytes(report[1:]) if 0 <= minimum < maximum <= 4095 else None


def write_all(fd, data):
    remaining = memoryview(data)
    deadline = time.monotonic() + 0.5
    while remaining:
        if time.monotonic() >= deadline:
            raise TimeoutError("Bridge output stalled.")
        ready = select.select([], [fd], [], max(0, deadline - time.monotonic()))[1]
        if not ready:
            raise TimeoutError("Bridge output stalled. The relay stopped instead of accumulating old controls.")
        try:
            written = os.write(fd, remaining)
        except BlockingIOError:
            continue
        if written == 0:
            raise OSError("Bridge output closed.")
        remaining = remaining[written:]


def write_report(hid, payload):
    if not valid_output(payload):
        raise ValueError("Only the Z1 light report can be written.")
    if not select.select([], [hid], [], 0.5)[1] or os.write(hid, payload) != len(payload):
        raise OSError("The complete Z1 light report could not be written. Relay stopped.")


def announce(hid, midi, previous):
    write_all(midi, encode(4, b'\x01'))
    values = calibration(hid)
    write_all(midi, encode(3, values) if values is not None else encode(4, b'\x02'))
    if previous is not None:
        write_all(midi, encode(1, previous))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--hidraw', required=True, help='Original Z1 /dev/hidrawN device')
    parser.add_argument('--midi', required=True, help='ALSA raw MIDI node for the iPad-facing USB MIDI gadget')
    args = parser.parse_args()
    if not sys.platform.startswith('linux'):
        parser.error("Run this relay on Linux USB-host/device bridge hardware, not on the iPad or Mac.")
    hid_path = Path(args.hidraw).resolve()
    properties = Path('/sys/class/hidraw') / hid_path.name / 'device/uevent'
    identity = next((line.split('=', 1)[1] for line in properties.read_text().splitlines() if line.startswith('HID_ID=')), '')
    parts = identity.split(':')
    if len(parts) != 3 or [int(value, 16) for value in parts] != [3, 0x17cc, 0x1210]:
        parser.error("The HID device is not the original Native Instruments Z1 (17cc:1210).")
    if not all(stat.S_ISCHR(Path(path).stat().st_mode) for path in [args.hidraw, args.midi]):
        parser.error("Both paths must identify character devices.")
    hid = os.open(args.hidraw, os.O_RDWR | os.O_NONBLOCK)
    midi = None
    try:
        midi = os.open(args.midi, os.O_RDWR | os.O_NONBLOCK)
        announce(hid, midi, None)
        decoder = Decoder()
        previous = None
        print("Z1 control relay active. This relay does not forward audio.", flush=True)
        while True:
            for fd in select.select([hid, midi], [], [], 1)[0]:
                try:
                    data = os.read(fd, 64 if fd == hid else 4096)
                except BlockingIOError:
                    continue
                if not data:
                    return
                if fd == hid:
                    if valid_input(data) and data != previous:
                        write_all(midi, encode(1, data))
                        previous = data
                else:
                    for kind, payload in decoder.append(data):
                        if kind == 2 and valid_output(payload):
                            write_report(hid, payload)
                        elif kind == 4 and payload == b'\x03':
                            announce(hid, midi, previous)
    finally:
        if midi is not None:
            try:
                write_all(midi, encode(4, b'\x00'))
            except (OSError, TimeoutError):
                pass
            os.close(midi)
        os.close(hid)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except (OSError, ValueError, TimeoutError) as error:
        sys.exit(str(error))

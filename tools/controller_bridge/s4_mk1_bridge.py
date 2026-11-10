#!/usr/bin/env python3
"""Bridge S4 Mk1 CAIAQ controls, LEDs and four-channel playback."""
import argparse
import ctypes as c
import os
from pathlib import Path
import select
import subprocess
import sys
import time
from contextlib import contextmanager
from struct import pack

from s4_mk3_bridge import audio_command, playback_pcm
from z1_bridge import Decoder, encode, write_all

INPUT, LIGHTS, STATUS = 14, 15, 11
LENGTHS = {INPUT: 74, LIGHTS: 103, STATUS: 1}
LED_COUNT = 163
KEY_BASE, AXIS_BASE, AXIS_COUNT = 0x100, 0x10, 47


class InputState:
    def __init__(self, keys, axes):
        self.keys = sum(1 << (key - KEY_BASE) for key in set(keys) if KEY_BASE <= key < KEY_BASE + 96)
        self.axes = axes
        self.wheel_ms = 0

    def update(self, event):
        if event.type == 1 and KEY_BASE <= event.code < KEY_BASE + 96 and event.value in (0, 1):
            bit = 1 << (event.code - KEY_BASE)
            self.keys = self.keys | bit if event.value else self.keys & ~bit
        if event.type == 3 and AXIS_BASE <= event.code < AXIS_BASE + AXIS_COUNT:
            axis = event.code - AXIS_BASE
            ceiling = 4095 if axis < 36 else 1023 if axis < 38 else 15
            if 0 <= event.value <= ceiling:
                self.axes[axis] = event.value
                if axis in (36, 37):
                    self.wheel_ms = (event.sec * 1000 + event.usec // 1000) & 0xffff

    def frames(self):
        buttons = b'\x01' + self.keys.to_bytes(12, 'little') + pack('<HH', *self.axes[36:38])
        buttons += bytes(self.axes[38:47]) + pack('<HHH', *self.axes[10:12], self.wheel_ms)
        pots = b'\x02' + pack('<36H', *self.axes[:36])
        return tuple(encode(INPUT, bytes([len(report)]) + report.ljust(73, b'\0'), LENGTHS)
                     for report in (buttons, pots))


def unpack_lights(packet):
    if len(packet) != LENGTHS[LIGHTS] or packet[0] != 0x80 or packet[-1] & 0x80:
        return None
    packed = int.from_bytes(packet[1:], 'little')
    return [(packed >> (index * 5)) & 31 for index in range(LED_COUNT)]


def controller(sysfs=Path('/sys')):
    matches = []
    for event in (sysfs / 'class/input').glob('event*'):
        for parent in event.resolve(strict=True).parents:
            vendor, product = parent / 'idVendor', parent / 'idProduct'
            if vendor.is_file() and product.is_file():
                if vendor.read_text().strip() == '17cc' and product.read_text().strip() == 'baff':
                    matches.append((parent, '/dev/input/' + event.name))
                break
    if len(matches) != 1:
        raise ValueError('Connect one S4 Mk1 with CAIAQ input support enabled.')
    return matches[0]


@contextmanager
def alsa_lights(pcm):
    alsa = c.CDLL('libasound.so.2')
    handle, value, info = c.c_void_p(), c.c_void_p(), c.c_void_p()
    card = pcm.removeprefix('plughw:').split(',')[0]
    alsa.snd_ctl_elem_info_get_name.restype = c.c_char_p

    def check(result):
        if result < 0:
            raise OSError(f'ALSA could not access the S4 Mk1 LED controls ({result}).')

    try:
        check(alsa.snd_ctl_open(c.byref(handle), ('hw:' + card).encode(), 0))
        check(alsa.snd_ctl_elem_value_malloc(c.byref(value)))
        check(alsa.snd_ctl_elem_info_malloc(c.byref(info)))
        for numid, name in [(5, b'LED: Master: Warning'), (163, b'LED: FX2: Mode')]:
            alsa.snd_ctl_elem_info_set_numid(info, numid)
            check(alsa.snd_ctl_elem_info(handle, info))
            if alsa.snd_ctl_elem_info_get_name(info) != name:
                raise ValueError('The S4 Mk1 ALSA LED layout does not match CAIAQ.')

        def write(numid, level):
            alsa.snd_ctl_elem_value_set_numid(value, numid)
            alsa.snd_ctl_elem_value_set_integer(value, 0, c.c_long(level))
            check(alsa.snd_ctl_elem_write(handle, value))

        yield write
    finally:
        if info:
            alsa.snd_ctl_elem_info_free(info)
        if value:
            alsa.snd_ctl_elem_value_free(value)
        if handle:
            alsa.snd_ctl_close(handle)


def current_state(device):
    return InputState(device.active_keys(), [device.absinfo(AXIS_BASE + axis).value for axis in range(AXIS_COUNT)])


def relay(device, midi, audio, write_light):
    state = current_state(device)
    decoder = Decoder(LENGTHS)
    announced = False
    dropped = False
    last_heartbeat = time.monotonic()
    sent = (None, None)
    leds = [None] * LED_COUNT

    def send_state():
        nonlocal sent
        frames = state.frames()
        for frame, previous in zip(frames, sent):
            if frame != previous:
                write_all(midi, frame)
        sent = frames

    while audio.poll() is None:
        for fd in select.select([device.fd, midi], [], [], 0.05)[0]:
            try:
                if fd == device.fd:
                    for event in device.read():
                        if event.type == 0 and event.code == 3:
                            dropped = True
                            if announced:
                                write_all(midi, encode(STATUS, b'\x00', LENGTHS))
                            announced = False
                        elif event.type == 0 and event.code == 0:
                            if dropped:
                                state = current_state(device)
                                dropped = False
                            if announced:
                                send_state()
                        elif not dropped:
                            state.update(event)
                    continue
                data = os.read(midi, 4096)
            except BlockingIOError:
                continue
            if not data:
                return
            for kind, payload in decoder.append(data):
                if kind == STATUS and payload == b'\x03' and not dropped:
                    announced = True
                    last_heartbeat = time.monotonic()
                    write_all(midi, encode(STATUS, b'\x01', LENGTHS))
                    sent = (None, None)
                    send_state()
                elif announced and kind == LIGHTS:
                    values = unpack_lights(payload)
                    if values is not None:
                        for index, value in enumerate(values):
                            if value != leds[index]:
                                write_light(index + 1, value)
                        leds = values
        if announced and time.monotonic() - last_heartbeat >= 0.5:
            write_all(midi, encode(STATUS, b'\x01', LENGTHS))
            last_heartbeat = time.monotonic()
    raise RuntimeError(f'The S4 Mk1 playback relay stopped with exit status {audio.returncode}.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--midi', required=True, type=Path, help='USB gadget raw MIDI node')
    parser.add_argument('--audio-in', default='hw:CARD=UAC2Gadget,DEV=0', help='USB audio gadget capture PCM')
    args = parser.parse_args()
    if not sys.platform.startswith('linux'):
        parser.error('Run the relay on Linux bridge hardware.')
    from evdev import InputDevice

    parent, event = controller()
    pcm = playback_pcm(parent)
    device = InputDevice(event)
    try:
        midi = os.open(args.midi, os.O_RDWR | os.O_NONBLOCK)
        try:
            with alsa_lights(pcm) as write_light, subprocess.Popen(audio_command(args.audio_in, pcm)) as audio:
                try:
                    relay(device, midi, audio, write_light)
                finally:
                    if audio.poll() is None:
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
        device.close()


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except (ImportError, OSError, RuntimeError, ValueError, TimeoutError) as error:
        sys.exit(str(error))

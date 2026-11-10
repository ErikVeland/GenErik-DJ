"""Draw deck status on the D2, S5 and S8 USB panels."""
from array import array
from pathlib import Path
import struct
import sys
from threading import Condition, Thread

WIDTH, HEIGHT = 480, 272
PANELS = {'d2': (1, 0x02, 1), 's5': (4, 0x03, 2), 's8': (6, 0x04, 2)}
STRIDE = WIDTH * 3


def rectangles(current, previous):
    if previous is None:
        return [(0, HEIGHT)]
    bands = []
    for row in range(HEIGHT):
        offset = row * STRIDE
        if current[offset:offset + STRIDE] != previous[offset:offset + STRIDE]:
            if bands and bands[-1][0] + bands[-1][1] == row:
                start, height = bands[-1]
                bands[-1] = start, height + 1
            else:
                bands.append((row, 1))
    return [(0, HEIGHT)] if len(bands) > 16 else bands


def encode_screen(screen, current, previous=None):
    for row, height in rectangles(current, previous):
        pixels = memoryview(current)[row * STRIDE:(row + height) * STRIDE]
        rgb565 = array('H', ((r >> 3) << 11 | (g >> 2) << 5 | (b >> 3)
                             for r, g, b in zip(pixels[::3], pixels[1::3], pixels[2::3])))
        if sys.byteorder == 'little':
            rgb565.byteswap()
        header = struct.pack('>BBBB8xHH', 0x84, 0, screen, 0x60, WIDTH, height)
        header = header[:10] + struct.pack('>H', row) + header[12:]
        runs = struct.pack('>I', len(rgb565) // 2) + rgb565.tobytes() + b'\x03\0\0\0'
        yield header + runs + bytes((0x40, 0, screen, 0))


def draw_status(payload):
    from PIL import Image, ImageDraw, ImageFont

    side, deck, flags, position, duration, bpm, length = struct.unpack_from('<BBBHHHB', payload)
    title = payload[10:10 + length].decode('utf-8', errors='ignore').strip()
    image = Image.new('RGB', (WIDTH, HEIGHT), (12, 18, 27))
    draw = ImageDraw.Draw(image)
    font_file = Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
    def font(size):
        return ImageFont.truetype(str(font_file), size) if font_file.is_file() else ImageFont.load_default()
    def time_label(seconds):
        return f'{seconds // 60}:{seconds % 60:02}'
    cyan = (93, 206, 255)
    amber = (255, 180, 65)
    white = (237, 244, 252)
    draw.rectangle((0, 0, WIDTH - 1, 56), fill=(26, 39, 58))
    draw.text((24, 12), f'DECK {"ABCD"[deck]}', font=font(27), fill=cyan)
    state = 'PLAY' if flags & 1 else 'READY' if flags & 8 else 'EMPTY'
    draw.text((345, 14), state, font=font(22), fill=white)
    title = title or ('Untitled track' if flags & 8 else 'Load a track')
    title_font = font(26)
    while len(title) > 1 and draw.textlength(title, font=title_font) > WIDTH - 48:
        title = title[:-2].rstrip() + '…'
    draw.text((24, 78), title, font=title_font, fill=white)
    remaining = max(0, duration - position)
    draw.text((24, 129), time_label(position), font=font(33), fill=white)
    if duration:
        draw.text((313, 129), f'-{time_label(remaining)}', font=font(33),
                  fill=amber if remaining <= 30 and not flags & 4 else white)
    draw.rectangle((24, 185, 455, 194), fill=(47, 62, 80))
    if duration and position:
        draw.rectangle((24, 185, 24 + 431 * min(position, duration) // duration, 194), fill=cyan)
    footer = f'{bpm / 10:.1f} BPM' if bpm else 'BPM —'
    if flags & 2:
        footer += '     SYNC'
    if flags & 4:
        footer += '     LOOP'
    draw.text((24, 219), footer, font=font(22), fill=cyan)
    return side, image.tobytes()


class ScreenWorker:
    def __init__(self, model, usb_parent):
        self.model = model
        self.interface, self.endpoint, self.count = PANELS[model]
        self.bus = int((usb_parent / 'busnum').read_text())
        self.address = int((usb_parent / 'devnum').read_text())
        self.condition = Condition()
        self.pending = {}
        self.running = True
        self.thread = Thread(target=self.run, name=f'{model}-display', daemon=True)
        self.thread.start()

    def submit(self, payload):
        if len(payload) != 64 or payload[0] >= self.count or payload[1] >= 4 or payload[9] > 54:
            return
        with self.condition:
            self.pending[payload[0]] = payload
            self.condition.notify()

    def close(self):
        with self.condition:
            self.running = False
            self.condition.notify()
        self.thread.join(timeout=1)

    def run(self):
        try:
            import usb.core
            import usb.util
            from PIL import Image  # noqa: F401
        except ImportError as error:
            print(f'{self.model} screens need PyUSB and Pillow. {error}', file=sys.stderr)
            return
        device = None
        try:
            device = usb.core.find(bus=self.bus, address=self.address, idVendor=0x17cc)
            if device is None:
                raise OSError('The USB screen device disconnected.')
            config = device.get_active_configuration()
            interface = config[(self.interface, 0)]
            if not any(endpoint.bEndpointAddress == self.endpoint
                       and usb.util.endpoint_type(endpoint.bmAttributes) == usb.util.ENDPOINT_TYPE_BULK
                       for endpoint in interface):
                raise OSError('The documented screen endpoint is unavailable.')
            usb.util.claim_interface(device, self.interface)
            previous = {}
            while True:
                with self.condition:
                    self.condition.wait_for(lambda: not self.running or self.pending)
                    if not self.running:
                        return
                    _, payload = self.pending.popitem()
                side, frame = draw_status(payload)
                for rectangle in encode_screen(side, frame, previous.get(side)):
                    if device.write(self.endpoint, rectangle, timeout=250) != len(rectangle):
                        raise OSError('The screen did not accept the complete update.')
                previous[side] = frame
        except (OSError, KeyError, ValueError) as error:
            print(f'{self.model} screens stopped. {error}', file=sys.stderr)
        finally:
            if device is not None:
                usb.util.dispose_resources(device)

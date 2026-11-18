"""Read the public VirtualDJ inventory without importing controller implementations."""
from html.parser import HTMLParser
from urllib.parse import urljoin

VIRTUALDJ_URL = 'https://virtualdj.com/products/hardware.html?view=all'
CATEGORIES = {'All-in-one', 'Deck controllers (cd player/turntable)', 'Clubmixers',
              'Addon Units (FX,Pads,..)', 'Sound cards', 'Rackmounts', 'Mini Mixers', 'Timecode vinyls'}
NAME_RESOLUTIONS = {
    'Hercules INPULSE 300 MK2': 'Hercules DJControl Inpulse 300 MK2',
    'Hercules INPULSE 500': 'Hercules DJControl Inpulse 500',
    'Hercules Inpulse 200 MK3': 'Hercules DJControl Inpulse 200 MK3',
    'Hercules INPULSE 200 MK2': 'Hercules DJControl Inpulse 200 MK2',
    'Hercules Inpulse T7': 'Hercules DJControl Inpulse T7',
    'Hercules Inpulse 300': 'Hercules DJControl Inpulse 300',
    'Hercules JOGVISION': 'Hercules DJControl Jogvision',
    'Hercules StarLight': 'Hercules DJControl Starlight',
    'Hercules Inpulse 200': 'Hercules DJControl Inpulse 200',
    'Hercules Instinct P8': 'Hercules DJControl Instinct P8',
    'Hercules UNIVERSAL DJ': 'Hercules Universal DJ',
    'Hercules DJCONTROL WAVE': 'Hercules DJControlWave',
    'Mixvibes MIXVIBES UMIX CONTROL PRO': 'MixVibes U-Mix Control Pro',
    'Numark PARTY MIX MKII': 'Numark Party Mix II',
    'Numark PARTYMIX MK3': 'Numark Party Mix III',
    'Denon DJ LC6000': 'Denon DJ LC6000 PRIME',
    'Denon DJ SC5000': 'Denon DJ SC5000 PRIME',
    'Denon DJ SC5000M': 'Denon DJ SC5000M PRIME',
    'Denon DJ SC6000': 'Denon DJ SC6000 PRIME',
    'Denon DJ SC6000M': 'Denon DJ SC6000M PRIME',
    'Denon DJ SC2000': 'Denon DN SC2000',
    'Denon DJ X1850': 'Denon DJ X1850 PRIME',
    'AKAI AFX': 'Akai Pro AFX',
    'AKAI AMX': 'Akai Pro AMX',
    'Midi Fighter Twister': 'DJ TechTools MIDI Fighter Twister',
    'Midi Fighter 3D': 'DJ TechTools MIDI Fighter 3D',
    'DJ-Tech VVT-101': 'DJ-Tech VTT-101',
    'Phase': 'Phase SAS Phase',
    'The Next Beat': 'The Next Beat by Tiësto',
    'Reloop RMX90': 'Reloop RMX-90 DVS',
    'Reloop DIGITAL JOCKEY 2 CE': 'Reloop Digital Jockey 2 Controller',
    'Reloop DIGITAL JOCKEY 2 IE': 'Reloop Digital Jockey 2 Interface Edition',
    'Reloop DIGITAL JOCKEY 2 ME': 'Reloop Digital Jockey 2 Master Edition',
    'Reloop DIGITAL JOCKEY 3 ME': 'Reloop Jockey 3 ME',
    'Reloop MIXAGE CE': 'Reloop Mixage Controller Edition',
    'Reloop MIXAGE IE': 'Reloop Mixage Interface Edition',
    'Reloop MIXAGE IE MK2': 'Reloop Mixage Interface Edition MK2',
}
for _model in ['S4 MK2', 'S2 MK2', 'X1 MK2', 'S2 MK3', 'S5', 'X1 MK3', 'S3', 'S8', 'D2', 'Z2', 'Z1', 'Z1 MK2', 'F1', 'X1']:
    for _prefix in ['Native Instruments KONTROL ', 'Native Instruments Kontrol ']:
        NAME_RESOLUTIONS[_prefix + _model] = 'Native Instruments Traktor Kontrol ' + _model
NAME_RESOLUTIONS['Native Instruments KONTROL S2'] = 'Native Instruments Traktor Kontrol S2 Mk1'


class VirtualDJInventoryParser(HTMLParser):
    """Capture one named product per featured or regular public inventory card."""
    def __init__(self):
        super().__init__()
        self.rows = []
        self.current = None
        self.text = None
        self.category = ''
        self.category_text = None

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag == 'span' and attrs.get('class') == 'hwp_categoryname':
            self.category_text = []
        if tag == 'article' and {'hwp_featurebox', 'hwp_box'} & set(attrs.get('class', '').split()):
            self.current = {}
        if self.current is not None and tag == 'a' and attrs.get('href', '').startswith('?model='):
            self.current['url'] = urljoin(VIRTUALDJ_URL, attrs['href'])
        if self.current is not None and tag == 'b':
            self.text = []

    def handle_data(self, data):
        if self.category_text is not None:
            self.category_text.append(data)
        if self.text is not None:
            self.text.append(data)

    def handle_endtag(self, tag):
        if tag == 'span' and self.category_text is not None:
            self.category = ' '.join(''.join(self.category_text).split())
            self.category_text = None
        if tag == 'b' and self.text is not None:
            name = ' '.join(''.join(self.text).split())
            self.current.update(sourceName=name, name=NAME_RESOLUTIONS.get(name, name), category=self.category,
                                role='dvs-medium' if self.category == 'Timecode vinyls' else
                                'dvs-only' if self.category == 'Sound cards' else
                                'accessory' if self.category in {'Addon Units (FX,Pads,..)', 'Mini Mixers'} else 'primary')
            self.rows.append(self.current)
            self.current, self.text = None, None


def read_virtualdj(html):
    """Reject incomplete or ambiguous product inventories before updating the catalogue."""
    parser = VirtualDJInventoryParser()
    parser.feed(html)
    rows = parser.rows
    if not 400 <= len(rows) <= 1024 or len({r.get('url') for r in rows}) != len(rows):
        raise ValueError('The VirtualDJ inventory is incomplete or contains duplicate product URLs.')
    if any(not r['sourceName'] or r['category'] not in CATEGORIES or '?model=' not in r.get('url', '') for r in rows):
        raise ValueError('The VirtualDJ inventory contains an unidentified product or category.')
    return rows

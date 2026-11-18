#!/usr/bin/env python3
"""Prepare responsive copies of verified captures and retain their provenance."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib
import json

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
ASSETS = ROOT / 'assets'
workspace_source = REPO / 'TestBuilds/r52/before.png'
library_source = REPO / 'TestBuilds/r50/browser-height.png'
workspace = Image.open(workspace_source).convert('RGB')
library = Image.open(library_source).convert('RGB').crop((10, 1180, 2010, 1665))
waveform = workspace.crop((10, 990, 2010, 1580))
for name, source, widths in [('workspace',workspace,[960,1600,2224]),('library',library,[960,1600]),('waveform',waveform,[960,1600])]:
    for width in widths:
        im = source.resize((width, round(source.height*width/source.width)), Image.Resampling.LANCZOS)
        im.save(ASSETS/f'{name}-{width}.webp',quality=88,method=6)
        if width == 1600:
            im.save(ASSETS/f'{name}-{width}.jpg',quality=90,optimize=True)
mark = Image.open(REPO / 'Replica/Sources/TDJInterface/Resources/HeaderArtwork/GenErikHeaderMark.png').convert('RGBA')
mark.thumbnail((160,160), Image.Resampling.LANCZOS)
mark.save(ASSETS/'mark.png')
icon = Image.new('RGBA',(64,64),'#0b0d0e')
mark.thumbnail((54,54), Image.Resampling.LANCZOS)
icon.alpha_composite(mark,((64-mark.width)//2,(64-mark.height)//2))
icon.save(ASSETS/'favicon.png')
social = Image.new('RGB',(1200,630),'#0b0d0e')
draw=ImageDraw.Draw(social)
from fontTools.ttLib import TTFont
import tempfile
font = TTFont(ASSETS/'archivo-latin.woff2')
font.flavor = None
font_path = str(Path(tempfile.gettempdir())/'generik-archivo.ttf')
font.save(font_path)
font=ImageFont.truetype(font_path,100)
small=ImageFont.truetype(font_path,25)
draw.text((64,45),'GenErik DJ',font=font,fill='#e6e6e6')
draw.text((69,171),'Native DJ software. In development for iPad.',font=small,fill='#a7adb2')
strip=waveform.resize((1200,354),Image.Resampling.LANCZOS)
social.paste(strip,(0,245))
draw.line((64,222,1136,222),fill='#7ddee6',width=2)
social.save(ASSETS/'social.jpg',quality=92,optimize=True)
provenance=[]
for path in (workspace_source,library_source):
    provenance.append({'source':str(path.relative_to(REPO)), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'status':'Earlier development capture; not a release-approved current screenshot'})
(ROOT/'image-provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
print('Prepared genuine interface images, brand assets and social preview.')

"""Launchpad S uses its own X-Y protocol and two-colour LED values."""
from curated import profile
from native_dj_grid import add_native_dj_grid

LAUNCHPAD_S_SOURCE = 'https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/novation/downloads/10753/launchpad-s-prm.pdf'
LAUNCHPAD_S_REFERENCES = {'Novation Launchpad S': {
    'url': LAUNCHPAD_S_SOURCE, 'sha256': '5a1d051e7413871bba9c56a065bfd6069f218e2656e97cb5bdcf5ef4d32615fa',
    'files': [{'cachePath': 'TestBuilds/r434/upstream/launchpad-s-prm.pdf', 'sha256': '5a1d051e7413871bba9c56a065bfd6069f218e2656e97cb5bdcf5ef4d32615fa'}, {'cachePath': 'TestBuilds/r435/upstream/launchpad-s-afg.pdf', 'sha256': '795de2456376f4edaccbd1ac2e9ab0e256386aa53d2f249a57cffcb1ee3082f6'}],
    'relatedSources': [{'url': 'https://downloads.novationmusic.com/novation/launchpad-mk1/launchpad-s'}, {'url': 'https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/novation/downloads/10752/launchpad-s-afg.pdf'}],
    'pages': [3, 5, 8, 12, 13, 17, 18],
    'review': 'Own manufacturer reference specifies USB class-compliant MIDI channel1, X-Y grid Notes16*y+x with top row0..7 and bottom112..119, NoteOn127 press and NoteOn0 release. Native accepts both ordinary release forms. Native assigns its existing four-quadrant DJ layout: A/B below and opt-in C/D above,64 inputs. Own LED facts specify NoteOn at the input address, red15, green60, amber63 and off12. Native uses52 status/pad lamps. Paired startup sends only documented temporary reset B0/0/0, X-Y selection B0/0/1 and simple buffer0 B0/0/32. Reset clears all LEDs and returns volatile settings to power-on values. Shutdown and partial-startup abort attempt the same reset. Previous volatile layout/brightness/buffer state is not restored. No identity challenge, firmware, authentication, bootloader ID/power mode or stored setting is written. Advanced guide says low-power mode is default and permits iPad bus power; full-power mode needs a separate powered hub. Outer buttons, drum layout, advanced colour/buffering/animation/brightness, complete lifecycle/recovery and physical/iPad/A10X acceptance remain open. No original Launchpad, Mini, MK2, X or Pro protocol is inherited.'}}


def launchpad_s_profiles():
    """Apply the existing native grid using independently documented S addresses."""
    p = profile('Novation Launchpad S', LAUNCHPAD_S_SOURCE)
    p.update(definition='manufacturer:launchpad-s-native-grid', role='accessory',
        excludedAliases=['Launchpad', 'Launchpad Mini', 'Launchpad Mini MK3', 'Launchpad MK2', 'Launchpad X', 'Launchpad Pro', 'Launchpad Pro MK3'],
        hardwareMode='Use Launchpad S USB MIDI. Native temporarily resets LEDs/settings, selects X-Y layout and buffer0, then resets at shutdown. Close other controller software. A/B are below; C/D above require app opt-in. iPad bus power requires low-power mode; full-power mode requires a powered hub.',
        scope='Automatic64-pad native four-quadrant accessory and52 two-colour status/pad lamps. Outer buttons, other layouts, complete lifecycle and physical acceptance remain open.',
        startup=[[176, 0, 0], [176, 0, 1], [176, 0, 32]], shutdown=[[176, 0, 0]], startupAbort=[[176, 0, 0]],
        gaps=[LAUNCHPAD_S_REFERENCES['Novation Launchpad S']['review']])
    add_native_dj_grid(p, [[16 * (7 - y) + x for x in range(8)] for y in range(8)])
    for lamp in p['outputs']:
        lamp.update(onValue=15 if lamp['action'].startswith('cuePreview') else 63 if lamp['action'].startswith(('sync', 'hotcue')) else 60, offValue=12)
    return [p]

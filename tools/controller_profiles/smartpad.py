"""Independent MIDIPLUS SmartPAD default Clip grid without unqualified held contacts."""
from curated import profile
from native_dj_grid import add_native_dj_grid

SMARTPAD_SOURCE = 'https://www.midiplus.com.tw/cn/MIDIPLUS-Download-detail/0/Manual_Of_SmartPAD_EN/'
SMARTPAD_REVISION = '00f456de31492c35fa2808d2e1b46bf069ca516b'
SMARTPAD_REFERENCES = {'MIDIPLUS SMARTPAD': {
    'url': SMARTPAD_SOURCE, 'sha256': '7e515ff39d0a1fe08fce82d9c459f7b9fd295a8127fe3e9a12a0a2640ab3d844',
    'files': [
        {'cachePath': 'TestBuilds/r443/upstream/smartpad-manual.pdf', 'sha256': '7e515ff39d0a1fe08fce82d9c459f7b9fd295a8127fe3e9a12a0a2640ab3d844'},
        {'cachePath': 'TestBuilds/r443/upstream/smartpad-owner-README.md', 'sha256': 'd59ec13abb034986486770e5666c3d258a510174e3e3cbe175ee40ff1d71a6eb'},
        {'cachePath': 'TestBuilds/r443/upstream/smartpad-owner-notes.txt', 'sha256': 'd6a85377bb4a26ba987feffae36a17841862e745ba7b4d885e943946bdcc6f15'},
        {'cachePath': 'TestBuilds/r443/upstream/smartpad-owner-review.txt', 'sha256': 'e4c3528dbc0b212cbc69611006850225e6a2c442bd9dac36169e1a8a87abbd07'}],
    'relatedSources': [
        {'url': f'https://raw.githubusercontent.com/s0len0id/smartpad-tester/{SMARTPAD_REVISION}/notes/smartpad.txt'},
        {'url': f'https://raw.githubusercontent.com/s0len0id/smartpad-tester/{SMARTPAD_REVISION}/README.md'},
        {'url': f'https://raw.githubusercontent.com/s0len0id/smartpad-tester/{SMARTPAD_REVISION}/notes/amazon-review.txt'},
        {'url': 'https://www.midiplus.com/html/smartpad.html'}],
    'review': 'Own MIDIPLUS SmartPAD manual001/v1.2/May2019 documents default Clip mode, channel1 NoteOn90/NoteOff80, top row0..7, second row16..23 and bounds00..77hex. Independent pinned factory-hardware owner notes and preserved firsthand review confirm all eight rows, top-to-bottom16*y+x. The old owner notes reverse NoteOn/NoteOff status labels; the manufacturer status bytes are authoritative. Native reuses only app functions with these independent addresses. Sixty automatic non-momentary inputs provide A/B below and C/D above: Play, Sync, Load, PFL, Loop In/Out, Reloop and eight Hot Cues per quadrant. C/D require app opt-in. Four main Cue cells remain unmapped because mode buttons do not reliably send MIDI and Set mode shares CCs with encoders, leaving held-release ownership unqualified. Release pads before changing hardware mode. Mode1/channel2, Mode2/channel3, Set/encoder CCs, right-side scene buttons, other firmware, paging and full lifecycle remain inactive/unqualified. No Ableton handshake or host scroll offset is sent; use factory firmware/default Clip and close other controller hosts. The manufacturer requires NoteOff before a colour change; owner evidence distinguishes pre0.15 LED behaviour and a differing velocity palette. No guessed or single-packet colour output runs. Full feedback, mode/source ownership, saved state, USB/OS/power and physical/iPad/A10X acceptance remain open. SmartPAD II and replacement KIKPAD/CleverPad firmware are separate. No setup, reset, output, preset, driver, firmware or audio route is sent.'}}


def smartpad_profiles():
    """Return the documented default Clip grid and omit unresolved momentary controls."""
    p = profile('MIDIPLUS SMARTPAD', SMARTPAD_SOURCE)
    p.update(definition='reviewed:smartpad-clip-grid', role='accessory',
        aliases=['MIDIPLUS SMARTPAD', 'SmartPAD'], excludedAliases=['SmartPAD II', 'MIDIPLUS SmartPAD II', 'KIKPAD', 'CleverPad'],
        hardwareMode='Use factory firmware and default Clip mode. Close other controller hosts. A/B use the lower quadrants; C/D use the upper quadrants with app opt-in. The four main Cue cells stay inactive. Release pads before changing mode. No encoder, scene, paging, light or audio setup is sent.',
        scope='Automatic60-input default Clip accessory grid: Play, Sync, Load, PFL, manual loop controls and eight Hot Cues per deck. Main Cue, other modes, encoders, feedback and full lifecycle remain open.',
        gaps=[SMARTPAD_REFERENCES['MIDIPLUS SMARTPAD']['review']])
    add_native_dj_grid(p, [[16 * (7 - y) + x for x in range(8)] for y in range(8)])
    p['inputs'] = [r for r in p['inputs'] if not r['action'].startswith('cuePreview')]
    p['outputs'] = []
    return [p]

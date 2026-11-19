"""MPD218 chroma10 factory facts and explicit native pad/knob assignments."""
from curated import add, profile

MPD218_FACTORY = 'https://cdn.inmusicbrands.com/akai/MPD218-FactoryPresets.zip'
MPD218_FORMAT = 'https://raw.githubusercontent.com/mungewell/mpd-utils/4d9dedf300ff1b87068559cc04c361af8b9bb298/mpd218.py'
MPD218_REFERENCES = {'Akai MPD218': {
    'url': MPD218_FACTORY, 'sha256': 'ef623408677661bb8a4321fee0842254a200351fbcc4bedd6955e7b5d4b9e598',
    'files': [{'cachePath': 'TestBuilds/r432/upstream/mpd218-factory.zip', 'sha256': 'ef623408677661bb8a4321fee0842254a200351fbcc4bedd6955e7b5d4b9e598'}, {'cachePath': 'TestBuilds/r432/upstream/mpd218-factory/MPD218 - Factory Presets/Preset1-chroma10.mpd218', 'sha256': '6119dcfb3946f6e9a24aaf05b1b40f0e38403f2d37c28999327b43e6586959e6'}, {'cachePath': 'TestBuilds/r432/upstream/mpd218-pinned.py', 'sha256': '508cd1640b1733fe2670301aeda609158e6db2b7cc9360a974bc2b07418c8668'}, {'cachePath': 'TestBuilds/r432/upstream/mpd218-bitwig.zip', 'sha256': '8a927aa10cb07a2b5ce370fb0cf04c22462b92ebe283b9c3bd59eca0bfd74195'}, {'cachePath': 'TestBuilds/r432/upstream/mpd-bitwig/MPD2 Series v1.0.2/MPD218.control.js', 'sha256': '40359f89cbfda0487b58c9a68b8d4a35347734a2471d0872be994d5ab470f2da'}, {'cachePath': 'TestBuilds/r432/upstream/mpd218-guide.pdf', 'sha256': '72bf5f3ae6d3f2266b07875ba175f7b5da3d1653f6f5dc00c6b7d568d3be608b'}],
    'archiveMember': 'MPD218 - Factory Presets/Preset1-chroma10.mpd218',
    'relatedSources': [{'url': 'https://www.akaipro.com/downloads-and-support/downloads/?product=MPD218'}, {'url': MPD218_FORMAT}, {'url': 'https://cdn.inmusicbrands.com/akai/MPD218/MPD2Seriesv1.0.2.zip_1a67b95b5f13097447d8d3a771d8a77a.zip'}, {'url': 'https://cdn.inmusicbrands.com/akai/attachments/MPD218/MPD218-UserGuide-v1.0.pdf'}],
    'review': 'Own manufacturer factory archive qualifies preset1 chroma10. Independently documented MPD218 file fields corroborate all48 Note-type momentary pads on channel10, Notes36..83, and18 ordinary CC knobs on channel1 with ranges0..127. No preset file or decoder code executes. Own Bitwig member independently identifies MPD218/MPD218 Port A and its channel10 pad stream. Native assigns Pad Banks A/B/C to app A/B/C. Each16-note bank gives eight Hot Cues, Play, held Cue, Sync, Load, Loop In/Out, Reloop and Key Lock. Six knobs per native deck assign gain/high/mid/low/level/filter. Pad and knob banks remain independent. A new mapped pad bank retires only its source and rearms pad buttons while preserving knob pickup. Both release forms retain old addresses. A standalone bank/preset-selector report is not qualified; held controls await original release or next mapped bank report. Use preset1, momentary notes and Note Repeat off. Other presets, toggle/program/bank types, pressure/repeat/tempo, preset lifecycle/recovery, LEDs, USB/OS/power and physical/iPad/A10X acceptance remain open. The guide requires holding Note Repeat during iOS connection, then releasing it. No stored preset, tempo, driver, firmware, source script, device reset, identity probe, output or audio route is written. MPD226/232 and MPK protocols stay separate.'}}


def mpd218_profiles():
    """Map only the independently qualified preset1 footprint to native controls."""
    p = profile('Akai MPD218', MPD218_FACTORY)
    p.update(definition='reviewed:mpd218-chroma10-native', role='accessory', inputProtocol='mpd218Chroma',
        aliases=['Akai MPD218', 'MPD218', 'MPD218 Port A'], excludedAliases=['MPD218 Port B', 'MPD226', 'MPD232', 'MPD18'],
        hardwareMode='Select unedited preset1 chroma10 with PROG SELECT+Pad1. Keep Note Repeat off. On iOS, hold Note Repeat while connecting, then release it. Pad and knob banks A/B/C target app A/B/C. Enable C separately. Move knobs to current app values for pickup.',
        scope='Automatic66-input preset1 native layout:48 pads and18 absolute knobs across independent three-bank controls. Full presets/modes/pressure/repeat/lifecycle/feedback remain open.', gaps=[MPD218_REFERENCES['Akai MPD218']['review']])
    for bank, deck in enumerate('abc'):
        base = 36 + 16 * bank
        for slot in range(8): add(p, f'hotcue{slot + 1}', 9, base + slot, deck=deck)
        for action, offset in [('play', 8), ('cuePreview', 9), ('sync', 10), ('load', 11), ('loopIn', 12), ('loopOut', 13), ('reloop', 14), ('keylock', 15)]: add(p, action, 9, base + offset, deck=deck)
        for action, wire in zip(['gain', 'high', 'mid', 'low', 'level', 'filterKnob'], [[3, 9, 12, 13, 14, 15], list(range(16, 22)), list(range(22, 28))][bank]): add(p, action, 0, wire, 'control', deck=deck)
    return [p]

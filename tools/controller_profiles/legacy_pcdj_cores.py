"""Independent legacy MIDI facts with explicit source corrections and limits."""
from curated import add, profile
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA
from ultramixer_recovered import normal_button

TRAK = 'Numark 4TRAK'
XPONENT = 'M-Audio Xponent'
XPONENT_GUIDE = 'https://cf3.zzounds.com/media/070907_TorqXpon_UG_EN01-ae905b8e52356e5c89a355bc137419ca.pdf'
LEGACY_PCDJ_REFERENCES = {
    TRAK: {
        'url': FOUR_SOURCE, 'sha256': FOUR_PACKAGE_SHA,
        'archiveMember': 'Applications/DEX4.app/Contents/Resources/controllers/Numark__4trak_Main.js',
        'files': [
            {'cachePath': 'TestBuilds/r301/upstream/controllers/Numark__4trak_Main.js', 'sha256': 'f9c105ffde97c3a38f98c74d80be2acb2adab3e7cf61045e8a9a3279c5e99beb'},
            {'cachePath': 'TestBuilds/r421/upstream/4trak.pdf', 'sha256': 'f6ce08498a304b977688e6272b99751f0a9d2b49b8ed14cf43cf21204d7e7821'}],
        'relatedSources': [{'url': 'https://www.numark.com/images/product_downloads/4TRAK_Quickstart_Guide_v1.1.pdf'}],
        'review': 'Own Main script qualifies four deck channels1..4, channel0 mixer, strict1/127 browse and exact0/1 side-selector CC80/81. Native keeps physical Shift identities across A/C and B/D and retires owned side contacts on either Shift edge or selector report. Normal transport and five Hot Cues use release guards. Source lamp CCs are independent of input notes. Only steady Play/Cue/key-lock/Hot Cue lamps are enabled. Source startup changes deck banks, jog mode and loop mode; native deliberately sends none of those writes. The separate FX bar is not this input. Driver/USB host, startup, paired jog calibration/contact, strip seek, conditional loops/FX, complete feedback/lifecycle/audio and physical/iPad/A10X acceptance remain open. Manual selection is required.'},
    XPONENT: {
        'url': FOUR_SOURCE, 'sha256': FOUR_PACKAGE_SHA,
        'archiveMember': 'Applications/DEX4.app/Contents/Resources/controllers/MAudio__Xponent.js',
        'files': [
            {'cachePath': 'TestBuilds/r301/upstream/controllers/MAudio__Xponent.js', 'sha256': 'be0c6b910b99252faf3d56c8463c9170fcdbfd455de3a465cbbab3d0f5f7f6b6'},
            {'cachePath': 'TestBuilds/r390/upstream/djay-documents/M-Audio Xponent.djayMidiMapping', 'sha256': '90bbefef1d963947ec914021026e0c12d31ab426bb9d82a74c44680e6da26676'}],
        'relatedSources': [{'url': XPONENT_GUIDE, 'reviewedPages': [14, 15, 16]}, {'url': 'https://www.algoriddim.com/hardware'}],
        'review': 'Manufacturer Appendix A and independent djay mapping override the PCDJ script: real Shift is Note44 per deck, not Note18, and Note44 must never load a track. Pitch uses the complete MIDI pitch-bend value with exact centre, inverted as in the djay definition. Default bank A channels0/1 and channel2 globals qualify normal transport, five Hot Cues, fixed1/2/4/8-beat loops, direct manual loops, mixer and cue-mix. Owned Note22 touch gates binary-offset CC22 jog at source scratch scale300; physical scale remains unmeasured. Native Shift suppresses unsupported alternate functions and retires held contacts. Bank B, source scratch-toggle/search, trackpad/mouse, transform, EQ kills, FX, remaining lamps/meters, complete lifecycle/host/audio/OS and physical/iPad/A10X acceptance remain open. No source code, driver, setup or stored setting runs. Manual selection is required.'}}


def legacy_pcdj_profiles():
    """Return bounded native mappings without executing publisher actions."""
    trak = profile(TRAK, FOUR_SOURCE)
    trak.update(definition='reviewed:legacy-pcdj-4trak', autoSelect=False,
        aliases=[TRAK, 'Numark 4Trak', '4TRAK', 'Numark 4TRAK MIDI'], excludedAliases=['Numark 4TRAK FX', '4TRAK FX', 'Numark NS6', 'Numark NS6II'],
        hardwareMode='Select the main 4TRAK MIDI input manually. Enable C/D separately. Keep the mixer in its software configuration and configure app audio separately.',
        scope='Manual four-deck normal transport, held Cue/bends, five Hot Cues, coarse pitch, mixer and library. Explicit side selectors retire owned contacts.',
        gaps=[LEGACY_PCDJ_REFERENCES[TRAK]['review']])
    for i, deck in enumerate('abcd'):
        ch = i + 1
        add(trak, 'shift', ch, 18); trak['inputs'][-1]['shiftInput'] = i % 2
        side = ['a', 'c'] if i % 2 == 0 else ['b', 'd']
        trak.setdefault('bankChanges', []).append({'channel': ch, 'number': 18, 'anyPositive': True, 'decks': side, 'releaseShiftChannels': []})
        buttons = [('play', 17), ('cuePreview', 16), ('sync', 15), ('keylock', 45), ('pitchBendDown', 24), ('pitchBendUp', 25), ('load', 6), ('load', 7)]
        buttons += [(f'hotcue{j+1}', 19+j) for j in range(5)]
        for action, number in buttons: normal_button(trak, action, ch, number, deck)
        add(trak, 'tempo', ch, 1, 'control', deck=deck); trak['inputs'][-1]['inverted'] = True
        for action, numbers in [('level', [8, 13, 19, 24]), ('gain', [12, 17, 23, 28]), ('high', [11, 16, 22, 27]), ('mid', [10, 15, 21, 26]), ('low', [9, 14, 20, 25])]:
            add(trak, action, 0, numbers[i], 'control', deck=deck)
        add(trak, 'cue', 0, 49+i, deck=deck)
        for action, number in [('play', 9), ('cuePreview', 8), ('keylock', 23)] + [(f'hotcue{j+1}', 11+j) for j in range(5)]:
            trak['outputs'].append({'action': action + ('A' if deck in 'ac' else 'B'), 'targetDeck': deck, 'kind': 'control', 'channel': ch, 'number': number, 'onValue': 127, 'offValue': 0, 'offUsesNoteOn': False})
    for number, decks in [(80, ['a', 'c']), (81, ['b', 'd'])]:
        for value in [0, 1]: trak['bankChanges'].append({'kind': 'control', 'channel': 0, 'number': number, 'onValue': value, 'decks': decks})
    for action, number in [('crossfader', 7), ('cueMix', 18), ('monitor', 66), ('master', 67)]: add(trak, action, 0, number, 'control')
    add(trak, 'browse', 0, 68, 'control', 'signedStep'); add(trak, 'openGroup', 0, 8)

    x = profile(XPONENT, FOUR_SOURCE)
    x.update(definition='reviewed:legacy-pcdj-xponent', autoSelect=False,
        aliases=[XPONENT, 'M-AUDIO XPONENT', 'Xponent', 'Torq Xponent'], excludedAliases=['M-Audio X-Session', 'X-Session Pro'],
        hardwareMode='Select Xponent manually with Bank A selected. Native Shift has no destructive alternate commands. Configure app audio separately. Wheel movement requires owned contact.',
        scope='Manual default-bank two-deck transport, five Hot Cues, fixed/manual loops, full pitch position, fixed touch/jog, mixer and cue-mix.',
        gaps=[LEGACY_PCDJ_REFERENCES[XPONENT]['review']])
    for ch, deck in enumerate('ab'):
        add(x, 'shift', ch, 44); x['inputs'][-1]['shiftInput'] = ch
        x.setdefault('bankChanges', []).append({'channel': ch, 'number': 44, 'anyPositive': True, 'decks': [deck], 'releaseShiftChannels': []})
        buttons = [('play', 36), ('cuePreview', 35), ('sync', 2), ('keylock', 30), ('cue', 20), ('pitchBendDown', 16), ('pitchBendUp', 17), ('loopIn', 41), ('loopOut', 43), ('loop', 42), ('loopUp', 31), ('loopDown', 32)]
        buttons += [(f'hotcue{j+1}', 23+j) for j in range(5)]
        for action, number in buttons: normal_button(x, action, ch, number, deck, feedback=action in ['play', 'cue'] or action.startswith('hotcue'))
        add(x, 'jogTouch', ch, 22, deck=deck)
        add(x, 'jog', ch, 22, 'control', 'binaryOffset', deck); x['inputs'][-1].update(argument=300, requiresTouch=True)
        add(x, 'tempo', ch, 0, 'pitch', 'centredPitch', deck); x['inputs'][-1]['inverted'] = True
        for action, number in [('level', 7), ('low', 8), ('mid', 9), ('high', 10), ('gain', 11)]: add(x, action, ch, number, 'control', deck=deck)
        for number, beats in enumerate([1, 2, 4, 8], 37):
            add(x, 'toggleFixedLoop', ch, number, deck=deck); x['inputs'][-1].update(argument=beats, shifted=False)
    add(x, 'crossfader', 2, 7, 'control'); add(x, 'cueMix', 2, 13, 'control')
    return [trak, x]

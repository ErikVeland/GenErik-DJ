"""Independent PMX-10 manufacturer MIDI facts, including its explicit feedback limit."""
from curated import add, profile

PMX10_SOURCE = 'https://www.geminisound.com/cdn/shop/files/PMX10_Manual.pdf?v=3857980637559190502'
PMX10_REFERENCES = {'Gemini PMX10': {
    'url': PMX10_SOURCE, 'sha256': '3219e8110efe8f567122b1adb7b2263f8768e9f88f583bb299ac5ad85b7644c1',
    'files': [{'cachePath': 'TestBuilds/r446/upstream/pmx10-manual.pdf', 'sha256': '3219e8110efe8f567122b1adb7b2263f8768e9f88f583bb299ac5ad85b7644c1'}],
    'relatedSources': [{'url': 'https://www.geminisound.com/pages/downloads'}],
    'review': 'Own manufacturer PMX-10 manual p8/p9 visually reviewed. Independent raw0/1 Hot Cue notes8..1, distinct Sample09..0F/20hex, Loop35, PFL50 and mixer Level49/Filter51/Low52/Mid53/High54/Gain55 are explicit. Globalraw4 Load64/65, directory push66, Back67, Master80, Cue Blend83, Cue Level84 and Crossfader96 are separately qualified. Native assigns Back to previous library group. Mode selectors33/34 rearm only their source/deck. No transport is inferred from another control. Nineteen optional static lamps:16 green1 Hot Cues, two on1 Loop and one on1 PFL-B, all off0. CH1 PFL MIDI Input is explicitly None in the own chart, so PFL-A feedback stays inactive. No PMX20 lamp, C/D, preset, SysEx or mode assumption is inherited. Loop-size/browse encoders are only labelled Relative without a byte encoding and stay inactive. Sampler/FX, fader start/reverse/curves, mic/booth and output Pad Mode CC40hex remain inactive. Manual input requires separately qualified Controller mode and audio ownership: the own manual selects Mixer without a host, Hybrid with another audio interface, and Controller with the PMX-10 audio interface selected. Native does not configure or discover those audio modes. Automatic selection, complete mode/source/feedback/lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. No setup, reset, query, persistent mode, preset, driver, firmware or audio-route packet runs.'}}


def pmx10_profiles():
    """Return the independently documented two-deck manual subset and nineteen lamps."""
    p = profile('Gemini PMX10', PMX10_SOURCE)
    p.update(definition='reviewed:pmx10-manufacturer-core', role='accessory', autoSelect=False,
        aliases=['Gemini PMX10', 'Gemini PMX-10', 'PMX10', 'PMX-10'], excludedAliases=['Gemini PMX20', 'PMX-20', 'PMX20'],
        hardwareMode='Enable this manual profile separately. Controller mode requires the PMX-10 audio interface selected by the host. Audio routing and hardware ownership need separate qualification. Select Hot Cues for the pads. Back selects the previous library group. Encoders, sampler/FX and Pad Mode output remain inactive.',
        scope='Manual40-input two-deck manufacturer subset with16 Hot Cues, Loop, mixer/PFL, Load, directory entry/previous group and four global controls. Nineteen optional static lamps. CH1 PFL feedback, relative encoders, modes/audio and full lifecycle remain open.',
        bankChanges=[{'channel': ch, 'number': n, 'anyPositive': True, 'decks': [deck]}
            for ch, deck in enumerate('ab') for n in [33, 34]],
        gaps=[PMX10_REFERENCES['Gemini PMX10']['review']])
    for ch, deck in enumerate('ab'):
        for slot in range(8): add(p, f'hotcue{slot + 1}', ch, 8 - slot, deck=deck, feedback=True)
        add(p, 'loop', ch, 35, deck=deck, feedback=True)
        add(p, 'cue', ch, 50, deck=deck, feedback=ch == 1)
        for action, n in [('level', 49), ('filterKnob', 51), ('low', 52), ('mid', 53), ('high', 54), ('gain', 55)]:
            add(p, action, ch, n, 'control', deck=deck)
        add(p, 'load', 4, 64 + ch, deck=deck)
    add(p, 'openGroup', 4, 66)
    add(p, 'browsePreviousGroup', 4, 67); p['inputs'][-1]['pulse'] = True
    for action, n in [('crossfader', 96), ('master', 80), ('monitor', 84), ('cueMix', 83)]: add(p, action, 4, n, 'control')
    for lamp in p['outputs']: lamp['onValue'] = 1
    return [p]

"""Own DJ-202 hardware-owner facts with a bounded native normal MIDI subset."""
from curated import add, profile

DJ202_XML = 'https://gist.githubusercontent.com/upCASE/c8dace3e70d565a4b1178f7013d3d738/raw/4517327e37ba39deb18f31f83f9039cc1a072cb3/Roland_DJ-202.midi.xml'
DJ202_JS = 'https://gist.githubusercontent.com/upCASE/88fb258e85546092af18bc3ff924f752/raw/7df847d6bd717d4cc5ef6daa1bd7c1e4f603ed4d/Roland_DJ-202-scripts.js'
DJ202_REFERENCES = {'Roland DJ-202': {
    'url': DJ202_XML, 'sha256': 'c95e3ad4a59ed9c92d39e28f207dd9ae1350796e3adcd237c0409822b3f917d9',
    'files': [{'cachePath': 'TestBuilds/r436/upstream/Roland_DJ-202.midi.xml', 'sha256': 'c95e3ad4a59ed9c92d39e28f207dd9ae1350796e3adcd237c0409822b3f917d9'}, {'cachePath': 'TestBuilds/r436/upstream/Roland_DJ-202-scripts.js', 'sha256': '3c441d08ef4114d994b18a05e42b3797d371271204c90ee977a60c480fdbb33c'}],
    'relatedSources': [{'url': DJ202_JS, 'sha256': '3c441d08ef4114d994b18a05e42b3797d371271204c90ee977a60c480fdbb33c'}, {'url': 'https://github.com/mixxxdj/mixxx/wiki/Roland-Dj-202'}, {'url': 'https://github.com/mixxxdj/mixxx/issues/11497'}],
    'review': 'Separate hardware-owner DJ-202 XML and script qualify a manual normal MIDI subset. These are community observations, not a manufacturer SDK. XML independently defines four deck channels0..3: Play0, held Cue1, Sync2 and Key Lock13 with shifted4/5/3/14; global Shift is channel15 Note0. Native normal transport is Shift-guarded. Shifted and opposite-bank release aliases preserve ownership and debounce. Explicit14-bit pairs are tempo9/59, gain22/52, high23/53, mid24/54, low25/55 and level28/58. XML is authoritative for EQ input addresses: script constructor placeholders differ from the actual mapped pairs. Script sets rate_dir=-1; native tempo polarity is inverted and guarded because shifted tempo changes key pitch. FilterCC26 and PFLNote27 remain separate. Own loop channels4..7 use In21, Out22 and toggle24, unlike DJ-505 loop numbers. Native uses explicit loop semantics. Reloop-and-stop23 remains inactive. Browser channel15CC0 accepts only127 previous/1 next and is Shift-guarded. Shared Load ownership, crossfader maximum16368 calibration, deck-switch software state, jog/contact, pads/FX/TR-S, full Shift modes and feedback remain open. Native emits neither the source initial-state/pad-unlock SysEx nor a driver/preset/firmware/audio write. Generic USB mode may require a saved hardware selection; no zero-config claim is made. Complete startup/shutdown/recovery, routing and physical/iPad/A10X acceptance remain open. DJ-505/DJ-808 contracts stay separate.'}}


def dj202_profiles():
    """Map only the independently reviewed normal inputs without device-mode writes."""
    p = profile('Roland DJ-202', DJ202_XML)
    p.update(definition='reviewed:roland-dj202', autoSelect=False,
        excludedAliases=['DJ-505', 'DJ-808'],
        hardwareMode='Manual normal MIDI subset. Expose DJ-202 USB MIDI and select this profile manually. Generic USB mode may require a saved hardware setting. C/D require app opt-in. Full deck-switch ownership, software-mode setup and audio routing remain open.',
        scope='Manual110-input four-target normal transport, explicit paired tempo/gain/EQ/level, filter/PFL, own loop buttons and strict library steps. Full modes/jog/pads/feedback/lifecycle remain open.', gaps=[DJ202_REFERENCES['Roland DJ-202']['review']])
    add(p, 'shift', 15, 0)
    for channel, deck in enumerate('abcd'):
        for action, number, shifted in [('play', 0, 4), ('cuePreview', 1, 5), ('sync', 2, 3), ('keylock', 13, 14)]:
            add(p, action, channel, number, deck=deck); p['inputs'][-1]['shifted'] = False
            add(p, action, channel, shifted, deck=deck); p['inputs'][-1]['releaseOnly'] = True
            for release in [number, shifted]:
                add(p, action, (channel + 2) % 4, release, deck=deck); p['inputs'][-1]['releaseOnly'] = True
        for action, number, low in [('tempo', 9, 59), ('gain', 22, 52), ('high', 23, 53), ('mid', 24, 54), ('low', 25, 55), ('level', 28, 58)]:
            add(p, action, channel, number, 'control', 'paired14Bit', deck); p['inputs'][-1]['lowNumber'] = low
            if action == 'tempo': p['inputs'][-1].update(inverted=True, shifted=False)
        add(p, 'filterKnob', channel, 26, 'control', deck=deck)
        add(p, 'cue', channel, 27, deck=deck)
        for action, number in [('loopIn', 21), ('loopOut', 22), ('reloop', 24)]: add(p, action, channel + 4, number, deck=deck)
    add(p, 'browse', 15, 0, 'control', 'signedStep'); p['inputs'][-1]['shifted'] = False
    return [p]

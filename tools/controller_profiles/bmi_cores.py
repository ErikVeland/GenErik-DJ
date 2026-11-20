"""Separate bounded Beyond Music input and lamp facts from public factory mappings."""
from curated import add, profile
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA

BMI_REFERENCES = {}
for model, digest in [(1, 'a86abafd09b8147d5476aaf2cbf052fcb2ac65264d89e676a721e5c84da50f45'), (3, 'db5c111cd25cea59b435a9e9fd872e1b84965e596f0b8eec8eb0e73e51983e05')]:
    member = f'Beyond__Abma{model}.js'
    BMI_REFERENCES[f'BeyondMusic (BMI) ABMA{model}'] = {'url': FOUR_SOURCE, 'sha256': FOUR_PACKAGE_SHA,
        'archiveMember': 'Applications/DEX4.app/Contents/Resources/controllers/' + member,
        'files': [{'cachePath': 'TestBuilds/r301/upstream/controllers/' + member, 'sha256': digest}],
        'review': 'Own separate public factory member qualifies normal transport, three Hot Cues, bends, key lock, PFL, loop controls, six mixer/pitch axes per deck, inverted crossfader, Cue mix and relative browser/wheel facts. Native uses channel1 and330-count wheel bend without software Scratch mode. Loop In/Out/Reloop use native independent anchors and loop state, not copied conditional software actions. Both source browser switches open groups. ' +
            ('Only this member explicitly uses deckCue on51/60 and monitor gainCC34. It also handles both standard NoteOn/Off statuses. ' if model == 3 else 'This member uses CuePlay/SetCue software commands, not held deckCue. Its Cue/CUP keys stay inactive. It has no monitor gainCC34. ') +
            'Each own output map qualifies different NoteOn127/0 lamp addresses for Play/PFL/three Hot Cues/loop state, plus ABMA3 Cue. No guessed Sync/key lamps or position strips. Source identity uses VID/PID/SysEx rather than a distinct port name. Native does not perform those probes. Manual selection and separate app audio are required. Copied JB Systems comments do not qualify any JB model. ABMA4, shared ABMA USB names, needle positions, relative cutoff curves, Scratch-mode toggles/contact, Clear/CUP/FX/reverse, full lifecycle/state/USB/OS/audio and physical/iPad/A10X acceptance remain open. No mapping action, startup reset, sleep, driver, firmware, stored preset or vendor program runs.'}


def bmi_profiles():
    """Return independent manual native assignments without copied conditional actions."""
    result = []
    for model in [1, 3]:
        name = f'BeyondMusic (BMI) ABMA{model}'; ref = BMI_REFERENCES[name]
        p = profile(name, ref['url'])
        p.update(definition=f'reviewed:bmi-abma{model}-normal', autoSelect=False,
            aliases=[name, f'Beyond Music ABMA{model}', f'ABMA{model}'],
            excludedAliases=['ABMA USBAUDIO', 'JB Systems DJ-KONTROL 2', 'JB Systems DJ-KONTROL 3', 'Beyond Music Abm4'],
            hardwareMode='Select this model manually. Native uses normal MIDI channel1 controls,330-count wheel bend and separate app audio. Software Scratch/FX/needle and copied vendor actions stay inactive.',
            scope='Manual normal transport, three Hot Cues per deck, bends, key lock, PFL, native loops, mixer/pitch and library. Only ABMA3 includes held Cue and headphone volume.', gaps=[ref['review']])
        for deck, buttons, axes, wheel, pads, fixed, lamps in [
            ('a', [67, 64, 75, 56, 85, 121, 120, 73, 74, 112, 114, 113], [8, 13, 16, 18, 20, 11], 25, [115, 116, 117], [109, 110, 111], [37, 101, 26, 25, 24, 45]),
            ('b', [76, 71, 52, 63, 86, 104, 103, 77, 78, 95, 97, 96], [9, 14, 17, 19, 21, 12], 24, [98, 99, 100], [92, 93, 94], [84, 97, 73, 72, 71, 92])]:
            for action, wire in zip(['play', 'sync', 'load', 'keylock', 'cue', 'pitchBendDown', 'pitchBendUp', 'loopIn', 'loopOut', 'reloop', 'loopDown', 'loopUp'], buttons): add(p, action, 0, wire, deck=deck)
            for slot, wire in enumerate(pads): add(p, f'hotcue{slot + 1}', 0, wire, deck=deck)
            for beats, wire in zip([2, 4, 8], fixed):
                add(p, 'fixedLoop', 0, wire, deck=deck); p['inputs'][-1]['argument'] = beats
            for action, wire in zip(['level', 'gain', 'high', 'mid', 'low', 'tempo'], axes): add(p, action, 0, wire, 'control', deck=deck)
            add(p, 'wheelJog', 0, wheel, 'control', 'twosComplement', deck); p['inputs'][-1]['argument'] = 330
            for action, wire in zip(['play', 'cue', 'hotcue1', 'hotcue2', 'hotcue3', 'loop'], lamps):
                p['outputs'].append({'action': action + deck.upper(), 'kind': 'note', 'channel': 0, 'number': wire, 'targetDeck': deck, 'onValue': 127, 'offValue': 0, 'offUsesNoteOn': True})
            if model == 3:
                add(p, 'cuePreview', 0, 51 if deck == 'a' else 60, deck=deck)
                p['outputs'].append({'action': 'cuePreview' + deck.upper(), 'kind': 'note', 'channel': 0, 'number': 41 if deck == 'a' else 88, 'targetDeck': deck, 'onValue': 127, 'offValue': 0, 'offUsesNoteOn': True})
        add(p, 'crossfader', 0, 10, 'control'); p['inputs'][-1]['inverted'] = True
        add(p, 'cueMix', 0, 32, 'control')
        if model == 3: add(p, 'monitor', 0, 34, 'control')
        add(p, 'browse', 0, 26, 'control', 'twosComplement')
        for wire in [79, 91]: add(p, 'openGroup', 0, wire)
        result.append(p)
    return result

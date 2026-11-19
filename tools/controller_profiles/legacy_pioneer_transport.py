"""Independent T1 three-layer and MEP7000 speed/transport manufacturer facts."""
from curated import add, profile

LEGACY_PIONEER_TRANSPORT_REFERENCES = {
    'Pioneer DJM-T1': {
        'url': 'https://downloads.support.alphatheta.com/manuals/dj-mixers/DJM-T1/DJM-T1_DRB1610_manual.pdf',
        'cacheName': 'djmt1-manual.pdf', 'sha256': 'd26c7844ca00be4f601f2a16d6f6841d2ba382902af865cd42712820937fef45', 'pages': [23, 24, 26, 27, 28, 29],
        'review': 'Current manufacturer manual pages28/29 were visually reviewed. Note C-1 is0; CC labels are decimal. It explicitly lists normal, Shift and Advanced Shift wires. The manual60-input native core retains selected mixer fields across all three layers, four base Hot Cues, base transport/loops, normal/Shift library controls and shifted/advanced release-only Cue aliases. Fourteen base transport/Sync/Cue/pad lamps have documented0/127 outputs. Generic Controller Mode must be ON, both mixer MIDI buttons enabled and MIDI channel1 selected. Hardware mode/configuration is manual. Dual crossfader attenuation outputs are not one physical-position wire and stay inactive. Native Hot Cue deletion, FX/sampler/LFO, Advanced Shift functions, complete mode/audio/lifecycle/calibration and physical/iPad/A10X acceptance remain open.'},
    'Pioneer MEP-7000': {
        'url': 'https://downloads.support.alphatheta.com/manuals/dj-players/MEP-7000/MEP-7000_DRB1467B_manual.pdf',
        'cacheName': 'mep7000-manual.pdf', 'sha256': '415c872bf9e81175ba345cc3032f555b7bf3d0f6e099f8baa0cd180318485a79', 'pages': [57, 58, 59, 60],
        'review': 'Manufacturer tables59/60 were visually reviewed. Its jog is absolute speed:64 stopped,65/63 approximately+/-0.06x,127/0 at+/-4x. This independently matches the existing cdjPlatterSpeed decoder, not a relative counter. Tempo is0 at minus and127 at plus with64 centre. Page58 fixes default A/centre channel1 and B channel2. Direct Load A/B, browse and encoder press are not grey mode-only rows. PC selection and Load establish computer control in Normal Style; Manipulator Style also sends these wires. Native automatically selects the26-input core when the named MIDI source is exposed. Source mode entry, full modes, search/memory, display/lamps, external audio and physical/iPad/A10X calibration/acceptance remain open. No SEP-C1 or CDJ sibling protocol is inherited.'},
}


def legacy_pioneer_transport_profiles():
    result = profile('Pioneer DJM-T1', LEGACY_PIONEER_TRANSPORT_REFERENCES['Pioneer DJM-T1']['url'])
    result.update(autoSelect=False, definition='reviewed:djm-t1-independent-three-layer-core',
                  excludedAliases=['DDJ-T1', 'DJM-S3', 'DJM-2000'],
                  hardwareMode='Manual MIDI channel1; Generic Controller Mode ON; both mixer CH1/CH2 MIDI buttons enabled. Use Hot Cue rather than Sampler mode. Advanced Shift requires firmware2.00. Configure audio separately and avoid duplicate hardware/software processing.',
                  scope='Manual60-input T1 core: three-layer native gain/EQ/level, normal/Shift browse, base load/play/Cue/Sync/loop/four Hot Cues and fourteen documented base lamps. Shifted/advanced Cue wires release an existing preview only.',
                  gaps=['Dual crossfader attenuation wires are not a qualified single position and stay inactive. Native Hot Cue delete, sampler/FX/LFO, other Shift/Advanced Shift functions, complete mode handling/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open.'])
    for index, deck in enumerate('ab'):
        for action, number in [('load', 1 + index), ('play', 3 + index), ('sync', 5 + index), ('cuePreview', 11 + index)]:
            add(result, action, 0, number, deck=deck, feedback=action != 'load')
        for number in [75 + index, 125 + index]:
            add(result, 'cuePreview', 0, number, deck=deck)
            result['inputs'][-1]['releaseOnly'] = True
        for layer in [0, 64, 76]:
            for action, number in [('gain', 13), ('high', 15), ('mid', 17), ('low', 19), ('level', 21)]:
                add(result, action, 0, number + index + layer, 'control', deck=deck)
        add(result, 'cue', 0, 47 + index, deck=deck)
        for slot in range(4):
            add(result, f'hotcue{slot + 1}', 0, 27 + 2 * index + 4 * slot, deck=deck, feedback=True)
        add(result, 'loop', 0, 21 + 2 * index, deck=deck)
        add(result, 'loopSize', 0, 9 + 2 * index, 'control', 'twosComplement', deck)
    add(result, 'browse', 0, 0, 'control', 'twosComplement')
    add(result, 'browseGroups', 0, 64, 'control', 'twosComplement')
    for number in [0, 64]:
        add(result, 'openGroup', 0, number)
    mep = profile('Pioneer MEP-7000', LEGACY_PIONEER_TRANSPORT_REFERENCES['Pioneer MEP-7000']['url'])
    mep.update(definition='reviewed:mep-7000-independent-speed-transport-core',
               aliases=['Pioneer MEP-7000', 'MEP-7000', 'MEP-7000 MIDI', 'Pioneer DJ MEP-7000'],
               excludedAliases=['SEP-C1', 'CDJ-700', 'CDJ-2000'],
               hardwareMode='Default MIDI channels: A/centre1, B2. Normal Style: select PC then LOAD A/B for computer control. Manipulator Style also supplies these messages. Hardware Scratch/Jog Break selection and audio routing remain separate.',
               scope='Automatic26-input independent two-deck core with direct loading, held Cue, absolute speed jogs, centred pitch, loop controls and library navigation. No hardware writes or inferred display/audio protocol.',
               gaps=['Source mode entry and changes, full search/memory/Jog Break modes, pitch-range feedback, lamps/screens, complete lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. No hardware output chart is published in this manual.'])
    for channel, deck in enumerate('ab'):
        for action, number in [('play', 0), ('cuePreview', 1), ('loopIn', 6), ('loopOut', 7), ('reloop', 8), ('keylock', 17), ('jogTouch', 32), ('pitchBendUp', 20), ('pitchBendDown', 21)]:
            add(mep, action, channel, number, deck=deck)
        add(mep, 'jog', channel, 16, 'control', 'cdjPlatterSpeed', deck)
        add(mep, 'tempo', channel, 29, 'control', 'cdjTempo', deck)
    for deck, number in [('a', 52), ('b', 53)]:
        add(mep, 'load', 0, number, deck=deck)
    add(mep, 'browse', 0, 79, 'control', 'twosComplement')
    add(mep, 'openGroup', 0, 51)
    return [result, mep]

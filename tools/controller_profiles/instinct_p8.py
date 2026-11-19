"""Independent P8 manufacturer wires and published factory calibration facts."""
from curated import add, profile

P8_TABLE = 'https://ts.hercules.com/download/sound/MIDI_Mapping/DJ_InstinctP8/DJControl_Instinct_P8_MIDI_Command_List.pdf'
P8_REFERENCES = {'Hercules DJControl Instinct P8': {
    'url': P8_TABLE, 'sha256': '7b94d78365244f8f77e3354ee18572d60ed95a185a4bab92e231e9b650f08b7d', 'pages': [1, 2, 3, 4, 5, 6],
    'relatedSources': [{'url': 'https://ts.hercules.com/download/djuced/6.8/DJUCED_6.8.1.dmg',
                        'sha256': 'a76200de7cc2fced9b765d83edd02c8a07aa302d77c87c81ddf2f4c91330e2a2',
                        'member': 'DJControl InstinctP8.djm', 'memberSHA256': '96f8e201cb49b47cdc09efb5b4ece662834759ba0cdd08953ab07adb0f406045', 'memberVersion': '1.7'},
                       {'url': 'https://ts.hercules.com/faqs/eng/her_eng_00492.pdf'}],
    'review': 'All six pages of the independent P8 Version1.1 manufacturer MIDI chart were visually reviewed. Current public DJUCED6.8.1 factory XML, read without execution, fixes channel0,256-count wheel/contact streams, separate touch notes, four cue keys per side, native loop-button/encoder functions and shifted mixer targets C/D. The manufacturer gives EQ0 full clockwise and127 full anticlockwise; native inverts EQ. Positive alternate transport stays inactive; release-only aliases retain ownership. Shift press/release retires only the corresponding A/C or B/D contacts/pickup. Mode press retires all four. Native uses a fine pitch position delta of count/1024 on the separate Shift-wheel wire; exact source-software range equivalence is not claimed. All four normal loop-encoder pages deliberately use native loop size; source conditional FX/loop-move functions remain open. Cue pads use documented blue125; transport/PFL use127, all off0. Startup/shutdown clear only22 selected lamp addresses. No All Controls query, mode SysEx, audio route, original Instinct/Wave/Universal protocol or full modes/lifecycle/calibration/device acceptance is inferred.'}}


def instinct_p8_profiles():
    result = profile('Hercules DJControl Instinct P8', P8_TABLE)
    result.update(definition='reviewed:hercules-instinct-p8-independent-factory-core',
                  aliases=['Hercules DJControl Instinct P8', 'DJControl Instinct P8', 'DJControl InstinctP8'],
                  excludedAliases=['DJ Control Instinct', 'DJControl Instinct', 'DJControl Instinct iPad Edition', 'Universal DJ', 'DJControlWave'],
                  hardwareMode='Default MIDI channel1 on the independently reviewed P8. Normal mixer targets A/B; Shift mixer targets C/D with app opt-in. Native uses fixed contact/wheel handling and four normal loop-encoder pages. Configure audio separately.',
                  scope='Automatic86-input independent P8 core:256-count wheel/contact jogs, native fine Shift pitch count/1024, four Hot Cues per side, loops, selected four-target mixer controls and22 bounded lamps.',
                  gaps=['FX/sampler/held roll, Hot Cue deletion, shifted loop movement and conditional FX encoder modes, source-software pitch-curve equivalence, HP buttons, complete feedback/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. No All Controls query or mode write is sent.'])
    for side, deck in enumerate('ab'):
        offset = side * 48
        add(result, 'shift', 0, 99 if side == 0 else 47)
        result['inputs'][-1]['shiftChannel'] = side
        for action, number in [('play', 33), ('cuePreview', 34), ('sync', 35)]:
            add(result, action, 0, number + offset, deck=deck, feedback=True)
            add(result, action, 0, number + offset + 3, deck=deck)
            result['inputs'][-1]['releaseOnly'] = True
            lamp = dict(result['outputs'][-1], number=number + offset + 3)
            result['outputs'].append(lamp)
        add(result, 'load', 0, 95 + side, deck=deck)
        add(result, 'cue', 0, 91 + side, deck=deck, feedback=True)
        add(result, 'cue', 0, 100 + side, deck=deck)
        result['inputs'][-1]['releaseOnly'] = True
        add(result, 'jogTouch', 0, 97 + side, deck=deck)
        add(result, 'wheelJog', 0, 48 + 2 * side, 'control', 'twosComplement', deck)
        result['inputs'][-1]['argument'] = 256
        for number in [105 + 2 * side, 106 + 2 * side]:
            add(result, 'jog', 0, number, 'control', 'twosComplement', deck)
            result['inputs'][-1].update(argument=256, requiresTouch=True)
        add(result, 'tempo', 0, 49 + 2 * side, 'control', 'fineTempo512', deck)
        result['inputs'][-1].update(shiftChannel=side, shifted=True)
        for target, delta in [(deck, 0), ('cd'[side], 1)]:
            for action, number in [('level', 64 + 2 * side), ('low', 68 + 12 * side), ('mid', 70 + 12 * side), ('high', 72 + 12 * side)]:
                add(result, action, 0, number + delta, 'control', deck=target)
                result['inputs'][-1].update(inverted=action != 'level', shiftChannel=side, shifted=delta == 1)
        for slot in range(4):
            add(result, f'hotcue{slot + 1}', 0, 1 + slot + offset, deck=deck, feedback=True)
            result['outputs'][-1]['onValue'] = 125
            add(result, f'hotcue{slot + 1}', 0, 5 + slot + offset, deck=deck)
            result['inputs'][-1]['releaseOnly'] = True
        for number in ([52, 87, 89, 97] if side == 0 else [54, 99, 101, 103]):
            add(result, 'loopSize', 0, number, 'control', 'twosComplement', deck)
        add(result, 'loop', 0, 87 + side, deck=deck)
        add(result, 'loop', 0, 89 + side, deck=deck)
        result['inputs'][-1]['releaseOnly'] = True
        for index, action in enumerate(['loopIn', 'loopOut', 'loopDown', 'loopUp']):
            add(result, action, 0, 29 + index + offset, deck=deck)
    add(result, 'crossfader', 0, 86, 'control')
    add(result, 'browse', 0, 56, 'control', 'twosComplement')
    add(result, 'master', 0, 57, 'control', 'twosComplement')
    add(result, 'openGroup', 0, 43)
    result['bankChanges'] = [{'channel': 0, 'number': number, 'onValue': 127, 'decks': decks, 'releaseShiftChannels': [side]}
                             for side, (number, decks) in enumerate([(99, ['a', 'c']), (47, ['b', 'd'])])]
    result['bankChanges'].append({'channel': 0, 'number': 48, 'onValue': 127, 'decks': list('abcd')})
    result['startup'] = [[0x90, r['number'], 0] for r in result['outputs']]
    result['shutdown'] = [list(message) for message in result['startup']]
    return [result]

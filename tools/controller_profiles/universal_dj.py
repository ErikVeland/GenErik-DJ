"""Universal DJ USB facts reconciled across separate manufacturer mappings."""
from curated import add, profile

UNIVERSAL_DJAY = 'https://ts.hercules.com/download/sound/MIDI_Mapping/UniversalDJ/DJay_Pro_Hercules_Universal_DJ.zip'
UNIVERSAL_TRAKTOR = 'https://ts.hercules.com/download/sound/TDJS/current/TP2_Uni_DJ.zip'
UNIVERSAL_REFERENCES = {'Hercules Universal DJ': {
    'url': UNIVERSAL_DJAY, 'cacheName': 'universal-djay.zip', 'sha256': '5ea31750f3032576d713afa0ec9b1e7d8f879ea3173f97e538bb5b79b3602dfc',
    'member': 'Hercules UniversalDJ.djayMidiMapping', 'memberSHA256': 'eaf80b23b1a2bad34be5a3f710996c20e8aa4a6554b2e191d3834644b8d888a2',
    'relatedSources': [{'url': UNIVERSAL_TRAKTOR, 'cacheName': 'universal-traktor.zip', 'sha256': 'b15cec7ae21b414431acc63723f615b2d9f77b7a614972a6f5f2265af92b7be9',
                        'members': {'DJ_Uni_TP2_v271(MAC).tsi': 'a4212f1e9d491a8b0c5f15d099e02e4c9b82b6e762d669691eb4e00dd616c684',
                                    'DJ_Uni_TP2_v271(PC).tsi': 'aecd87c936e532fe04316b85fadb566a11e539b6a35a841f165ce38d9ef1a716'}},
                       {'url': 'https://ts.hercules.com/download/djuced/6.8/DJUCED_6.8.1.dmg',
                        'sha256': 'a76200de7cc2fced9b765d83edd02c8a07aa302d77c87c81ddf2f4c91330e2a2',
                        'member': 'DJControlUniversal.djm', 'memberSHA256': '2bef8dc759848f85ecd94ffd04f8f1098c70f937d4034ae2277414c3497861e7', 'memberVersion': '4.1'},
                       {'url': 'https://ts.hercules.com/download/sound/manuals/Universal_DJ/Universal_DJ-MIDI_controls.pdf',
                        'sha256': '427f6bbcb0e90645c9db3d047acdf8ecd93467ef802d29bd98e64d56445f8260', 'evidenceLimit': 'Older table conflicts with current primary mappings on mixer rows and prints impossible128+ MIDI values. It is not the authority for those rows.'},
                       {'url': 'https://ts.hercules.com/faqs/eng/her_eng_00471.pdf'},
                       {'url': 'https://support.hercules.com/en/product/universaldj-en/'}],
    'review': 'Manufacturer support directly publishes both djay and Traktor archives. Their independently readable mappings agree with current DJUCED factory facts: A level57/high59/mid60/low61, B level58/high62/mid63/low64, global cross65. These override conflicting older PDF mixer rows and impossible128+ values. Used Mac/PC TSI bindings explicitly qualify pitch MSB/LSB1/33,2/34 and55/71,56/72, all inverted; no plus32 guess is used. Pinned factory XML independently qualifies512-count separate wheel/contact streams, eight cue keys, fixed loops and0/127 lamp bounds. The native layout fixes two decks, source-local touch, per-side Shift cleanup, eight Hot Cues, selected manual/fixed loops and gain encoders. Normal EQ polarity follows the manufacturer printed physical direction; physical response remains unverified. Thirty selected lamps clear in60 total lifecycle messages. No state query, software installation/execution, generic USB alias, Bluetooth/tablet transport, automatic audio route, full modes/lifecycle/calibration or physical/iPad/A10X acceptance is inferred.'}}


def universal_dj_profiles():
    result = profile('Hercules Universal DJ', UNIVERSAL_DJAY)
    result.update(definition='reviewed:hercules-universal-dj-reconciled-usb-core',
                  aliases=['Hercules Universal DJ', 'Universal DJ', 'DJHERCULESMIX Universal DJ'],
                  excludedAliases=['DJControlWave', 'DJControl Instinct P8', 'Périphérique MIDI USB'],
                  hardwareMode='USB computer MIDI mode with default deck channels1/2 and both-byte pitch reports. Fixed native A/B layout. Configure audio separately. Bluetooth and tablet transport are not qualified.',
                  scope='Automatic111-input reconciled Universal DJ USB core with two explicit pitch-pair families,512-count wheel/contact streams, per-side Shift, eight Hot Cues per deck, selected loops/mixer/gain and30 bounded lamps.',
                  gaps=['Bluetooth/tablet transport and source-software C/D deck layers remain open. FX/sampler, Hot Cue deletion, cue-loop extraction, full conditional encoder modes, live meters, complete feedback/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. EQ physical polarity and the complete hardware pitch range need capture. No All Controls query or mode write is sent.'])
    for side, deck in enumerate('ab'):
        add(result, 'shift', side, 68)
        result['inputs'][-1]['shiftChannel'] = side
        for action, number in [('play', 65), ('cuePreview', 66), ('sync', 67)]:
            add(result, action, side, number, deck=deck, feedback=True)
            result['inputs'][-1].update(shiftChannel=side, shifted=False)
            add(result, action, side, number + 8, deck=deck)
            result['inputs'][-1].update(releaseOnly=True, shiftChannel=side, shifted=True)
            result['outputs'].append(dict(result['outputs'][-1], number=number + 8))
        add(result, 'load', side, 81, deck=deck)
        result['inputs'][-1].update(shiftChannel=side, shifted=False)
        add(result, 'load', side, 84, deck=deck)
        result['inputs'][-1].update(releaseOnly=True, shiftChannel=side, shifted=True)
        add(result, 'cue', side, 83, deck=deck, feedback=True)
        for number in [82, 85]:
            add(result, 'jogTouch', side, number, deck=deck)
        add(result, 'wheelJog', 0, 48 + side, 'control', 'twosComplement', deck)
        result['inputs'][-1]['argument'] = 512
        add(result, 'jog', 0, 50 + side, 'control', 'twosComplement', deck)
        result['inputs'][-1].update(argument=512, requiresTouch=True)
        for number, low in [(1 + side, 33 + side), (55 + side, 71 + side)]:
            add(result, 'tempo', 0, number, 'control', 'paired14Bit', deck)
            result['inputs'][-1].update(lowNumber=low, inverted=True)
        for action, number in [('level', 57 + side), ('high', 59 + 3 * side), ('mid', 60 + 3 * side), ('low', 61 + 3 * side)]:
            add(result, action, 0, number, 'control', deck=deck)
            result['inputs'][-1]['inverted'] = action != 'level'
        for slot in range(8):
            add(result, f'hotcue{slot + 1}', side, 17 + slot, deck=deck, feedback=True)
            result['inputs'][-1].update(shiftChannel=side, shifted=False)
            add(result, f'hotcue{slot + 1}', side, 25 + slot, deck=deck)
            result['inputs'][-1].update(releaseOnly=True, shiftChannel=side, shifted=True)
        for slot, beats in enumerate([0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8]):
            add(result, 'toggleFixedLoop', side, 49 + slot, deck=deck)
            result['inputs'][-1].update(argument=beats, shiftChannel=side, shifted=False)
        for index, action in enumerate(['loopIn', 'loopOut', 'loopDown', 'loopUp', 'loop']):
            add(result, action, side, 57 + index, deck=deck)
            result['inputs'][-1].update(shiftChannel=side, shifted=True)
        add(result, 'loopSize', 0, 86 + 8 * side, 'control', 'twosComplement', deck)
        result['inputs'][-1].update(shiftChannel=side, shifted=False)
        for number in [81 + 8 * side, 83 + 8 * side, 85 + 8 * side, 87 + 8 * side]:
            add(result, 'gain', 0, number, 'control', 'twosComplement', deck)
            result['inputs'][-1].update(shiftChannel=side, shifted=True)
    add(result, 'crossfader', 0, 65, 'control')
    add(result, 'browse', 0, 54, 'control', 'twosComplement')
    add(result, 'openGroup', 0, 92)
    result['bankChanges'] = [{'channel': side, 'number': 68, 'onValue': 127, 'decks': [deck], 'releaseShiftChannels': [side]}
                             for side, deck in enumerate('ab')]
    result['startup'] = [[0x90 + r['channel'], r['number'], 0] for r in result['outputs']]
    result['shutdown'] = [list(message) for message in result['startup']]
    return [result]

"""Independent manufacturer Wave USB controls with composed MODE modifiers."""
from curated import add, profile

WAVE_DJAY = 'https://ts.hercules.com/download/sound/MIDI_Mapping/DJWave/DJCWaveDJAYPro.ZIP'
WAVE_REFERENCES = {'Hercules DJControlWave': {
    'url': WAVE_DJAY, 'cacheName': 'wave-djay.zip', 'sha256': 'cfd8c66371ca3a300855d4a1c9ad32b92fde200a6b6ca1c0f6c281f3eb15c313',
    'members': {'DJControlWave.djayMidiMapping': '0dc7f3a7a973212a6efaf217723d336e4a22263da346616b1dafbf7fb3e145c4',
                'DJControlWave2.djayMidiMapping': '3802e2fbf533a2d9fc7949f64d65a4ba0b084a314a297c64c4e97a170d453c88'},
    'relatedSources': [{'url': 'https://ts.hercules.com/download/sound/MIDI_Mapping/DJWave/DJCWave_VDJ7.zip', 'cacheName': 'wave-vdj7.zip',
                        'sha256': '5b30423ba18d9bf8c7a6d567d81851cb912d84aab704f1ef6d67803890a75469',
                        'member': 'Hercules DJControlWave definition.xml', 'memberSHA256': '67ea59a86ae61b9e5e4a2c80b6784a753f8ddfad8b14cb2ea85d425d9a76be2f'},
                       {'url': 'https://ts.hercules.com/download/sound/TDJS/current/TP2_DJ_Wave.zip', 'cacheName': 'wave-traktor.zip',
                        'sha256': '2f7e74f1e0353dc1b1427d9c6e56a63678286424055a03ba54ca7cd73b095159', 'evidenceLimit': 'Archive is pinned as an additional manufacturer source; no unreviewed TSI binding or setup command is imported.'},
                       {'url': 'https://ts.hercules.com/download/djuced/6.8/DJUCED_6.8.1.dmg',
                        'sha256': 'a76200de7cc2fced9b765d83edd02c8a07aa302d77c87c81ddf2f4c91330e2a2',
                        'member': 'DJControlWave.djm', 'memberSHA256': '76578fcb2e233bd6c85740a647592e57acce4975bc8da2f68ae4b63ab2c228d0', 'memberVersion': '3.2'},
                       {'url': 'https://support.hercules.com/en/product/djcontrolwave-en/'}],
    'review': 'The manufacturer directly publishes separate djay and VirtualDJ mappings. Both djay plist members explicitly map MODE notes16/34 to the same application modifier, normal Play13/31 to Shift Load, loop encoder presses17/35 to Shift library controls, and inverted pitch2/3. The manufacturer VirtualDJ device definition explicitly gives512 full-turn counts for all four wheel/contact CC streams. Current DJUCED uses720, so512 is the selected primary-definition calibration and physical equivalence remains unresolved. Native composes both MODE contacts without clearing the other when one releases. MODE presses retire source-owned deck contacts; no guessed release-all-Shift override is used. Forty-two selected inputs and fourteen0/127 transport/loop/cue-pad lamps are qualified. The djay PFL rows point both decks to the same unrelated channel4 CC9 template, so no PFL wire is imported. Current factory ring/setup bytes, state query, spinning rings, meters, EQ kill lamps, FX/sampler, cue deletion, full mode/lifecycle/audio/calibration and Bluetooth/tablet/physical/iPad/A10X acceptance remain open. No downloaded action, installer or script is executed.'}}


def wave_usb_profiles():
    result = profile('Hercules DJControlWave', WAVE_DJAY)
    result.update(definition='reviewed:hercules-wave-independent-usb-core',
                  aliases=['Hercules DJControlWave', 'DJControlWave', 'Hercules DJ Control Wave', 'DJ Control Wave'],
                  excludedAliases=['Universal DJ', 'DJHERCULESMIX Universal DJ', 'DJControl Instinct', 'DJControl Instinct P8'],
                  hardwareMode='USB MIDI with default channel1. Both MODE keys are composed native Shift, following the manufacturer djay mapping. Shift Play loads that deck. Shift loop encoder browses; Shift encoder press opens the group. Configure host audio separately.',
                  scope='Automatic42-input independent Wave USB core with composed MODE Shift, direct Shift loads,512-count wheel/contact streams, inverted pitch, three Hot Cues per deck, loops, mixer and14 selected lamps.',
                  gaps=['Bluetooth/tablet transport, ring animation/setup, meters, EQ kill lamps, source-specific right-MODE headphone functions, PFL wire ambiguity, FX/sampler, Hot Cue delete, complete modes/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. The manufacturer VirtualDJ512 calibration differs from current DJUCED720. No state query or SysEx is sent.'])
    for number in [16, 34]:
        add(result, 'shift', 0, number)
    for side, deck in enumerate('ab'):
        offset = side * 18
        for action, number in [('play', 13), ('cuePreview', 15), ('sync', 14), ('loop', 17)]:
            add(result, action, 0, number + offset, deck=deck, feedback=True)
            result['inputs'][-1]['shifted'] = False
        add(result, 'load', 0, 13 + offset, deck=deck)
        result['inputs'][-1]['shifted'] = True
        add(result, 'openGroup', 0, 17 + offset)
        result['inputs'][-1]['shifted'] = True
        for action, number in [('tempo', 2 + side), ('level', 4 + side), ('high', 7 + 3 * side), ('mid', 8 + 3 * side), ('low', 9 + 3 * side)]:
            add(result, action, 0, number, 'control', deck=deck)
            result['inputs'][-1].update(inverted=action == 'tempo', layerIndependent=True)
        add(result, 'jogTouch', 0, 18 + offset, deck=deck)
        result['inputs'][-1]['layerIndependent'] = True
        add(result, 'wheelJog', 0, 16 + side, 'control', 'twosComplement', deck)
        result['inputs'][-1].update(argument=512, layerIndependent=True)
        add(result, 'jog', 0, 18 + side, 'control', 'twosComplement', deck)
        result['inputs'][-1].update(argument=512, requiresTouch=True, layerIndependent=True)
        for slot in range(3):
            add(result, f'hotcue{slot + 1}', 0, 7 + slot + offset, deck=deck, feedback=True)
            result['inputs'][-1]['shifted'] = False
        add(result, 'loopSize', 0, 20 + side, 'control', 'twosComplement', deck)
        result['inputs'][-1]['shifted'] = False
        add(result, 'browse', 0, 20 + side, 'control', 'twosComplement')
        result['inputs'][-1]['shifted'] = True
    for action, number in [('crossfader', 1), ('master', 6)]:
        add(result, action, 0, number, 'control')
        result['inputs'][-1]['layerIndependent'] = True
    result['bankChanges'] = [{'channel': 0, 'number': number, 'onValue': 127, 'decks': list('ab')} for number in [16, 34]]
    result['startup'] = [[0x90, r['number'], 0] for r in result['outputs']]
    result['shutdown'] = [list(message) for message in result['startup']]
    return [result]

"""Independent manufacturer facts for three legacy four-strip DJM mixers."""
from curated import add, profile

LEGACY_DJM_REFERENCES = {
    'Pioneer DJM-900NXS': {
        'url': 'https://progresionaudiovisual.com/sites/default/files/2024-05/DJM-900nexus_OperatingInstructions070511.pdf',
        'cacheName': 'djm900nxs-manual.pdf', 'sha256': 'c512d1285b8fcff62d066ca6f64a8dad6fcb51484f54206305e652d1a47244cd', 'pages': [21, 22, 23],
        'review': 'Independent manufacturer operating manual pages21/22 were visually reviewed. Its hexadecimal chart qualifies four gain/three-band EQ/Color/fader strips, direct Cue CC46-49hex and four global mixer values. Page23 states default MIDI channel1 and Toggle. No NXS2/SRT inheritance or unlisted source-selector wire is inferred. Link Cue, MIDI LFO, X-Pad, fader start, FX/mic, curve/assignment, full lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open.'},
    'Pioneer DJM-850': {
        'url': 'https://www.appliancesonline.com.au/public/manuals/Pioneer-DJM850-4Ch-High-End-Digital-Mixer-User-Manual.pdf',
        'cacheName': 'djm850-manual.pdf', 'sha256': 'c4ae8dd35829cf90757a53c288d8552963ce5d468a47f7ba57a4087a3022bbe0', 'pages': [22, 23, 24],
        'review': 'Independent manufacturer manual pages22/23 were visually reviewed. Its decimal chart qualifies the same32 selected native mixer fields, independently of the900NXS hexadecimal chart. The cover explicitly includes850-K/S/W. Page24 states default MIDI channel1 and Toggle. BEAT switches, hardware effects, mic, fader-start notes, curve/assignment, full lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. No sibling source-selector message is inherited.'},
    'Pioneer DJM-750MK2': {
        'url': 'https://www.proacousticsusa.com/media/wysiwyg/PDFs/DJM-750MK2_addendum_MIDI_Message_EN.pdf',
        'cacheName': 'djm750mk2-midi.pdf', 'sha256': 'c3cb2018984ea93e6e676644c0d5a63ce45a8ffabf9ddc229abb390aa35ce784', 'pages': [1, 2, 3],
        'review': 'All three pages of the independent Version1.00 manufacturer addendum were visually reviewed. They qualify the32 selected native mixer fields and sixteen source-selector notes, including Return AUX on every strip. A new on127 source report resets only its strip pickup. Native requires MIDI channel1 and Toggle Cue state. The addendum does not establish the factory utility defaults. No original750,250MK2,900NXS2 or other sibling mode is inferred. Send/Return, FX/mic, curve/assignment, full lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open.'},
}


def legacy_djm_mixer_profiles():
    results = []
    strips = [[1, 2, 3, 4, 5, 17], [6, 7, 8, 9, 10, 18],
              [12, 14, 15, 21, 22, 19], [80, 81, 92, 82, 83, 20]]
    for name, ref in LEGACY_DJM_REFERENCES.items():
        short = name.removeprefix('Pioneer ')
        result = profile(name, ref['url'])
        result.update(autoSelect=False, role='accessory', definition='reviewed:'+short.lower()+'-independent-four-strip-mixer',
                      aliases=[name, 'Pioneer DJ '+short, short, short+' MIDI 1'],
                      excludedAliases=[m for m in ['DJM-900NXS2', 'DJM-900SRT', 'DJM-750', 'DJM-250MK2', 'DJM-TOUR1'] if m != short],
                      hardwareMode='Manual MIDI channel1 and Toggle Cue-button mode. Physical CH1-4 map native A-D. C/D require app opt-in. Configure app audio separately and avoid duplicate hardware/software processing.',
                      scope='Manual32-input four-strip native mixer, direct Cue states and four global controls. Independently reviewed model-specific table. No hardware writes or automatic audio route.',
                      gaps=['Hardware processing and external deck audio are separate from this optional app mixer. Curve/assignment, FX/microphone, master/Link/FX Cue, fader-start/mode controls, full lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. Native Color knobs control the software filter.'])
        if short == 'DJM-900NXS':
            result['aliases'] += ['DJM-900nexus', 'Pioneer DJM-900nexus']
        elif short == 'DJM-850':
            result['aliases'] += ['DJM-850-K', 'DJM-850-S', 'DJM-850-W']
        for index, (deck, numbers) in enumerate(zip('abcd', strips)):
            for action, number in zip(['gain', 'high', 'mid', 'low', 'filterKnob', 'level'], numbers):
                add(result, action, 0, number, 'control', deck=deck)
            add(result, 'cueState', 0, 70 + index, 'control', deck=deck)
        for action, number in [('crossfader', 11), ('master', 24), ('monitor', 26), ('cueMix', 27)]:
            add(result, action, 0, number, 'control')
        if short == 'DJM-750MK2':
            result['bankChanges'] = [{'channel': 0, 'number': n, 'onValue': 127, 'decks': [deck]}
                                     for deck, numbers in [('a', [51, 52, 53, 67]), ('b', [55, 56, 57, 69]),
                                                           ('c', [59, 60, 61, 71]), ('d', [63, 64, 65, 73])] for n in numbers]
            result['scope'] += ' Source-selector reports reset pickup only on the changed strip.'
        results.append(result)
    return results

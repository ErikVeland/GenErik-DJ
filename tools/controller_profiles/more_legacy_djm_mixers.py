"""Independent SRT, original750 and250MK2 manufacturer mixer facts."""
from curated import profile
from legacy_djm_mixers import add_reviewed_djm_inputs

MORE_LEGACY_DJM_REFERENCES = {
    'Pioneer DJM-900SRT': {
        'url': 'https://www.djcenter.ee/images/kasutusjuhendid/Pioneer-DJM-900SRT.pdf',
        'cacheName': 'djm900srt-manual.pdf', 'sha256': '0a105556c267a2c9254fe5f8d1e36aff93942338485fe4260733a017091b16c0', 'pages': [22, 23, 24],
        'review': 'Manufacturer chart pages22/23 were visually reviewed. Decimal CC addresses qualify32 native mixer fields. Physical strips explicitly select USB decks3/1/2/4 and target native C/A/B/D. All sixteen selector notes reset only their strip pickup. Page24 specifies default MIDI channel1 and TGL. Enable generic MIDI with ON/OFF(UTILITY) and close Serato. No NXS/NXS2 mode is inherited. Hardware FX, mic, assignment/curve, fader starts, external deck audio, complete modes/lifecycle/calibration and physical/iPad/A10X acceptance remain open.'},
    'Pioneer DJM-750': {
        'url': 'https://cdn-docs.av-iq.com/instructions/DJM-750_OperatingInstructions042613.pdf',
        'cacheName': 'djm750-manual.pdf', 'sha256': 'bc53dc62005fb4d99536bbbd242c5267e5a23bcfe013ad155d0bba3405c15d68', 'pages': [19, 20, 21],
        'review': 'Manufacturer decimal chart pages19/20 were visually reviewed. It qualifies28 selected inputs with no per-strip Color knob or source-selector report. Physical CH1-4 target native A-D by an explicit app layout. Page21 specifies default MIDI channel1 and TGL. The global Boost Color FX control is not four strip filters and stays inactive. No750MK2 field is inherited. Hardware FX, mic, assignment/curve, fader starts, external deck audio, complete modes/lifecycle/calibration and physical/iPad/A10X acceptance remain open.'},
    'Pioneer DJM-250MK2': {
        'url': 'https://manuals.plus/m/e7d4bd85474a10aedc2c4ddd9809d56bd9707b753a45cf73bd7b831a2da23594',
        'reviewDate': '2026-11-19', 'pages': [1, 2],
        'evidenceLimit': 'Manufacturer Version1.00 table was reviewed as cached extracted text. Direct table PDF bytes and screenshots were unavailable. No table byte hash or visual table claim is made.',
        'relatedSources': [{'url': 'https://downloads.support.alphatheta.com/manuals/dj-mixers/DJM-250MK2/DJM-250MK2_DRI1443B_manual.pdf',
                            'cacheName': 'djm250mk2-manual.pdf', 'sha256': '3de1a6bcad2c169345161af75def4b4e67da27befee995b7ac339bdfa3522afb', 'pages': [19]},
                           {'url': 'https://support.alphatheta.com/en-US/articles/4404659792025', 'review': 'Manufacturer lists the2Mar2017 MIDI addendum. Its linked legacy download returns404.'}],
        'review': 'The independently readable hexadecimal250MK2 chart qualifies18 selected native inputs and six source-selector notes. Operating manual page19 was visually reviewed and confirms default MIDI1/TOGGLE. Physical CH1/2 target native A/B. Selector on127 reports reset only their strip pickup. No original250,450 or S3 protocol is inferred. AUX/mic, global Filter/parameter, assignment/curve/reverse, external deck audio, full lifecycle/calibration and physical/iPad/A10X acceptance remain open.'},
}


def more_legacy_djm_profiles():
    results = []
    names = list(MORE_LEGACY_DJM_REFERENCES)
    for name, decks, color, count in [(names[0], 'cabd', True, 32), (names[1], 'abcd', False, 28), (names[2], 'ab', True, 18)]:
        short = name.removeprefix('Pioneer ')
        ref = MORE_LEGACY_DJM_REFERENCES[name]
        result = profile(name, ref['url'])
        result.update(autoSelect=False, role='accessory', definition='reviewed:'+short.lower()+'-independent-manual-mixer',
                      aliases=[name, 'Pioneer DJ '+short, short, short+' MIDI 1'],
                      excludedAliases=[m for m in ['DJM-900NXS', 'DJM-900NXS2', 'DJM-750MK2', 'DJM-250', 'DJM-450', 'DJM-S3'] if m != short],
                      hardwareMode='Manual MIDI channel1 and Toggle Cue-button mode. Physical strips target native '+('/'.join(decks.upper()))+'. C/D require app opt-in. Configure audio separately and avoid duplicate hardware/software processing.' + (' Enable generic MIDI with ON/OFF(UTILITY) and close Serato.' if short == 'DJM-900SRT' else ''),
                      scope=f'Manual{count}-input independently reviewed native mixer and direct Cue states. No hardware writes or automatic audio route.',
                      gaps=['Hardware processing and external deck audio are separate from this optional app mixer. Unmapped FX/mic, curve/assignment, fader starts, complete modes/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open.'] + ([ref['evidenceLimit']] if 'evidenceLimit' in ref else []))
        add_reviewed_djm_inputs(result, decks=decks, include_color=color)
        if short != 'DJM-750':
            selectors = [(d, range(start, start + 4)) for d, start in zip('cabd', [50, 54, 58, 62])] if short == 'DJM-900SRT' else [('a', [51, 52, 53]), ('b', [55, 56, 57])]
            result['bankChanges'] = [{'channel': 0, 'number': n, 'onValue': 127, 'decks': [d]} for d, ns in selectors for n in ns]
            result['scope'] += ' Source reports reset pickup only on the changed strip.'
        results.append(result)
    return results

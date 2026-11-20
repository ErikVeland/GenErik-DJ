"""Independent PMX-20 manufacturer table with explicitly excluded source conflicts."""
from curated import add, profile

PMX20_MANUAL = 'https://www.geminisound.com/cdn/shop/files/PMX20_Manual_Compressed.pdf?v=12183789050654275091'
PMX20_SPEC = 'https://cdck-file-uploads-us1.s3.dualstack.us-west-2.amazonaws.com/flex001/uploads/techtools/original/3X/3/2/32116e078fe974f6b96cc2a7e8a25e1eae665413.pdf'
PMX20_REFERENCES = {'Gemini PMX20': {
    'url': PMX20_MANUAL, 'sha256': 'baf0f0cd69921c8f2c35b94861e87668ad9fa4bd4e340a2daf91b9902f18688e',
    'files': [
        {'cachePath': 'TestBuilds/r445/upstream/pmx20-manufacturer-manual.pdf', 'sha256': 'baf0f0cd69921c8f2c35b94861e87668ad9fa4bd4e340a2daf91b9902f18688e'},
        {'cachePath': 'TestBuilds/r445/upstream/pmx20-midi-spec.pdf', 'sha256': '9515b9e568070fbf0d9239607276d4e112af2ec5780f91a4d6ab35c88dea9555'}],
    'relatedSources': [{'url': 'https://www.geminisound.com/products/pmx-20'}, {'url': PMX20_SPEC}],
    'review': 'Own manufacturer2018 manual p8/p9 gives A/B Hot Cues, loops, all four mixer strips, global controls and output colours. The public2021 PMX20 MIDI SPEC.xlsx export hosted by DJ TechTools supplies explicit C/D performance rows, binary-offset loop encoders, mode/focus paging and factory momentary-button behaviour. Its author metadata is only admin; manufacturer authorship of that separate export is not established. Native uses non-conflicting facts and records its additional C/D/encoding provenance separately. The tables disagree on LoadC/D (manufacturer44/45hex versus2021spec45/46), Forward (46 versus44) and browse encoder channel (raw4 versus5). All disputed controls stay inactive. Manual76-input accessory:32 Hot Cues, four Loop buttons/size encoders, six mixer controls per deck, four PFL buttons, A/B Load, directory entry, native previous-group assignment on Back, crossfader/master/headphone level/blend. Hot Cue notes8..1 are reversed by slot; Sample notes09..0F/20hex remain inactive. Mode33/34 rearm only their deck. Own table focus64 rearm A/C or B/D without assigning app actions. C/D require app opt-in. Forty optional static Hot Cue/PFL/Loop lamps use steady green1/on1 and off0. No mode/focus lamp is sent because those receive notes change hardware paging. Use Full MIDI mode selected before the app by holding CH2 USB10seconds, factory momentary buttons and normal paging. Automatic selection stays off: default power-on is hardware Mixer mode, and persistent Flat/Toggle settings have no reviewed discovery/restoration. No identity, forced updates, all-LED reset, persistent mode, preset, driver, firmware or audio-route write is sent. Main Play/Cue/Sync, sampler/FX, meters, disputed global controls, complete source/audio/mode/lifecycle/recovery and physical/iPad/A10X acceptance remain open. No PMX10 protocol is inherited.'}}


def pmx20_profiles():
    """Return the reviewed manual subset with source conflicts and mode writes inactive."""
    p = profile('Gemini PMX20', PMX20_MANUAL)
    p.update(definition='reviewed:pmx20-common-core', role='accessory', autoSelect=False,
        aliases=['Gemini PMX20', 'Gemini PMX-20', 'PMX20', 'PMX-20'], excludedAliases=['Gemini PMX10', 'PMX-10', 'PMX10'],
        hardwareMode='Before opening the app, select Full MIDI mode by holding CH2 USB for10seconds. Use factory momentary buttons and normal paging. Enable this manual profile separately. Select Hot Cues for pads; C/D require app opt-in. Back selects the previous library group. C/D Load, Forward and rotary browsing stay inactive because the documents conflict. Audio routing is separate.',
        scope='Manual76-input-row four-deck mixer/performance subset with32 Hot Cues, loop controls, mixer/PFL, A/B Load, directory entry/previous group and four global controls. Forty optional static lamps. Full modes, disputed controls, lifecycle and audio remain open.',
        bankChanges=[{'channel': ch, 'number': n, 'anyPositive': True,
            'decks': list('ac' if ch % 2 == 0 else 'bd') if n == 64 else [deck]}
            for ch, deck in enumerate('abcd') for n in [33, 34, 64]],
        gaps=[PMX20_REFERENCES['Gemini PMX20']['review']])
    for ch, deck in enumerate('abcd'):
        for slot in range(8): add(p, f'hotcue{slot + 1}', ch, 8 - slot, deck=deck, feedback=True)
        add(p, 'loop', ch, 35, deck=deck, feedback=True)
        add(p, 'loopSize', ch, 36, 'control', 'binaryOffset', deck)
        add(p, 'cue', ch, 50, deck=deck, feedback=True)
        for action, n in [('level', 49), ('filterKnob', 51), ('low', 52), ('mid', 53), ('high', 54), ('gain', 55)]:
            add(p, action, ch, n, 'control', deck=deck)
    for deck, n in [('a', 64), ('b', 65)]: add(p, 'load', 4, n, deck=deck)
    add(p, 'openGroup', 4, 66)
    add(p, 'browsePreviousGroup', 4, 67); p['inputs'][-1]['pulse'] = True
    for action, n in [('crossfader', 96), ('master', 80), ('monitor', 84), ('cueMix', 83)]: add(p, action, 4, n, 'control')
    for lamp in p['outputs']: lamp['onValue'] = 1
    return [p]

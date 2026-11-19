"""Separate public legacy cores, with model-specific modes and ownership limits."""
from curated import add, profile
from legacy_denon_hc import lamp as led_trigger
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA

HD = 'Denon DJ HD2500'
SCS = 'Stanton SCS.4DJ'
FIRST = 'Gemini FirstMix I/O'
BASE = 'https://cdn.inmusicbrands.com/denondj/legacy/'
STANDALONE_REFERENCES = {
    HD: {'url': BASE+'dnhd2500/DN-HD2500-MIDI-command-list.pdf', 'sha256': 'a84b3ff9e23cd3acd010ef42a0e8fdf8b6aefca65468cd761baad289b8ddcfee',
        'files': [{'cachePath': 'TestBuilds/r417/upstream/hd2500-midi.pdf', 'sha256': 'a84b3ff9e23cd3acd010ef42a0e8fdf8b6aefca65468cd761baad289b8ddcfee'}, {'cachePath': 'TestBuilds/r424/upstream/hd2500-quickstart.pdf', 'sha256': '582391a253b585dbef28ef5ba51b581561c6693da50dc18932295c9161221029'}, {'cachePath': 'TestBuilds/r424/upstream/hd2500-mac-midi.pdf', 'sha256': 'e46b0d56d67cbc5a73addb99f9d12ff0460cc455d2b194e4d60005dc12aea02c'}],
        'relatedSources': [{'url': BASE+'dnhc4500/DN-HC4500_DN-HD2500_quickstartguide_ssl.pdf'}, {'url': BASE+'dnhd2500/DN-HD2500_mac_audiomidiconfig_manual.pdf'}],
        'review': 'Own manufacturer MIDI chart supplies press64, Play67/Cue66, bends9/8, A1/B55/57, reloop64, Load40, Back48, strict browse84 values0/127, contact81 and binary-offset CC81 wheel with documented1480 pulses/revolution. Native manually assigns raw0 to A and raw1 to B; other channel pairs and default pairing are not inferred from HC4500. Own setup guide requires SOURCE then PARAMETERS to select MIDI, explicitly not PC. Own Mac guide identifies DN-HD2500 or generic Inter0, but native never selects a generic endpoint automatically. Source49 and Preset36 retire owned A/B contacts. Own output table uses separate CC74-on/75-off triggers with Play39/Cue38 lamp identifiers. Local font extraction is incomplete; the primary web document text supplies the wire table. Pitch direction, complete jog interpretation/calibration, A2/Flip, FX, display/preset/state/lifecycle/audio/host/OS and physical acceptance remain open. No preset request or write is sent.'},
    SCS: {'url': FOUR_SOURCE, 'sha256': FOUR_PACKAGE_SHA, 'archiveMember': 'Applications/DEX4.app/Contents/Resources/controllers/Stanton__SCS4DJ.js',
        'files': [{'cachePath': 'TestBuilds/r301/upstream/controllers/Stanton__SCS4DJ.js', 'sha256': '07972c1b703452af8468b5c101b0185ec943a9cd3497596a42d8bead3a8a7434'}, {'cachePath': 'TestBuilds/r424/upstream/scs4dj-manual.pdf', 'sha256': '4c052dac297c6dbdc95b41a787d0f8911608ca733fe597b1638755582657761b'}],
        'relatedSources': [{'url': 'https://www.emnordic.fi/storage/FE226549D60919FE29F43F8383CB7715D1F4FAEA5F915FECFBE2969F0B76EED3/3bf2605be62941a1b71b78d13ceaa034/pdf/media/2dd02535312b49948abcf7c1386b8214/549661.pdf', 'reviewedSection': '6.8 MIDI Controller Mode'}],
        'review': 'Own named MIDI script qualifies raw0 fixed A/B transport, held bends, normal mixer/tempo, separate wheel/rim counts, library and native loop toggle/reloop/size buttons. Manufacturer mode section requires MIDI Controller Mode and permits channel1..16; native retains MIDI channel1 and published unmodified addresses. Standalone playback stops when that mode is entered. Fixed native Note44/43 contact gates platter CC13/14 at source scale256; rim CC15/16 is wheel-side jog. Script Cue-position claims on Notes5..8 are not qualified physical Hot Cues and remain inactive, including the explicitly ambiguous crossfader-switch address. Source Play/PFL and loop-state lamps only. Source scratch-toggle logic is not copied. Custom channels/maps, full FX/modes/meters/state/lifecycle/audio/USB/OS, physical scale and iPad/A10X acceptance remain open.'},
    FIRST: {'url': FOUR_SOURCE, 'sha256': FOUR_PACKAGE_SHA, 'archiveMember': 'Applications/DEX4.app/Contents/Resources/controllers/Gemini__FirstMIX_iO.js',
        'files': [{'cachePath': 'TestBuilds/r301/upstream/controllers/Gemini__FirstMIX_iO.js', 'sha256': 'e9548d4cabb33429097c818a2d1594f70edaaff80daa7b7c842c50b94869efc4'}],
        'relatedSources': [{'url': 'https://manualzz.com/doc/en/2467126/gemini-firstmix-i-o-operating-instructions', 'review': 'Manufacturer-authored guide transcript: per-deck Gain/Treble/Bass, Master, rotary Pitch, Scratch mode and physical headphone volume.'}],
        'review': 'Own FirstMIX i/O script independently qualifies raw0 transport/PFL/key lock/Load, physical contact23/87, rotary pitch3/4, Gain10/11, High12/13, Low16/17, crossfader7 and Master18. The manufacturer guide resolves copied source comments: gain is gain, there are no channel faders, and CC18 is Master rather than cue-mix. Separate left wheel addresses1/2 carry negative unsigned counts; right20/21 carry positive counts at source scale350. Native unsignedCount retains1..127 magnitude, ignores0, requires owned contact and applies sign per address. Browser Notes3/2 move previous/next and Note1 opens selection. No original FirstMix/Pro alias, original signed wheel encoding or startup is inherited. Fixed native contact replaces the source software Scratch toggle. Preview, FX, full modes/state/meters/lifecycle/audio/host/OS and physical/iPad/A10X acceptance remain open. Local PDF mirror refused access; the manufacturer guide transcript was read publicly. No bypass, vendor code, driver, SysEx query, firmware or setting write runs.'}}


def standalone_profiles():
    """Return independent subsets without vendor startup or hardware state writes."""
    hd = profile(HD, STANDALONE_REFERENCES[HD]['url'])
    hd.update(definition='reviewed:legacy-standalone-hd2500', autoSelect=False,
        aliases=[HD, 'Denon DN-HD2500', 'DN-HD2500', 'DNHD2500'], excludedAliases=['DN-HC4500', 'DN-HC5000', 'Inter 0'],
        hardwareMode='Select manually in MIDI source mode, not PC. This subset maps MIDI channel1 to A and channel2 to B. Other channel pairs are inactive. Configure app audio separately.', scope='Manual two-target normal transport, held Cue/bends, manual loop anchors, library and fixed contact/jog. Separate Play/Cue lamp triggers.', gaps=[STANDALONE_REFERENCES[HD]['review']])
    for ch, deck in enumerate('ab'):
        for action, number in [('play', 67), ('cuePreview', 66), ('pitchBendDown', 9), ('pitchBendUp', 8), ('load', 40), ('openGroup', 48), ('loopIn', 55), ('loopOut', 57), ('reloop', 64)]: add(hd, action, ch, number, deck=deck if action != 'openGroup' else None)
        add(hd, 'browse', ch, 84, 'control', 'zeroForward')
        add(hd, 'jogTouch', ch, 81, deck=deck)
        add(hd, 'jog', ch, 81, 'control', 'binaryOffset', deck); hd['inputs'][-1].update(argument=1480, requiresTouch=True)
        for number in [49, 36]: hd.setdefault('bankChanges', []).append({'channel': ch, 'number': number, 'onValue': 64, 'decks': ['a', 'b'], 'releaseShiftChannels': []})
        led_trigger(hd, 'play', ch, 39, deck); led_trigger(hd, 'cuePreview', ch, 38, deck)

    scs = profile(SCS, FOUR_SOURCE)
    scs.update(definition='reviewed:legacy-standalone-scs4dj', aliases=[SCS, 'Stanton SCS4DJ', 'SCS.4DJ', 'SCS4DJ'], excludedAliases=['Stanton SCS.1d', 'Stanton SCS.3d'],
        hardwareMode='Enter MIDI Controller Mode with published unmodified addresses and MIDI channel1. Internal standalone playback stops. Configure app audio separately.', scope='Automatic channel1 transport, held Cue/bends, library, native loop toggle/reloop/size, mixer, coarse pitch and fixed touch/platter/rim. Qualified Play/PFL/loop-state lamps.', gaps=[STANDALONE_REFERENCES[SCS]['review']])
    for i, deck in enumerate('ab'):
        for action, numbers in [('play', [36, 35]), ('cuePreview', [38, 37]), ('sync', [40, 39]), ('cue', [30, 29]), ('pitchBendDown', [26, 25]), ('pitchBendUp', [28, 27]), ('load', [69, 70]), ('loop', [18, 17]), ('reloop', [24, 23]), ('loopUp', [22, 21]), ('loopDown', [20, 19])]: add(scs, action, 0, numbers[i], deck=deck, feedback=action in ['play', 'cue'])
        add(scs, 'jogTouch', 0, [44, 43][i], deck=deck)
        for action, numbers in [('jog', [13, 14]), ('wheelJog', [15, 16])]:
            add(scs, action, 0, numbers[i], 'control', 'binaryOffset', deck); scs['inputs'][-1].update(argument=256, requiresTouch=action == 'jog')
        for action, numbers in [('level', [17, 18]), ('high', [7, 8]), ('mid', [9, 10]), ('low', [11, 12]), ('filterKnob', [5, 6])]: add(scs, action, 0, numbers[i], 'control', deck=deck)
        add(scs, 'tempo', 0, i+1, 'control', deck=deck); scs['inputs'][-1]['inverted'] = True
        scs['outputs'].append({'action': 'loop'+deck.upper(), 'targetDeck': deck, 'kind': 'note', 'channel': 0, 'number': [24, 23][i], 'onValue': 127, 'offValue': 0, 'offUsesNoteOn': True})
    add(scs, 'crossfader', 0, 65, 'control'); add(scs, 'cueMix', 0, 66, 'control'); add(scs, 'browse', 0, 64, 'control', 'binaryOffset'); add(scs, 'openGroup', 0, 65)

    first = profile(FIRST, FOUR_SOURCE)
    first.update(definition='reviewed:legacy-standalone-firstmix-io', aliases=[FIRST, 'Gemini FirstMix IO', 'FirstMIX i/O', 'FirstMix IO'], excludedAliases=['Gemini FirstMix', 'FirstMix Pro'],
        hardwareMode='Unmodified FirstMix I/O normal MIDI channel1. Native wheel movement requires owned contact. Configure app audio separately.', scope='Automatic two-deck transport, PFL/key lock/Load, library, true gain/two-band EQ, rotary pitch, Master/crossfader and fixed touch with separate directional wheel counts.', gaps=[STANDALONE_REFERENCES[FIRST]['review']])
    for i, deck in enumerate('ab'):
        for action, number in [('play', 7), ('cuePreview', 6), ('sync', 5), ('cue', 9), ('keylock', 12), ('load', 22)]: add(first, action, 0, number+64*i, deck=deck, feedback=action in ['play', 'cuePreview', 'cue', 'keylock'])
        add(first, 'jogTouch', 0, 23+64*i, deck=deck)
        for number, inverted in [(1+i, True), (20+i, False)]:
            add(first, 'jog', 0, number, 'control', 'unsignedCount', deck); first['inputs'][-1].update(argument=350, requiresTouch=True, inverted=inverted)
        for action, number in [('gain', 10), ('high', 12), ('low', 16)]: add(first, action, 0, number+i, 'control', deck=deck)
        add(first, 'tempo', 0, 3+i, 'control', deck=deck); first['inputs'][-1]['inverted'] = True
    add(first, 'crossfader', 0, 7, 'control'); add(first, 'master', 0, 18, 'control')
    for action, number in [('browsePrevious', 3), ('browseNext', 2), ('openGroup', 1)]: add(first, action, 0, number)
    return [hd, scs, first]

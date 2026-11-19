"""Independent GMX MIDI facts without HID, mode or sibling inference."""
from curated import add, profile

GMX_REFERENCES={'Gemini GMX': {'url': 'https://raw.githubusercontent.com/codecat/mixxx-gemini-gmx/67f88e747bd8c8e04048f29945e7d87506e863f1/Midi%20Spec.txt', 'sha256': '62ec592442989a7ffe0a3c52bdebe8655b5f19454f0e2d060c314b799ed4ab1d', 'upstreamRevision': '67f88e747bd8c8e04048f29945e7d87506e863f1', 'files': [{'cachePath': 'TestBuilds/r471/upstream/gmx.midi.xml', 'sha256': 'd3a8899bafc2ace44a09abefca238ba625ae50a838ba6ac884cbbea0f621283f'}, {'cachePath': 'TestBuilds/r471/upstream/gmx-midi-spec.txt', 'sha256': '62ec592442989a7ffe0a3c52bdebe8655b5f19454f0e2d060c314b799ed4ab1d'}, {'cachePath': 'TestBuilds/r471/upstream/gmx-scripts.js', 'sha256': '71ebf84e6c5e090b5197f79663e2777bdb4061bffb8c637de2bc643cbad909df'}, {'cachePath': 'TestBuilds/r471/upstream/README.md', 'sha256': 'be7fe4abd26f787b56f6049ce4c4ceca196feb388c97a655be5739e3dd91aec1'}, {'cachePath': 'TestBuilds/r446/upstream/gmx-manual.pdf', 'sha256': '549fe6d30b7cdc02f28375b7f893005efcf62f69ff0eb455b824027c3a3ceb77'}], 'relatedSources': [{'url': 'https://github.com/codecat/mixxx-gemini-gmx'}, {'url': 'https://www.geminisound.com/cdn/shop/files/GMX_user_manual.pdf?v=6780214146587148454', 'sha256': '549fe6d30b7cdc02f28375b7f893005efcf62f69ff0eb455b824027c3a3ceb77'}, {'url': 'https://www.geminisound.com/blogs/kb/gmx-gmx-drive-midi-troubleshooting'}], 'review': 'Primary owner codecat repository mixxx-gemini-gmx at67f88e747bd8c8e04048f29945e7d87506e863f1 supplies independent MIDI XML, numeric Midi Spec and a separate HID interface. Its README calls the mapping work-in-progress and explicitly reports MIDI limitations. This is community protocol evidence, not a manufacturer numeric specification or native hardware acceptance. MIDI XML and the notes agree on raw0/1 deck channels and raw3 globals. Native Play1/held Cue2/Reloop5/Keylock19/Load28/PFL34 use the existing app actions. Numeric notes separately qualify loop In3/Out4, shifted half8/double7 and Shift43. Native normal buttons/filter/tempo are Shift-guarded; Range20 is negative-only Keylock rearm, and negative half/double aliases rearm normal In/Out as well as their own action. Native uses the existing +/-8-percent tempo range for explicitly inverted CC1; exact hardware range/discovery is unqualified. Normal filterCC4 preserves the XML super1 role; the prose endpoint typo is not interpreted as a binary switch. Raw3 gain1/2, mid3/4, high5/6, low7/8 and level9/10 are normal absolute positions. Cross11, cueMix12, master13 and monitor14 are explicitly inverted in both numeric roles and XML; native preserves their direction. No sibling G2V/G4V/GMX DRIVE addresses or USB names are inherited. Own GMX manual independently documents that entering/exiting MIDI stops standalone playback. Native never sends that mode switch. Requires manual existing MIDI mode/input and separately configured app audio. Hot Cue/Auto Loop states, all pads/clears, TAP/Lock/AutoCue/repeat/search/reverse/scratch, ambiguous relative jog/browser edge64 and calibration, booth, meters/screens/HID, full feedback/lifecycle/recovery and exact USB/driver/OS/power/audio/DVS and physical/iPad/A10X acceptance remain open. Source notes use ceil(value-63.5) while mapper jog uses value-64; no relative encoding is guessed. Source LED-clear loops are not copied. No upstream mapper/script code executes or ships. No setup/query/preset/firmware/driver/hardware-mode/output/audio-route packet runs.'}}


def gmx_profiles():
    """Return the manual normal MIDI layout with explicit inverted global knobs."""
    ref=GMX_REFERENCES['Gemini GMX'];p=profile('Gemini GMX',ref['url'])
    p.update(autoSelect=False,definition='reviewed:gemini-gmx-primary-midi-core',
        aliases=['Gemini GMX','GMX'],excludedAliases=['GMX DRIVE','Gemini GMX DRIVE','GMX-DRIVE','G2V','G4V'],
        hardwareMode='Enter GMX MIDI mode before manual profile selection; switching modes stops standalone playback. Use an existing MIDI source and configure app audio separately. Native does not change hardware mode, audio or drivers. Hot Cue/Auto Loop modes, HID and screens remain unsupported. Tempo uses the app range.',
        scope='Manual46-input fixed A/B Play/held Cue/Keylock/Load/PFL, normal/shifted loops, inverted tempo, filter, gain/EQ/level and inverted cross/headphone/master controls. No automatic identity, setup, outputs or audio route.',
        gaps=[ref['review']])
    for ch,deck in enumerate('ab'):
        add(p,'shift',ch,43);p['inputs'][-1]['shiftInput']=ch
        for action,n in [('play',1),('cuePreview',2),('reloop',5),('keylock',19),('load',28),('cue',34),('loopIn',3),('loopOut',4)]:
            add(p,action,ch,n,deck=deck);p['inputs'][-1]['shifted']=False
        for action,n in [('keylock',20),('loopIn',8),('loopOut',7)]:
            add(p,action,ch,n,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for action,n in [('loopDown',8),('loopUp',7)]:
            add(p,action,ch,n,deck=deck);p['inputs'][-1]['shifted']=True
        for action,n in [('tempo',1),('filterKnob',4)]:
            add(p,action,ch,n,'control',deck=deck);p['inputs'][-1]['shifted']=False
            if action=='tempo':p['inputs'][-1]['inverted']=True
        for action,n in [('gain',1),('mid',3),('high',5),('low',7),('level',9)]:add(p,action,3,n+ch,'control',deck=deck)
    for action,n in [('crossfader',11),('cueMix',12),('master',13),('monitor',14)]:
        add(p,action,3,n,'control');p['inputs'][-1]['inverted']=True
    return [p]

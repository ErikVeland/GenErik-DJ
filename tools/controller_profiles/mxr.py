"""Independent manufacturer MXR contracts with separate controller and lamp channels."""
from curated import add, profile

MXR_REFERENCES = {
    'American Audio 10MXR': {'url': 'https://www.adj.eu/mwdownloads/download/link/id/522', 'sha256': '6ea2a7ef819f5a8988017fef599222cf9938ec463c2048e8b21658d36f41399d', 'cachePath': 'TestBuilds/r422/upstream/10mxr.pdf', 'reviewedPages': [15],
        'review': 'Own two-strip manufacturer table qualifies normal raw channel0 and Shift1, two Hot Cues per side, right Sync54 and USB selectors89/6. Hardware mixer/audio ownership differs from the larger models. Manual selection requires separate app audio to avoid applying hardware mixing twice. No Controller-mode channel offset is inferred from 14/19MXR. Native alternate positive commands remain inactive and alternate releases retire held controls. Source Sync55 and reversed browse direction are overridden by the primary table. No source actions or hardware writes run.'},
    'American Audio 14MXR': {'url': 'https://www.adj.com/cdn/shop/files/f1f0c1c8837d984226dd0e8bf00bea2ad37f7a6c_14mxr.pdf?v=10788332160262280223', 'sha256': 'a8777d31871455f53e5abcf87c891e37eeb833502b50443ca5a9f0d6f6e170a2', 'cachePath': 'TestBuilds/r422/upstream/14mxr.pdf', 'reviewedPages': [16, 17], 'visuallyReviewedPages': [16],
        'review': 'Own manufacturer table explicitly adds2 to input channels in Controller mode, except LED messages. Native normal input raw2, Shift releases raw3, lamps raw0. Four physical strips map C/A/B/D as in the separate named PCDJ volume mapping. Primary per-strip five mixer controls, filter and PFL override the script copied fourth-strip EQ target error. Three Hot Cues per side and right Sync55 are independent of 10MXR. Hold Controller Mode while powering on to select the documented software-mixing route; native does not change that setting. Mixer-mode channels0/1 stay inactive. Software-owned steady lamps only; no hardware-owned audio/mic/route/preset writes.'},
    'American Audio 19MXR': {'url': 'https://assets.centryngroup.com/dl/files/MXR941__DL__002.pdf', 'sha256': '93e5c0edfecd27f57aa8f793f8f51f4570f7ae232f47f29651975aca1c831cb1', 'cachePath': 'TestBuilds/r422/upstream/19mxr.pdf', 'reviewedPages': [14, 15],
        'review': 'Own manufacturer table explicitly adds2 to inputs in Controller mode, except LED messages. Native normal raw2, Shift release guards raw3 and lamps raw0. Four physical strips map C/A/B/D with primary mixer/PFL addresses; the script copied fourth-strip EQ target error is not retained. Three Hot Cues and right Sync55 match this model table. The two filter controls depend on hardware crossfader assignments and remain inactive. PFL rows do not identify lamps, so no PFL LED is invented. Hold Controller Mode during power-on for software mixing; native sends no mode or stored-setting write. Mixer-mode channels0/1 stay inactive.'}}


def mxr_profiles():
    """Return separate model subsets with hardware Shift release aliases."""
    result = []
    for size in [10, 14, 19]:
        name = f'American Audio {size}MXR'; ref = MXR_REFERENCES[name]
        p = profile(name, ref['url']); ch = 0 if size == 10 else 2
        p.update(definition=f'manufacturer:mxr-{size}', autoSelect=size != 10,
            aliases=[name, f'American Audio {size} MXR', f'{size}MXR', f'{size} MXR'],
            excludedAliases=[f'American Audio {other}MXR' for other in [10, 14, 19] if other != size],
            hardwareMode=('Select manually with separate app audio. The 10MXR hardware mixer route is not configured by this profile.' if size == 10 else 'Enter Controller mode by holding its button during power-on. Use the Controller-mode MIDI input; normal and Shift input channels are3/4. Lamps remain on MIDI channel1. Enable C/D separately. Configure app audio separately.'),
            scope='Normal transport, held Cue, native Hot Cues and library; independent manufacturer mixer addresses and steady software lamps. Alternate Shift commands stay inactive.',
            gaps=[ref['review'], 'Full Shift/sampler/FX modes, mic/booth/crossfader assignments, complete state/feedback/lifecycle/audio/USB/OS and physical/iPad/A10X acceptance remain open. No driver, firmware, vendor application, script action or hardware setting runs.'])

        def button(action, number, deck=None, feedback=False):
            add(p, action, ch, number, deck=deck, feedback=feedback)
            p['inputs'].append(dict(p['inputs'][-1], channel=ch+1, releaseOnly=True))

        for deck, play, cue, sync, hot, load in [('a', 13, 12, 21, 18, 101), ('b', 47, 46, 54 if size == 10 else 55, 52, 102)]:
            for action, n in [('play', play), ('cuePreview', cue), ('sync', sync), ('load', load)]: button(action, n, deck, action in ['play', 'cuePreview'])
            for i in range(2 if size == 10 else 3): button(f'hotcue{i+1}', hot+i, deck, True)
        decks = 'ab' if size == 10 else 'cabd'
        for i, deck in enumerate(decks):
            for action, offset in [('gain', 0), ('high', 1), ('mid', 2), ('low', 3), ('level', 4)]: add(p, action, ch, 5*i+offset, 'control', deck=deck)
            if size != 19: add(p, 'filterKnob', ch, 37+2*i, 'control', deck=deck)
            if size != 10: button('cue', 42+i, deck, size == 14)
        for action, number in [('crossfader', 31), ('master', 28), ('cueMix', 34), ('monitor', 35)]: add(p, action, ch, number, 'control')
        add(p, 'browse', ch, 52, 'control', 'binaryStep')
        for action, number in [('openGroup', 107), ('browsePreviousGroup', 103), ('browseNextGroup', 104), ('browsePrevious', 105), ('browseNext', 106)]: button(action, number)
        for output in p['outputs']: output['channel'] = 0
        p['bankChanges'] = [{'channel': channel, 'number': 109, 'anyPositive': True, 'decks': list(decks), 'releaseShiftChannels': []} for channel in [ch, ch+1]]
        selectors = [(89, 'a'), (6, 'b')] if size == 10 else list(zip(range(89, 93), decks))
        for channel in [ch, ch+1]:
            for number, deck in selectors: p['bankChanges'].append({'channel': channel, 'number': number, 'onValue': 127, 'decks': [deck], 'releaseShiftChannels': []})
            if size != 10: p['bankChanges'].append({'channel': channel, 'number': 108, 'onValue': 127, 'decks': list(decks), 'releaseShiftChannels': []})
        result.append(p)
    return result

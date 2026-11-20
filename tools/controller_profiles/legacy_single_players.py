"""Independent manufacturer defaults for four legacy single-player controllers."""
from curated import add, profile

SINGLE_PLAYER_REFERENCES = {
    'Audiophony CDX6': {'url': 'https://audiophony.com/downloads/CDX6_manuel-v4.0-fr-en-2016-03-07.pdf',
        'files': [{'cachePath': 'TestBuilds/r427/upstream/cdx6.pdf', 'sha256': 'c379218e01d522c865dab376b9052092b8928c8825d7f8e698aff7e28be419fd'}], 'pages': [36, 42, 43, 44]},
    'CITRONIC MPCD-X3': {'url': 'https://www.billebro.se/proddoc/PRID_5059_doc_170650.pdf',
        'files': [{'cachePath': 'TestBuilds/r427/upstream/mpcdx3.pdf', 'sha256': 'b1d00fbd18275ea9607aa28995d822d2097b0bf20efbae68ad4a985c3a92e8c5'}], 'pages': [11, 15, 16]},
    'Stanton CMP.800': {'url': 'https://www.recordcase.de/media/05/98/d0/1700636186/stanton-cmp-800-user-manual-en.pdf?ts=',
        'files': [{'cachePath': 'TestBuilds/r427/upstream/cmp800.pdf', 'sha256': '1514233ec520f470faefbcee9703bd91c06f887b197b0e2eada1d766165d4287'}], 'pages': [6, 16, 17], 'visuallyReviewedPages': [16]},
    'Synq DMC-1000': {'url': 'https://synq-audio.com/fileuploader/download/download/?d=0&file=custom%2Fupload%2FFile-1418208135.pdf&name=DMC-1000_Manual',
        'files': [{'cachePath': 'TestBuilds/r427/upstream/dmc1000.pdf', 'sha256': 'a9f43c198d85ad1248090ec203ca572755977f3f94760a61f34e31c82d2b9a26'}, {'cachePath': 'TestBuilds/r427/upstream/dmc1000-vdj.zip', 'sha256': '8715e3274bd835b1f2643fd7435148c7be84afa2ddd9a31b3322ec847390759c'}, {'cachePath': 'TestBuilds/r427/upstream/DMC1000.xml', 'sha256': '453a25770286c3297c66b0bf7fecb78cc0b49985cccbc90845fec7ac1649f84f'}],
        'pages': [8, 9, 10], 'visuallyReviewedPages': [9], 'pageNumbering': 'PDF pages, two printed pages per sheet',
        'relatedSources': [{'url': 'https://synq-audio.com/dmc-1000'}, {'url': 'https://synq-audio.com/fileuploader/download/download/?d=0&file=custom%2Fupload%2FFile-1438591800.zip&name=DMC-1000_MIDIMAP_Virtual_DJ', 'member': 'MAPPINGS/DMC1000.xml'}]}}

for name, ref in SINGLE_PLAYER_REFERENCES.items():
    ref['review'] = ('Own manufacturer-authored guide independently qualifies normal channels1/2, buttons and +63 alternate addresses, relative CC49/51/53 centred64, optional separate directional Notes49..54, touch19, default pulse1024 and literal NoteOn127/0 lamp packets. Firmware similarity is not protocol evidence. ' +
        ('Manufacturer USB names DMC1K through DMC1KH qualify distinct identity. Its own distributed device definition corroborates full1024 jog, inverted pitch-bend and note lamps. ' if name.startswith('Synq') else 'Generic MIDI/MIDI B..H names require manual selection. No Synq identity, pitch direction or conditional role is inherited. ') +
        'Use MIDI source, unedited defaults, channel pair1/2, Shift Hold, relative CC type and pulse1024. Set hardware A/B per unit. NOTE encoders are also supported. Absolute encoder mode and pulse512 are not supported by this recipe. Native treats bank/Shift/wheel changes as source-owned cleanup before new controls. Fixed channel0/1 targets are app A/B, not automatic player assignment. Normal Play/Cue/bends/key lock/manual loops/Load/group and contact-gated wheel/library are implemented. Pads, cue-memory/sample/edit/Hold/FX/Sync, complete alternate controls, pitch except independently corroborated Synq, display/meters/lifecycle/audio/host/OS and physical/iPad/A10X acceptance remain open. Guides mislabel literal0x9n note status as Control Change. ProMixer CC lamp commands and copied software roles are not used. No source action, stored setting, firmware, driver or mode write runs.')


def legacy_single_player_profiles():
    """Return only independently documented normal controls and safe release aliases."""
    result = []
    for name, ref in SINGLE_PLAYER_REFERENCES.items():
        synq = name.startswith('Synq')
        p = profile(name, ref['url'])
        p.update(definition='reviewed:legacy-single-' + {'Audiophony CDX6': 'cdx6', 'CITRONIC MPCD-X3': 'mpcdx3', 'Stanton CMP.800': 'cmp800', 'Synq DMC-1000': 'dmc1000'}[name],
            autoSelect=synq, inputProtocol='legacySinglePlayer',
            aliases=[name, name.split(' ', 1)[1]] + (['DMC1K'] + ['DMC1K' + suffix for suffix in 'BCDEFGH'] if synq else []),
            excludedAliases=['MIDI', 'MIDI B', 'USB Audio Device', name + ' clone'],
            hardwareMode='Select MIDI source and unedited defaults. Use MIDI channels1/2, Shift Hold, relative CC type, pulse1024 and normal Vinyl mode. Set hardware Player A/B per unit. NOTE encoder format also works. Configure app audio separately.',
            scope='Normal A/B transport, held Cue/bends, key lock, manual loops, Load, library, contact-gated1024-count relative/NOTE jog and four steady lamps per deck. Bank/Shift/wheel changes retire only the reporting source.', gaps=[ref['review']])
        for channel, deck in [(0, 'a'), (1, 'b')]:
            for action, wire in [('play', 2), ('cuePreview', 46), ('pitchBendDown', 3), ('pitchBendUp', 9), ('keylock', 30), ('loopIn', 4), ('loopOut', 23), ('reloop', 29), ('loop', 48), ('load', 37), ('openGroup', 43), ('jogTouch', 19)]:
                add(p, action, channel, wire, deck=None if action == 'openGroup' else deck, feedback=action in ['play', 'cuePreview', 'keylock', 'loop'])
                add(p, action, channel, wire + 63, deck=None if action == 'openGroup' else deck); p['inputs'][-1]['releaseOnly'] = True
            for kind, wire, encoding, inverted in [('control', 53, 'binaryOffset', False), ('note', 53, 'noteStep', False), ('note', 54, 'noteStep', True)]:
                add(p, 'jog', channel, wire, kind, encoding, deck); p['inputs'][-1].update(argument=1024, requiresTouch=True, inverted=inverted)
            for action, wire in [('browse', 51), ('browseGroups', 49)]: add(p, action, channel, wire, 'control', 'binaryOffset')
            for action, wire in [('browseNextGroup', 49), ('browsePreviousGroup', 50), ('browseNext', 51), ('browsePrevious', 52)]:
                add(p, action, channel, wire); p['inputs'][-1]['pulse'] = True
            if synq:
                add(p, 'tempo', channel, 0, 'pitch', 'centredPitch', deck); p['inputs'][-1]['inverted'] = True
        result.append(p)
    return result

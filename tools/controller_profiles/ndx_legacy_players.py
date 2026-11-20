"""Separate NDX800/900 normal MIDI facts and manufacturer USB-mode evidence."""
from curated import add, profile
from promixer_public import INSTALLER, INSTALLER_SHA

NDX_LEGACY_REFERENCES = {
    'Numark NDX800': {'url': INSTALLER, 'sha256': INSTALLER_SHA, 'member': 'Devices/NUMARK NDX-800 (Single A).xml',
        'files': [{'cachePath': 'TestBuilds/r388/upstream/documents/Devices/NUMARK NDX-800 (Single A).xml', 'sha256': '49d8a7182ea8d2c434a6079998b89ad3ed12985e3d9ea163d60753299a7c8df8'}, {'cachePath': 'TestBuilds/r426/upstream/ndx800.pdf', 'sha256': 'ac79aef922a617c65fcfcccb9603741169c041edc1d7f13ecf725900f768f953'}, {'cachePath': 'TestBuilds/r426/upstream/ndx800-cue.zip', 'sha256': '361f2a03f35901664ecf66d06d8306aa0c1de649c24d9e2931519485801c825e'}, {'cachePath': 'TestBuilds/r426/upstream/ndx800-mapping.xml', 'sha256': '074aeeaf3dc8c82b5ff911b6aefc521f4bf6bc9ea2ddf68b29b3001114090ca4'}],
        'relatedSources': [{'url': 'https://www.numark.com/product/ndx800', 'review': 'Manufacturer explicitly lists class-compliant MIDI and iOS compatibility; physical acceptance remains separate.'}, {'url': 'https://www.numark.com/images/product_downloads/ndx800___quickstart_guide___v1.4.pdf'}, {'url': 'https://www.numark.com/images/product_downloads/ndx800___cue_controller_mapping_file.zip'}],
        'review': 'Own public ProMixer Single-A input rows qualify normal Play58/Cue56/bends60/61/Load70/loop48/49/50, strict browseCC33 values1/127 and inverted pitch-bend. Manufacturer guide and CUE setup instructions require SOURCE/PARAMETER to select USB-MIDI. Published CUE mapper is semantic corroboration only, not a wire definition: RANGE distinguishes short pitch-range from held Key Lock; separate Pause is not a native toggle. Its copied MIXDECK refresh action never runs. Source phantom CC133 and zero-number placeholders are ignored, including selector0/rangeup69. No numeric selector or mode reset is inferred from900. Jog/contact calibration, conditional pads/record/Hold/FX/browser, unqualified Sync/key-lock/Pause commands, full output/display/state/lifecycle/audio/host and physical/iPad/A10X acceptance remain open. No NDX500 or900 startup is inherited.'},
    'Numark NDX900': {'url': INSTALLER, 'sha256': INSTALLER_SHA, 'member': 'Devices/NUMARK NDX-900 (Single A).xml',
        'files': [{'cachePath': 'TestBuilds/r388/upstream/documents/Devices/NUMARK NDX-900 (Single A).xml', 'sha256': '7882253e7ee503b60267bda12f9b39b048e69ebd235a2fb575feb8d5f28a1031'}, {'cachePath': 'TestBuilds/r426/upstream/ndx900.pdf', 'sha256': 'b9cfceaf99c294b5c10e84279317ac18d7bcce8ae06662efc48e36b4a124cbcc'}],
        'relatedSources': [{'url': 'https://www.numark.com/product/ndx900controller', 'review': 'Own product page lists driver-free class-compliant MIDI/audio and iOS compatibility; native does not infer automatic multi-interface routing.'}, {'url': 'https://www.numark.com/images/product_downloads/ndx900___quickstart_guide___v1.2.pdf'}],
        'review': 'Own separate public input definition qualifies the same bounded normal Play/Cue/bend/Load/manual-loop/browse/pitch wires. Native does not infer the NDX800 pad, range/Hold, display or lifecycle contract. Its own manufacturer guide requires USB-MIDI source mode. Each attached unit receives an app player assignment; accepted MIDI channels address that owned player rather than app deck numbers. Cue/Sampler mode69 retires only that source-owned player. Native pitch follows app range; hardware range changes are not implemented. Full jog/contact calibration, conditional pads/FX/record/Hold, separate Pause/key-lock/Sync semantics, feedback/display/lifecycle/audio/host/OS and physical/iPad/A10X acceptance remain open. No stored setting, software action, driver, firmware or vendor program runs.'}}


def ndx_legacy_profiles():
    """Return independent bounded player recipes; unresolved commands stay inactive."""
    result = []
    for number in [800, 900]:
        name = f'Numark NDX{number}'; ref = NDX_LEGACY_REFERENCES[name]
        p = profile(name, ref['url'])
        p.update(definition=f'reviewed:ndx-legacy-{number}', role='player',
            aliases=[name, f'Numark NDX-{number}', f'NDX{number}', f'NDX-{number}', f'NDX{number} Controller'],
            excludedAliases=[f'Numark NDX{other}' for other in [500, 800, 900] if other != number],
            hardwareMode='Select USB-MIDI with SOURCE/PARAMETER. Each connected player receives its own app deck assignment. Use normal transport mode and configure app audio separately. Pitch follows app range.',
            scope='Automatic single-player normal transport, held Cue/bends, Load, manual loop anchors/reloop, full pitch position and strict slow browse steps. MIDI channels retain source-owned player assignment.',
            gaps=[ref['review']])
        for action, wire in [('play', 58), ('cuePreview', 56), ('pitchBendDown', 60), ('pitchBendUp', 61), ('load', 70), ('loopIn', 48), ('loopOut', 49), ('reloop', 50)]:
            add(p, action, 0, wire, deck='a')
        add(p, 'tempo', 0, 0, 'pitch', 'centredPitch', 'a'); p['inputs'][-1]['inverted'] = True
        add(p, 'browse', 0, 33, 'control', 'signedStep')
        for row in p['inputs']: row['anyChannel'] = True
        if number == 900:
            p['bankChanges'] = [{'channel': 0, 'anyChannel': True, 'number': 69, 'anyPositive': True, 'decks': ['a']}]
        result.append(p)
    return result

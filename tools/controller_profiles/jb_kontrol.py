"""Independent JB Systems normal controls from each manufacturer's Traktor download."""
from curated import add, profile

COMMAND_REFERENCE = 'https://raw.githubusercontent.com/cmdr-editor/cmdr/5b7950272a55f73034d2df15de2917248e2e9616/cmdr/cmdr.TsiLib/Commands/Interpretation/KnownCommands.cs'
JB_REFERENCES = {}
for model, file_id, archive, archive_sha, tsi, tsi_sha in [
    (2, '1438086881', 'TestBuilds/r428/upstream/jb-kontrol2-traktor-response.bin', '81985dd3c3e63d70ab29b47abd0fc417967a34db2576717335cc54d11733f82a', 'TestBuilds/r428/upstream/jb-kontrol2-mapping/JBS - DJ KONTROL 2.tsi', '91b3d2ca7e5ec15916a62a9b8c281b0f87a7cdcd63c0265080eddbfb5d2184a7'),
    (3, '1438088622', 'TestBuilds/r429/upstream/jb-kontrol3-traktor.zip', '2642779fd7a8f56561bd3622a101b6d6febb84bf69f068c0b33bcf99a7084119', 'TestBuilds/r429/upstream/jb-kontrol3-mapping/JBS - DJ KONTROL 3.tsi', 'f784eeb79f1fc983a0e8fa89418aa2317cf8b0c682a3fe89eaa3c9392303858a')]:
    JB_REFERENCES[f'JB Systems DJ KONTROL{model}'] = {
        'url': f'https://jb-systems.eu/fileuploader/download/download/?d=0&file=custom%2Fupload%2FFile-{file_id}.zip&name=DJ-KONTROL{model}_TR2',
        'archiveMember': f'JBS - DJ KONTROL {model}.tsi',
        'files': [{'cachePath': archive, 'sha256': archive_sha}, {'cachePath': tsi, 'sha256': tsi_sha}, {'cachePath': 'TestBuilds/r429/upstream/cmdr-commands.cs', 'sha256': '7594c34a77b2f72480f2e0d0b70db500e4cddc71f30fae08043b87d8fde8e6e9'}],
        'relatedSources': [{'url': f'https://jb-systems.eu/dj-kontrol-{model}'}, {'url': COMMAND_REFERENCE}],
        'review': 'Own manufacturer product page identifies this separate Traktor download. Bounded read-only TSI inspection qualifies normal channel1 Play100, Load3076, PFL119, loop anchors2392/2393, volume102/gain117/high303/mid302/low301/tempo123, crossfader5, Cue mix17 and list browse3200. Pinned CMDR source independently names the numeric software commands. Traktor MIDI note naming uses C-1=0. Every active role, target, wire and inversion is checked against this own file. Pitch and crossfader are explicitly inverted, unlike the separate Beyond Music native assignments. Encoder mode1 qualifies only1/127 steps. Source Cue is CUP204, not a held native Cue contract. Shared Key Lock/modifiers, Sync/bends, conditional pads/Shift/FX/kill/loop functions, wheel format/calibration/contact, position strips, all output ranges/polarity, full lifecycle/identity/USB/OS/audio and physical/iPad/A10X acceptance remain open. Native uses independent loop anchors and app pitch range. Manual selection and separate app audio are required. No Beyond Music, KONTROL1/3S/4 identity or protocol is inherited. No TSI/software action, saved preference, preset, firmware or driver executes.'}


def jb_kontrol_profiles():
    """Return only independent normal roles with qualified wire direction and targets."""
    result = []
    for model in [2, 3]:
        name = f'JB Systems DJ KONTROL{model}'; ref = JB_REFERENCES[name]
        p = profile(name, ref['url'])
        p.update(definition=f'reviewed:jb-kontrol-{model}-normal', autoSelect=False,
            aliases=[name, f'JB Systems DJ-KONTROL {model}', f'DJ-KONTROL {model}', f'DJ KONTROL{model}'],
            excludedAliases=['ABMA USBAUDIO', 'Beyond Music ABMA1', 'Beyond Music ABMA3', 'DJ-KONTROL 1', 'DJ-KONTROL 3S', 'DJ-KONTROL 4'],
            hardwareMode='Select this model manually. Use normal MIDI channel1 controls and separate app audio. Native loop anchors and app pitch range apply. CUP, Shift/FX/pads/wheel and lights remain inactive.',
            scope='Manual25-input normal Play/Load/PFL/manual-loop anchors, mixer/pitch and strict library steps from this model’s own factory TSI. Full transport/modes/feedback/identity/audio remain open.', gaps=[ref['review']])
        for deck, buttons, axes in [('a', [67, 75, 85, 73, 74], [8, 13, 16, 18, 20, 11]), ('b', [76, 52, 86, 77, 78], [9, 14, 17, 19, 21, 12])]:
            for action, wire in zip(['play', 'load', 'cue', 'loopIn', 'loopOut'], buttons): add(p, action, 0, wire, deck=deck)
            for action, wire in zip(['level', 'gain', 'high', 'mid', 'low', 'tempo'], axes):
                add(p, action, 0, wire, 'control', deck=deck)
                if action == 'tempo': p['inputs'][-1]['inverted'] = True
        add(p, 'crossfader', 0, 10, 'control'); p['inputs'][-1]['inverted'] = True
        add(p, 'cueMix', 0, 32, 'control')
        add(p, 'browse', 0, 26, 'control', 'signedStep')
        result.append(p)
    return result

"""Independent original2000 and2000NXS manufacturer Zone1 mixer facts."""
from curated import profile
from legacy_djm_mixers import add_reviewed_djm_inputs

DJM2000_REFERENCES = {
    'Pioneer DJM-2000': {
        'url': 'https://static.bhphoto.com/lit_files/88476.pdf', 'cacheName': 'djm2000-manual.pdf',
        'sha256': 'f617eb68e798b0376bf65cfa995b52811a56abfd3f79608a993db68ba5268c12', 'pages': [19, 20, 25],
        'review': 'Manufacturer hexadecimal control-panel chart pages19/20 were visually reviewed. They independently qualify32 selected mixer inputs, including direct Cue CC46-49hex. Page25 specifies separate Zone1/Zone2 MIDI channels and Toggle/Trigger settings. Require Zone1 channel1/Toggle and Zone2 channel2 to separate editable touchscreen MIDI. No factory-default, NXS compatibility or undocumented source report is inferred. Touchscreen Frequency Mix/Sidechain Remix, editable TypeA-D, hardware FX/mic, full lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open.'},
    'Pioneer DJM-2000NXS': {
        'url': 'https://www.dimmer.fr/wp-content/uploads/2022/01/Pioneer-DJM-2000-Nexus-Manual-DE-EN-FR.pdf', 'cacheName': 'djm2000nxs-manual.pdf',
        'sha256': 'b796ebc63db572fd56096b0e7aa3ad2ad0c26b45b8ded9ee76c498775c39e548', 'pages': [20, 21, 27],
        'review': 'Independent manufacturer hexadecimal control-panel chart pages20/21 were visually reviewed. It separately qualifies32 selected mixer inputs. Page27 documents Zone1/Zone2 channel and Toggle/Trigger settings. Require Zone1 channel1/Toggle and Zone2 channel2; do not infer factory defaults. The cover explicitly names2000NXS and2000nexus. Touchscreen Sync Master/MIDI, Frequency Mix/Sidechain Remix, editable TypeA-D, hardware FX/mic, full lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. No TOUR1 or original2000 mode is inherited.'},
}


def djm2000_profiles():
    results = []
    for name, ref in DJM2000_REFERENCES.items():
        short = name.removeprefix('Pioneer ')
        result = profile(name, ref['url'])
        result.update(autoSelect=False, role='accessory', definition='reviewed:'+short.lower()+'-independent-zone1-mixer',
                      aliases=[name, 'Pioneer DJ '+short, short, short+' MIDI 1'],
                      excludedAliases=['DJM-TOUR1', 'DJM-900NXS', 'DJM-900NXS2', 'DJM-900SRT'],
                      hardwareMode='Manual Zone1 MIDI channel1 and Toggle Cue-button mode. Set editable touchscreen Zone2 to MIDI channel2. Enable MIDI ON/OFF. Physical CH1-4 target native A-D. C/D require app opt-in. Configure audio separately and avoid duplicate hardware/software processing.',
                      scope='Manual32-input independent Zone1 gain/EQ/filter/fader/Cue and global mixer. No touchscreen action, source-selector report, hardware write or automatic audio route.',
                      gaps=['Zone2 editable touchscreen messages must use the separate channel2. Zone1 Frequency Mix/Sidechain Remix and touchscreen controls, Sync Master, hardware FX/mic, curve/assignment, external deck audio, full modes/lifecycle/calibration and physical/iPad/A10X acceptance remain open. Native Filter knobs control the software filter.'])
        if short == 'DJM-2000NXS':
            result['aliases'] += ['DJM-2000nexus', 'Pioneer DJM-2000nexus']
        add_reviewed_djm_inputs(result)
        results.append(result)
    return results

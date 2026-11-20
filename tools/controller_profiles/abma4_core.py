"""Publisher-paired ABMA4 and KONTROL1 normal facts without channel guessing."""
from curated import add, profile

ABMA4_CORE_REFERENCES={'BeyondMusic (BMI) ABMA4':{'url': 'https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg', 'sha256': '55aaca2c33e7f1b84b420ab20f2c261f1c98ee73b62b3c012e25616f39070030', 'files': [{'cachePath': 'TestBuilds/r466/upstream/pcdj-dex4-mac.pkg', 'sha256': '55aaca2c33e7f1b84b420ab20f2c261f1c98ee73b62b3c012e25616f39070030'}, {'cachePath': 'TestBuilds/r466/upstream/pcdj-controllers/Applications/DEX4.app/Contents/Resources/controllers/Beyond__Abm4.js', 'sha256': '8ff2ac21e733a44dbb8caed40b41a376b2d1ca540160c678672b0f88024613f8'}, {'cachePath': 'TestBuilds/r466/upstream/pcdj-mac-data/DEX4.pkg/PackageInfo', 'sha256': '897b328e3ad25188ca281454d2104970c1ff96b4dd6784c43b9ade6552260304'}], 'archiveMember': 'Applications/DEX4.app/Contents/Resources/controllers/Beyond__Abm4.js', 'archiveMemberSHA256': '8ff2ac21e733a44dbb8caed40b41a376b2d1ca540160c678672b0f88024613f8', 'relatedSources': [{'url': 'https://pcdj.com/dj-software/dj-controllers/'}], 'review': 'Publisher DEX4.0.0 build98 public Mac archive, dated27March2025, verified and read as data with the trusted archive reader. No installer, application or controller script ran. Beyond__Abm4.js explicitly identifies ABMA4 and JBSystems DJ-kontrol1 no-audio, including the latter reported VID0014/PID0804 and separate ABM4 identity prefix00207B00010004. These identifiers are evidence, not native matching or query packets. Input device-name functions return false. The MIDI callback accepts separate status and channel arguments and does not branch on channel. Native therefore accepts n through a bounded manual unbanked two-deck core; stored channel0 is a placeholder, not a factory-channel claim. Each wire and action is unique. Every native row is checked against an explicit callback case: A/B Play67/76, held Cue51/60, Sync64/71, Keylock56/63, Load75/52, PFL85/86, bends-/+121/120 and104/103, loop half114/97 and double113/96. Absolute A/B gain13/14, high16/17, mid18/19, low20/21 and level8/9, global cueMix32/monitor34 and inverted cross10 preserve the publisher roles. CuePlay59/68 is not held Cue. Conditional Hot Cues/Delete, loop In/Out/Reloop and Smart Loop modes, touch/vinyl/jog calibration, filters/position, pitch/range, FX/kill/reset/reverse, browser and all feedback remain inactive. Browser/jog edge64 and full relative format are not inferred from the source expression. Native does not import source init/deinit LED sequences, delays, identity discovery or state writes. Automatic identity, complete MIDI activation/lifecycle/recovery, source settings, exact USB/driver/OS/power/audio/DVS and physical/iPad/A10X acceptance remain open. Requires an already exposed CoreMIDI source and separate app audio. The bounded contract rejects automatic selection, non-unique wires/actions, wrong targets, hidden C/D, modes/modifiers/banks, special encodings, setup/output/audio and inverted controls other than the crossfader. No ABMA1/2/3 or KONTROL2/3/3S/4 protocol is inherited.'}}
ABMA4_CORE_REFERENCES['JB Systems DJ KONTROL1']=ABMA4_CORE_REFERENCES['BeyondMusic (BMI) ABMA4']


def abma4_core_profiles():
    """Return separate manual identities for the explicitly paired MIDI definition."""
    results=[]
    for name,aliases in [
        ('BeyondMusic (BMI) ABMA4',['BeyondMusic (BMI) ABMA4','Beyond Music ABMA4','Beyond Music Abm4','ABMA4','ABM4']),
        ('JB Systems DJ KONTROL1',['JB Systems DJ KONTROL1','JB Systems DJ-KONTROL 1','DJ-KONTROL 1','DJ KONTROL1']),
    ]:
        ref=ABMA4_CORE_REFERENCES[name]
        p=profile(name,ref['url'])
        p.update(autoSelect=False,definition='reviewed:publisher-abma4-kontrol1-normal-'+('abma4' if name.startswith('Beyond') else 'kontrol1'),
            aliases=aliases,excludedAliases=['ABMA1','ABMA2','ABMA3','DJ-KONTROL 2','DJ-KONTROL 3','DJ KONTROL3S','DJ KONTROL4'],
            hardwareMode='Select this profile manually for the publisher-reported model. Use an existing MIDI connection and configure app audio separately. The normal controls accept MIDI channel changes. Jog, pads, Smart Loop and other mode buttons require separate support.',
            scope='Manual33-input normal A/B core: Play, held Cue/bends, Sync/Keylock, Load/PFL, loop half/double, channel mixer and headphone controls, and an inverted crossfader. No automatic identity, setup, feedback or audio route.',
            gaps=[ref['review']])
        for deck,notes in [('a',[67,51,64,56,75,85,121,120,114,113]),('b',[76,60,71,63,52,86,104,103,97,96])]:
            for action,n in zip(['play','cuePreview','sync','keylock','load','cue','pitchBendDown','pitchBendUp','loopDown','loopUp'],notes):add(p,action,0,n,deck=deck)
        for deck,values in [('a',[13,16,18,20,8]),('b',[14,17,19,21,9])]:
            for action,n in zip(['gain','high','mid','low','level'],values):add(p,action,0,n,'control',deck=deck)
        for action,n in [('crossfader',10),('cueMix',32),('monitor',34)]:
            add(p,action,0,n,'control')
            if action=='crossfader':p['inputs'][-1]['inverted']=True
        for row in p['inputs']:row['anyChannel']=True
        results.append(p)
    return results

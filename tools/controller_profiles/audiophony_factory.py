"""Independent DJazz Pro and DJam Ultimate factory facts, read as data."""
from copy import deepcopy
from curated import add, profile

AUDIOPHONY_FACTORY_REFERENCES = {}

AUDIOPHONY_FACTORY_REFERENCES['Audiophony DJAZZ'] = {'url': 'https://www.audiophony.com/downloads/DJazz-Pro_manuel-V1-2011-12.pdf', 'sha256': '2deb5d54906082cef84a472e881efd2efe4df3e3fff6a4ac5c53e638c6578633', 'files': [{'cachePath': 'TestBuilds/r460/upstream/djazz-pro-manual.pdf', 'sha256': '2deb5d54906082cef84a472e881efd2efe4df3e3fff6a4ac5c53e638c6578633'}, {'cachePath': 'TestBuilds/r460/upstream/djazz-vdj.zip', 'sha256': 'c18ea7120db230c308ad83dde8d609be98a81db079a104ad0322e1388ce4de7f'}, {'cachePath': 'TestBuilds/r460/upstream/djazz-vdj/Audiophony DJazz mapping.xml', 'sha256': '3422d4ab792c79b093946a732926349306cdf57b0bdfeb7b3b9bcd09b6e2b003'}, {'cachePath': 'TestBuilds/r460/upstream/djazz-vdj/DJAZZMIDI.xml', 'sha256': 'b474834803d9d99f6844b227108ced50289b6c676dd2908e08341fd9d53a0fd3'}, {'cachePath': 'TestBuilds/r460/upstream/djazz-vdj/read me_lisez moi.txt', 'sha256': '3038d225393a77c0f172cfb2d213324f54d8f16f16ab4547598daddbf46ca9ae'}], 'relatedSources': [{'url': 'https://www.eurobaltronics.com/files/downloads/16002_Audiophony_DJazz_mapping_virtual_DJ.zip'}, {'url': 'https://virtualdj.com/products/hardware.html?model=DJAZZ'}], 'review': 'Own DJazz-Pro v1 December2011 manual and separate Atomix factory XML/mapper from the public reseller archive, read only as data. Catalogue DJAZZ identity follows the official linked manufacturer model. Published mapping channels1..4, Hold Shift default. Normal NOTE Play24/Cue23/Sync18/Keylock16/PFL28/Loop1/In4/Out5/Active6/Bends19/20, Hot Cues8..11, Load34 on A/C and35 on B/D, contact38; shifted note releases plus50. Shifted Hot Cues58/59 seek native -4/+4 beats; other shifted positives remain inactive. Normal CC2 jog uses offset64 and own full count 150. Normal loopCC1 and browser14/44 also use offset64. Own inverted14bit pitch is mapped to native +/-8percent. Shift45 guards normal jog/tempo/loop/Mid/Low; Shift Low36 controls native filter. Gain3/33, High4/34 and Level7/37 mirror their actions. Global cross16/46, cueMix19/49 and monitor20/50 are independently listed. Normal browser push39 enters a group and89 only rearms. Deck17/67 retires only its source-owned A/C or B/D pair. Normal optional lamps exclude unpublished AutoLoop/meter/mode lamps. DJazz master12/42 appears in XML but not its own manual MIDI chart and stays inactive. Saved channel presets, exact startup state/discovery, complete jog/search/tempo-range/FX/sample/key/kill/delete modes, full feedback/screens/lifecycle/recovery, USB/OS/power/audio/DVS routing and physical/iPad/A10X acceptance remain open. No mapper, executable, setup, identity query, source-mode, preset, driver, firmware or audio-route write runs. Other Audiophony/DDC/Voxoa model bytes are not inherited.'}

AUDIOPHONY_FACTORY_REFERENCES['Audiophony DJAM'] = {'url': 'https://www.audiophony.com/downloads/DJam-ultimate_manuel-V1-2011-12.pdf', 'sha256': 'e927df4b4956fe2b3fc2fa0a07f2ef644b9079a36a0d0d1929f1637746219b69', 'files': [{'cachePath': 'TestBuilds/r460/upstream/djam-ultimate-manual.pdf', 'sha256': 'e927df4b4956fe2b3fc2fa0a07f2ef644b9079a36a0d0d1929f1637746219b69'}, {'cachePath': 'TestBuilds/r460/upstream/djam-vdj.zip', 'sha256': 'f4e254a3e9753418039e2a8674538c8a4c08865855cb691c90b4dacde320eb8a'}, {'cachePath': 'TestBuilds/r460/upstream/djam-vdj/Audiophony DJam mapping.xml', 'sha256': '732ef9483e596952aeec337ed79d0a758dddf4ff7510e77f26101baddeff397c'}, {'cachePath': 'TestBuilds/r460/upstream/djam-vdj/DJAMMIDI.xml', 'sha256': 'fbb81f8a89b9df378b84dffe7fe577db960b7193668541957d556f458cbbc9be'}, {'cachePath': 'TestBuilds/r460/upstream/djam-vdj/read me_lisez moi.txt', 'sha256': 'f5cad57aab3ba7cacb182ab04152179b9e52fc39737e17230252951a09ee608e'}], 'relatedSources': [{'url': 'https://www.eurobaltronics.com/files/downloads/16001_audiophony-djam-ultimate-midi-controller_Virtual_DJ_mappings.zip'}, {'url': 'https://virtualdj.com/products/hardware.html?model=DJAM'}], 'review': 'Own DJam-ultimate v1 December2011 manual and separate Atomix factory XML/mapper from the public reseller archive, read only as data. Catalogue DJAM identity follows the official linked manufacturer model. Published mapping channels1..4, Hold Shift default. Normal NOTE Play24/Cue23/Sync18/Keylock16/PFL28/Loop1/In4/Out5/Active6/Bends19/20, Hot Cues8..11, Load34 on A/C and35 on B/D, contact38; shifted note releases plus50. Shifted Hot Cues58/59 seek native -4/+4 beats; other shifted positives remain inactive. Normal CC2 jog uses offset64 and own full count 800. Normal loopCC1 and browser14/44 also use offset64. Own inverted14bit pitch is mapped to native +/-8percent. Shift45 guards normal jog/tempo/loop/Mid/Low; Shift Low36 controls native filter. Gain3/33, High4/34 and Level7/37 mirror their actions. Global cross16/46, cueMix19/49 and monitor20/50 are independently listed. Normal browser push39 enters a group and89 only rearms. Deck17/67 retires only its source-owned A/C or B/D pair. Normal optional lamps exclude unpublished AutoLoop/meter/mode lamps. DJam master12/42 is corroborated by its own manual and XML. Rear MIXER STATUS selects analogue MIX or MIDI. Automatic core excludes all mixer/PFL/global browser controls; full mixer is manual CTRL MIDI only, with normal reverse/curve settings and separate audio configuration. Saved channel presets, exact startup state/discovery, complete jog/search/tempo-range/FX/sample/key/kill/delete modes, full feedback/screens/lifecycle/recovery, USB/OS/power/audio/DVS routing and physical/iPad/A10X acceptance remain open. No mapper, executable, setup, identity query, source-mode, preset, driver, firmware or audio-route write runs. Other Audiophony/DDC/Voxoa model bytes are not inherited.'}

AUDIOPHONY_FACTORY_REFERENCES['Audiophony DJAM (CTRL MIDI mixer)'] = AUDIOPHONY_FACTORY_REFERENCES['Audiophony DJAM']


def _full_profile(model, jog):
    """Build only the rows checked separately in each model's own factory data."""
    name = 'Audiophony ' + model
    manual = model == 'DJAM'
    identifier = name + (' (CTRL MIDI mixer)' if manual else '')
    p = profile(identifier, AUDIOPHONY_FACTORY_REFERENCES[name]['url'])
    p.update(catalogueName=name, autoSelect=not manual,
        definition='reviewed:audiophony-' + model.lower() + '-factory-hold',
        aliases=[identifier, 'DJam Ultimate CTRL MIDI mixer'] if manual else [name, 'DJazz Pro', 'Audiophony DJazz Pro', 'DJAZZ'],
        excludedAliases=['DJinn', 'S70', 'DDC-2000', 'DJAM' if model == 'DJAZZ' else 'DJAZZ'],
        hardwareMode='Published factory mapping channels1..4 and Hold Shift. C/D require app opt-in. Native tempo +/-8percent. ' + ('Select rear MIXER STATUS=MIDI and CTRL MIDI/software source, with normal reverse/curves. Configure audio separately.' if manual else 'Other stored presets need separate qualification.'),
        scope=('Manual213-input CTRL MIDI mixer core, including master.' if manual else 'Automatic211-input published factory core.') + ' Transport/held Cue/bends, four Hot Cues, loops/size, calibrated normal jog/contact, native tempo, mixer/PFL/Load, Shift filter/beat jumps and track/group browse. Thirty-six optional normal lamps. Full theoretical and physical acceptance remain open.',
        bankChanges=[{'channel':ch,'number':n,'anyPositive':True,'decks':list('ac' if ch%2==0 else 'bd'),'releaseShiftChannels':[]} for ch in range(4) for n in [17,67]],
        gaps=[AUDIOPHONY_FACTORY_REFERENCES[name]['review']])
    for ch, deck in enumerate('abcd'):
        for action,n in [('play',24),('cuePreview',23),('sync',18),('keylock',16),('cue',28),('loopIn',4),('loopOut',5),('reloop',6),('pitchBendDown',19),('pitchBendUp',20),('loop',1),('load',34+ch%2),('jogTouch',38)]:
            add(p,action,ch,n,deck=deck,feedback=action in ['play','cuePreview','sync','keylock','cue'])
            add(p,action,ch,n+50,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for slot in range(4):
            add(p,f'hotcue{slot+1}',ch,8+slot,deck=deck,feedback=True)
            add(p,f'hotcue{slot+1}',ch,58+slot,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for action,n in [('gain',3),('high',4),('mid',5),('low',6),('level',7)]:
            add(p,action,ch,n,'control',deck=deck)
            if action in ['mid','low']:p['inputs'][-1]['shifted']=False
            else:add(p,action,ch,n+30,'control',deck=deck)
        add(p,'filterKnob',ch,36,'control',deck=deck);p['inputs'][-1]['shifted']=True
        add(p,'loopSize',ch,1,'control','binaryOffset',deck);p['inputs'][-1]['shifted']=False
        add(p,'jog',ch,2,'control','binaryOffset',deck);p['inputs'][-1].update(shifted=False,argument=jog)
        add(p,'tempo',ch,0,'pitch',deck=deck);p['inputs'][-1].update(shifted=False,inverted=True)
        for n,amount in [(58,-4),(59,4)]:
            add(p,'fixedJump',ch,n,deck=deck);p['inputs'][-1]['argument']=amount
            add(p,'fixedJump',ch,n-50,deck=deck);p['inputs'][-1].update(argument=amount,releaseOnly=True)
    globals_ = [('crossfader',16,46),('cueMix',19,49),('monitor',20,50)]
    if manual:globals_.append(('master',12,42))
    for action,normal,shifted in globals_:
        for n in [normal,shifted]:add(p,action,0,n,'control')
    add(p,'browse',0,14,'control','binaryOffset')
    add(p,'browseGroups',0,44,'control','binaryOffset')
    add(p,'openGroup',0,39)
    add(p,'openGroup',0,89);p['inputs'][-1]['releaseOnly']=True
    add(p,'shift',0,45)
    return p


def audiophony_factory_profiles():
    """Keep the DJam mixer switch outside automatic common-player support."""
    jazz = _full_profile('DJAZZ',150)
    mixer = _full_profile('DJAM',800)
    player = deepcopy(mixer)
    player.update(id='Audiophony DJAM',autoSelect=True,
        aliases=['Audiophony DJAM','DJam Ultimate','Audiophony DJam Ultimate','DJAM'],
        excludedAliases=['DJAZZ','DJinn','S70','DDC-2000','CTRL MIDI mixer'],
        definition='reviewed:audiophony-djam-common-players-hold',
        hardwareMode='Published factory mapping channels1..4 and Hold Shift. Common player controls in MIX/MIDI mixer modes. C/D require app opt-in. Native tempo +/-8percent. Audio configuration remains separate.',
        scope='Automatic157-input common-player core: transport/held Cue/bends, four Hot Cues, loops/size, calibrated normal jog/contact, native tempo, Load and Shift beat jumps. Thirty-two optional normal lamps. Mixer/PFL/global browser require the manual CTRL MIDI profile. Full theoretical and physical acceptance remain open.')
    mixer_actions={a+suffix for a in ['gain','high','mid','low','level','filterKnob','cue'] for suffix in 'AB'}
    player['inputs']=[r for r in player['inputs'] if r['action'] not in mixer_actions and (r.get('targetDeck') is not None or r['action']=='shift')]
    player['outputs']=[r for r in player['outputs'] if r['action'] not in ['cueA','cueB']]
    return [jazz,mixer,player]

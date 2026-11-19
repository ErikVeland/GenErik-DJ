"""DDC-2000 factory Mode1/Hold facts from separate manufacturer sources."""
from curated import add, profile

DDC_SOURCE='https://www.steinigke.de/download/11045050-Manual-89188-1.100-omnitronic-ddc-2000-controller-incl-vdj-de_en.pdf'
DDC_ZIP='https://www.steinigke.com/download/11045050-Support-85225-1.0000-omnitronic-ddc-2000-controller-incl-vdj-Virtual-DJ-PRO-Mapping-en.zip'
DDC_REFERENCES={'OMNITRONIC DDC-2000':{
    'url':DDC_SOURCE,'sha256':'a9e87f24c127c603b537dcf154592a5f2e6621d014937cd04019d5993effbef0',
    'files':[
        {'cachePath':'TestBuilds/r454/upstream/ddc2000-manual.pdf','sha256':'a9e87f24c127c603b537dcf154592a5f2e6621d014937cd04019d5993effbef0'},
        {'cachePath':'TestBuilds/r455/upstream/ddc2000-vdj.zip','sha256':'f3ecda15b4ed416920461eed388fb61964a14518151db8ce2fe0b917fa090b23'},
        {'cachePath':'TestBuilds/r455/upstream/DDC-2000_Device.xml','sha256':'6f8b9f174534f60957a85829fdfab1034dd65d9e81b587d47b54b59cf86dfb60'},
        {'cachePath':'TestBuilds/r455/upstream/DDC-2000_Mapping.xml','sha256':'bee9717fe81d7d3080f74f8c95a0927feeb773dbdb09c98f180cfdb9750de6d8'}],
    'relatedSources':[{'url':DDC_ZIP},{'url':'https://www.steinigke.com/mpn11045050-omnitronic-ddc-2000-controller-incl-vdj.html'}],
    'review':'Own manufacturer manual pp33..39 and own factory VirtualDJ PRO archive read as data, without executing its mapper. The manual explicitly establishes factory Mode1/raw0..3 A/B/C/D and global0, with Hold Shift default. Each deck has normal NOTE Play24/Cue23/Sync18/Keylock16/PFL28/AutoLoop1/In4/Out5/Active6/Bends19/20, four Hot Cues8..11 and distinct shifted wires plus50. Shifted transport/Hot Cue positives stay inactive, except native fixed beat jumps58=-4 and59=+4. Delete7 is not invented as a held modifier. Factory XML resolves bank-owned Load34 on raw0/2 and35 on1/3, shifted release aliases84/85, binary-offset64 loopCC1/browserCC14/44, inverted14bit pitch bend and normal jogCC2 with150 counts/revolution. Native uses its own +/-8percent tempo range. Shifted loop movement, tempo-range buttons and jog search remain inactive. Touch38 has shifted release88. Normal jog/tempo/loop size and Mid5/Low6 are global-Shift guarded; Shift LowCC36 controls native filter. Gain3/High4/Level7 and shifted33/34/37 deliberately keep the same native actions. Factory XML corroborates manual hexadecimal global shifted columns: cross46, cueMix49 and cueLevel50, rather than conflicting decimal45/48/49. Both layers mirror these three actions. Browser14 steps native tracks, Shift44 steps native groups, normal push39 enters a group and shifted89 only rearms it. Thirty-six optional normal static lamps cover Play/Cue/Sync/Keylock/PFL/four Hot Cues. The manual does not list an AutoLoop lamp; none is invented. Deck17/67 both edges retire only their source-owned physical A/C or B/D pair. The source XML lists extra master/mic controls absent from the manual MIDI chart; these stay inactive. Other stored channel/Shift/sample/EQ settings, hardware configuration chords, complete scratch/seek/range/FX/sample/video/kill/loop-delete modes, full feedback/meters/lifecycle/recovery, exact USB naming/OS/power/audio/DVS routing and physical/iPad/A10X acceptance remain open. Own Mac generic Core Audio and4in/4out statements do not prove an iPad route. No setup, identity query, driver, firmware, preset, source-mode or audio-route write runs. Encore/Voxoa/other OMNITRONIC bytes are not inherited.'}}


def ddc2000_profiles():
    """Return the independently qualified default core with explicit Shift guards."""
    p=profile('OMNITRONIC DDC-2000',DDC_SOURCE)
    p.update(definition='reviewed:ddc2000-mode1-hold',aliases=['OMNITRONIC DDC-2000','DDC-2000','DDC2000'],
        excludedAliases=['DDC-1000','DDC-3000','DDC-4000'],
        hardwareMode='Factory MIDI Mode1 (raw0..3) and Hold Shift only. Other stored presets need separate qualification. C/D require app opt-in. Native tempo is +/-8percent. Full mode/USB/audio ownership remains open.',
        scope='Automatic211-input factory Mode1/Hold core: transport/held Cue/bends, four Hot Cues, manual loops/size, calibrated normal jog/contact, native tempo, mixer/PFL/Load, Shift filter/beat jumps and track/group browse. Thirty-six optional lamps. Full theoretical and physical acceptance remain open.',
        bankChanges=[{'channel':ch,'number':n,'anyPositive':True,'decks':list('ac' if ch%2==0 else 'bd'),'releaseShiftChannels':[]} for ch in range(4) for n in [17,67]],
        gaps=[DDC_REFERENCES['OMNITRONIC DDC-2000']['review']])
    for ch,deck in enumerate('abcd'):
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
        add(p,'jog',ch,2,'control','binaryOffset',deck);p['inputs'][-1].update(shifted=False,argument=150)
        add(p,'tempo',ch,0,'pitch',deck=deck);p['inputs'][-1].update(shifted=False,inverted=True)
        for n,amount in [(58,-4),(59,4)]:
            add(p,'fixedJump',ch,n,deck=deck);p['inputs'][-1]['argument']=amount
            add(p,'fixedJump',ch,n-50,deck=deck);p['inputs'][-1].update(argument=amount,releaseOnly=True)
    for action,normal,shifted in [('crossfader',16,46),('cueMix',19,49),('monitor',20,50)]:
        for n in [normal,shifted]:add(p,action,0,n,'control')
    add(p,'browse',0,14,'control','binaryOffset')
    add(p,'browseGroups',0,44,'control','binaryOffset')
    add(p,'openGroup',0,39)
    add(p,'openGroup',0,89);p['inputs'][-1]['releaseOnly']=True
    add(p,'shift',0,45)
    return [p]

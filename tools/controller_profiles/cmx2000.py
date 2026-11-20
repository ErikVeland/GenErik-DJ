"""CMX-2000 manual native banks use independently checked manufacturer facts."""
from curated import add, profile

CMX_SOURCE='https://www.steinigke.de/download/11045060-Manual-88152-1.000-omnitronic-cmx-2000-2%2B1-channel-midi-controller-de_en.pdf'
CMX_ZIP='https://www.steinigke.de/download/11045060-Support-88193-1.0000-omnitronic-cmx-2000-2+1-kanal-midi-controller-Virtual-DJ-PRO-Mapping-de_en.zip'
CMX_SSL='https://www.steinigke.de/download/11045060-Support-89478-1.0000-omnitronic-cmx-2000-2+1-kanal-midi-controller-Serato-Scratch-Live-Mapping-de_en.zip'
CMX_REFERENCES={'OMNITRONIC CMX-2000':{
    'url':CMX_SOURCE,'sha256':'8fa7ba7a7f6b20220bdc01f77a66742b736eab09d89a5f171e88a6f6b8a127ee',
    'files':[
        {'cachePath':'TestBuilds/r456/upstream/cmx2000-manual.pdf','sha256':'8fa7ba7a7f6b20220bdc01f77a66742b736eab09d89a5f171e88a6f6b8a127ee'},
        {'cachePath':'TestBuilds/r456/upstream/cmx2000-vdj.zip','sha256':'4cf3bd380d72fae140d6dde7a23b12d43fc064887bb12eb3ab1b9f8623fb0ba3'},
        {'cachePath':'TestBuilds/r456/upstream/CMX-2000_Device.xml','sha256':'0e005a0b4e7d9bba54661a2e18aa477a1801f6eb9422d3e3cfcc438a07cd7e6a'},
        {'cachePath':'TestBuilds/r456/upstream/CMX-2000_Mapping.xml','sha256':'7fce073cea0c08ab49d041f509582679d822f9d40fc7f4a4ea83481029c135c8'},
        {'cachePath':'TestBuilds/r456/upstream/cmx2000-ssl.zip','sha256':'28a7ac1cf0cc0828f256d04bfa871d283451baad82f0c9ca883f58d8d295084b'},
        {'cachePath':'TestBuilds/r456/upstream/CMX-2000_Serato_Scratch_Live.xml','sha256':'820d429b5fa8c999d588acb61b22ce97f1bc9f6ffaec4027cc510b58b540ba7d'}],
    'relatedSources':[{'url':CMX_ZIP},{'url':CMX_SSL}],
    'review':'Own manufacturer manual pp39/47/52..54/60..61 and separately supplied VirtualDJ/Serato factory XML read as data. Numeric tables visually reviewed. This manual native119-input layout requires both input selectors USB, MIXER MIDI ON, Shift Lock OFF, normal fader direction and crossfader THRU OFF. Fixed wire channels raw0/1 do not become four invented hardware MIDI pages. Native starts A/B on apply/reconnect; normal Deck25 on each channel selects A/C or B/D in software with one127 press per change. Shifted Deck75 positives stay inactive and both shifted release forms rearm only that source/bank. C/D require app opt-in. Normal Play38/Cue37/Sync35/Keylock30/PFL16/Loop28/In31/Out32/Bends26/27 have explicit shifted plus50 release guards. Out uses native loop-out-or-exit. Native fixed jumps are normal36=-4 and33=+4. Shared Load is raw0 Note1 left/3 right, routed through the corresponding native bank; shifted51/53 only release. Eight left Hot Cues use43/48/49/50/44/45/46/47 for slots1..8. On the right, the manual conflicts with VirtualDJ for slots3/4/7/8. Independent factory Serato B2/B3 controls46/47 corroborate right slots3/4. Right slots1..6 use43/48/46/47/44/45. Uncorroborated right slots7/8 at49/50 remain inactive. Shifted clears only rearm. Mixer CC gain14/high15/mid16/low17/filter18/level19 and shifted54..59 deliberately retain the same native bank-owned actions. LoopCC25 and BrowseCC3/43 use documented binary offset64. Native Shift browse steps groups; normal browse steps tracks and push2 opens a group, shifted52 only rearms it. Global master5/45, cueMix1/41, cueLevel2/42 and cross11/51 deliberately mirror native actions. No jog or tempo fader is invented. Full mixer source/reverse/THRU/curve/Shift Lock ownership, remaining pad/FX/sample/video/fader-start/filter-off/alternate-loop/seek modes, right cues7/8, bank lamps/full feedback/meters/initial positions/startup/shutdown/recovery, USB/OS/audio/DVS routing and physical/iPad/A10X acceptance remain open. No mapper executes and no source init/position query, preset, driver, firmware or audio-route command runs. The source init attribute is not blindly copied as SysEx. DDC-2000 and other OMNITRONIC protocols are not inherited.'}}


def cmx2000_profiles():
    """Return manual A/C and B/D banks with conservative conflicting-pad handling."""
    p=profile('OMNITRONIC CMX-2000',CMX_SOURCE)
    p.update(definition='reviewed:cmx2000-manual-native-banks',autoSelect=False,
        aliases=['OMNITRONIC CMX-2000','CMX-2000','CMX2000'],excludedAliases=['DDC-2000','CMX-1000'],
        hardwareMode='Manual native layout only. Set both inputs USB, MIXER MIDI ON, Shift Lock OFF, fader reverse OFF and crossfader THRU OFF. Starts A/B on apply/reconnect. Deck buttons select A/C and B/D. C/D require app opt-in. Configure audio separately. Other source/curve/reverse modes remain unqualified.',
        scope='Manual119-input native banked transport/held Cue/bends, normal loops/size, four-beat jumps, eight left/six right Hot Cues, gain/EQ/filter/level/PFL/Load, master/crossfader/headphone controls and native track/group browse. No outputs or setup/audio write.',
        bankChanges=[{'channel':bank,'number':25,'releaseNumber':75,'onValue':127,'decks':list('ac' if bank==0 else 'bd'),'deckBank':bank} for bank in range(2)],
        gaps=[CMX_REFERENCES['OMNITRONIC CMX-2000']['review']])
    for bank,deck in enumerate('ab'):
        start=len(p['inputs'])
        for action,n in [('play',38),('cuePreview',37),('sync',35),('keylock',30),('cue',16),('loop',28),('loopIn',31),('loopOutOrExit',32),('pitchBendDown',26),('pitchBendUp',27)]:
            add(p,action,bank,n,deck=deck)
            add(p,action,bank,n+50,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for n,amount in [(36,-4),(33,4)]:
            add(p,'fixedJump',bank,n,deck=deck);p['inputs'][-1]['argument']=amount
            add(p,'fixedJump',bank,n+50,deck=deck);p['inputs'][-1].update(argument=amount,releaseOnly=True)
        add(p,'load',0,1+bank*2,deck=deck)
        add(p,'load',0,51+bank*2,deck=deck);p['inputs'][-1]['releaseOnly']=True
        numbers=[43,48,49,50,44,45,46,47] if bank==0 else [43,48,46,47,44,45]
        for slot,n in enumerate(numbers,1):
            add(p,f'hotcue{slot}',bank,n,deck=deck)
            add(p,f'hotcue{slot}',bank,n+50,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for action,n in [('gain',14),('high',15),('mid',16),('low',17),('filterKnob',18),('level',19)]:
            for number in [n,n+40]:add(p,action,bank,number,'control',deck=deck)
        add(p,'loopSize',bank,25,'control','binaryOffset',deck);p['inputs'][-1]['shifted']=False
        for row in p['inputs'][start:]:row['deckBank']=bank
    for action,n in [('master',5),('cueMix',1),('monitor',2),('crossfader',11)]:
        for number in [n,n+40]:add(p,action,0,number,'control')
    add(p,'browse',0,3,'control','binaryOffset')
    add(p,'browseGroups',0,43,'control','binaryOffset')
    add(p,'openGroup',0,2)
    add(p,'openGroup',0,52);p['inputs'][-1]['releaseOnly']=True
    add(p,'shift',0,9)
    return [p]

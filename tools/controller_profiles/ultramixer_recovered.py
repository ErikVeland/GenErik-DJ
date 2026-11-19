"""Separate public NVII/GO+ facts and the independently recovered DP2 definition."""
from curated import add, profile

NVII='Numark NVII'
GO_PLUS='Denon DJ PRIME GO+'
DP2='American Audio DP2'
BUNDLE_URL='https://downloads.ultramixer.com/downloads/_releases/UltraMixer/current/UltraMixer-6.4.11-ec74c38-Release-64Bit-mac-INTEL.zip'
BUNDLE_SHA='43b6fb3678741f5a49dc23724f0126020bfbfa9f3788a3fefa6f45ec07a549ad'
RECOVERED_REFERENCES={
    NVII:{'url':BUNDLE_URL,'sha256':BUNDLE_SHA,'cacheMember':'documents/res/midi/midimaps/Numark-NV2.xml','memberSHA256':'3a07f44ff1f15a6fdcc0d9bffcd28aa8298311df6017506f09d78dc4e6cf3203',
        'review':'Own named UltraMixer6.4.11 NV2 factory document qualifies channel1..4 Play33/Cue32/Sync31/Load5/bends16/17, channel0 mixer/PFL and explicit CC29/30 side selectors with values0/1. Its input/output body is identical to its separate NV file, but native does not infer startup or alias NV. Native normal transport uses two independent physical Shift identities across A/C and B/D channel aliases. Either Shift edge retires only source-owned holds; selector reports retire their own side and pickup. Pitch, jog/contact, conditional pads/FX/loops/library, complete screens/state/lifecycle/audio and physical acceptance remain open. Manual selection is required. No source action or vendor program runs.'},
    GO_PLUS:{'url':BUNDLE_URL,'sha256':BUNDLE_SHA,'cacheMember':'documents/res/midi/midimaps/Denon-DJ-Prime-Go-Plus.xml','memberSHA256':'adc225afa7c3f49e10de0bf8160b09ba09e867e12e0166cdb6471c77828a4d9c',
        'review':'Own named factory document qualifies a manual normal fixed A/B transport/mixer subset, explicit Shift15/8, signed1/127 loop-size and browse values. Its body is identical to the separately named GO document and its USB identifier is copied across several unrelated files. Native therefore ignores the identifier and does not infer original GO startup, USB host/audio mode, paired pitch, displays, complete modes or lifecycle. The same document labels CC12 master volume while original-model firmware facts use another role, so CC12/13 remain inactive rather than inheriting sibling globals. No setup, stored setting, source action, hardware/audio route or output packet executes. Physical/iPad/A10X acceptance remains open.'},
    DP2:{'url':'https://assets.centryngroup.com/dl/files/DP2__DL__003.zip','sha256':'d1b4aed053f954008eab66945e2db733a36d616466d691abd3ff08a3b6bb844a','cacheMember':'dp2-factory/Devices/American Audio DP2 definition.xml','member':'vdj6_dp2_midi/American_Audio_DP2.exe / Devices/American Audio DP2 definition.xml','memberSHA256':'48e9bd2ef22af5889855ac1f11162e256438382cd0c42458cca74fe6a8f6fd7a',
        'relatedSources':[{'url':'https://www.adj.com/products/dp2'},{'url':'https://assets.centryngroup.com/dl/files/DP2__DL__007.pdf','sha256':'8295dd3afa97fdc9f8f37368b7b9a7b8b8d71b17ec964227d083bfc37173cf27','visuallyReviewedPages':[12]},{'member':'Mappers/American Audio DP2 mapping.xml','sha256':'ef03c6d2aa7d5e451b01e5117203e8e6b376be058892fb02d942d01b0829d54c'}],
        'review':'Own manufacturer public MIDI chart and distributed Atomix device definition independently qualify default channels0/1, separate hardware Shift channels3/4, two physical Shift identities, channel2 globals, binary65/63 browser, inverted pitch position and LED note addresses. Native uses normal controls only; alternate positive commands stay inactive and release-only guards preserve held releases across both families. Manufacturer HIGH CC20, LOW21 and MIC_VOLUME19 versus deck-B MASTER_VOLUME19 override conflicting UltraMixer EQ/master labels. No mid EQ or gain is invented. Pitch follows app range; unknown jog calibration, FX/sampler and complete mode/state/lifecycle/audio/OS behaviour remain open. The USB-MIDI core selects automatically by explicit DP2 names, with separate app audio. No installer, source action, firmware, preset or hardware setting runs.'}}


def normal_button(p,action,channel,number,deck,alternate=None,feedback=False):
    add(p,action,channel,number,deck=deck,feedback=feedback);p['inputs'][-1]['shifted']=False
    p['inputs'].append(dict(p['inputs'][-1],shifted=True,releaseOnly=True))
    if alternate is not None:
        guard=dict(p['inputs'][-1],channel=alternate);guard.pop('shifted');p['inputs'].append(guard)


def recovered_profiles():
    nv=profile(NVII,RECOVERED_REFERENCES[NVII]['url'])
    nv.update(definition='reviewed:ultramixer-nvii-native',autoSelect=False,aliases=[NVII,'Numark NV2','NVII','NV2'],excludedAliases=['Numark NV','NV','Numark NS6II'],
        hardwareMode='Select the NVII profile manually on its normal MIDI input. A/C and B/D keep independent physical Shift identities. Enable C/D in the app separately. Configure audio separately.',
        scope='Manual four-target normal transport, held Cue/bends, five mixer controls per strip, PFL and crossfader. Explicit side selectors retire owned holds and pickup.',
        gaps=['Cold-start setup, pitch/jog/contact calibration, pad/FX/loop/library modes, screens, complete feedback/state/lifecycle/audio/OS and physical/iPad/A10X acceptance remain open.'])
    for i,deck in enumerate('abcd'):
        ch=i+1;add(nv,'shift',ch,13);nv['inputs'][-1]['shiftInput']=i%2
        nv.setdefault('bankChanges',[]).append({'channel':ch,'number':13,'onValue':127,'decks':list('abcd'),'releaseShiftChannels':[]})
        for action,n in [('play',33),('cuePreview',32),('sync',31),('load',5),('pitchBendDown',16),('pitchBendUp',17)]:normal_button(nv,action,ch,n,deck)
        for action,values in [('level',[8,13,19,24]),('gain',[12,17,23,28]),('high',[11,16,22,27]),('mid',[10,15,21,26]),('low',[9,14,20,25])]:add(nv,action,0,values[i],'control',deck=deck)
        add(nv,'cue',0,[53,54,52,55][i],deck=deck)
    for number,decks in [(29,['a','c']),(30,['b','d'])]:
        for value in [0,1]:nv['bankChanges'].append({'kind':'control','channel':0,'number':number,'onValue':value,'decks':decks})
    add(nv,'crossfader',0,7,'control')

    go=profile(GO_PLUS,RECOVERED_REFERENCES[GO_PLUS]['url'])
    go.update(definition='reviewed:ultramixer-prime-go-plus-native',autoSelect=False,aliases=[GO_PLUS,'Denon PRIME GO+','PRIME GO+','PRIME GO PLUS'],excludedAliases=['PRIME GO','Denon DJ PRIME GO','PRIME 2','PRIME 4+'],
        hardwareMode='Select PRIME GO+ manually on an exposed MIDI input in Computer mode. Configure app audio separately. USB host/startup and complete modes remain unqualified.',
        scope='Manual fixed A/B normal transport, held Cue/bends, loop size, library browse, five mixer controls per deck, PFL and crossfader.',
        gaps=['Host/startup and audio ownership, paired pitch/jog/contact calibration, conditional pads/FX, ambiguous CC12/13 globals, complete feedback/displays/state/lifecycle/OS and physical/iPad/A10X acceptance remain open.'])
    add(go,'shift',15,8);go['bankChanges']=[{'channel':15,'number':8,'onValue':127,'decks':['a','b'],'releaseShiftChannels':[]}]
    for i,deck in enumerate('ab'):
        for action,n in [('play',10),('cuePreview',9),('sync',8),('loop',39),('pitchBendDown',29),('pitchBendUp',30)]:normal_button(go,action,i+2,n,deck)
        normal_button(go,'load',15,i+1,deck)
        for action,n in [('level',14),('gain',3),('high',4),('mid',6),('low',8)]:add(go,action,i,n,'control',deck=deck)
        add(go,'cue',i,13,deck=deck);add(go,'loopSize',i+2,32,'control','signedStep',deck);go['inputs'][-1]['shifted']=False
    add(go,'crossfader',15,14,'control');add(go,'browse',15,5,'control','signedStep')

    dp=profile(DP2,RECOVERED_REFERENCES[DP2]['url'])
    dp.update(definition='manufacturer:american-audio-dp2-native',aliases=[DP2,'American Audio DP-2','ADJ-DP2 MIDI','ADJ DP2','DP2'],excludedAliases=['Synq PCM-1','DMC2','DP2 clone'],
        hardwareMode='Default normal DP2 USB-MIDI channels. Native Shift alternate positive commands remain inactive. Configure app audio separately. The pitch slider follows app range.',
        scope='Automatic normal two-deck transport, four Hot Cues, manual loops, held bends, pitch position, two-band mixer, library and global controls with owned Shift release guards.',
        gaps=['Jog/contact calibration, alternate Shift functions, auto-loop selection, sampler/FX/mic, complete modes/state/feedback/lifecycle/audio/OS and physical/iPad/A10X acceptance remain open.'])
    for i,deck in enumerate('ab'):
        for ch in [i,i+3]:
            add(dp,'shift',ch,55);dp['inputs'][-1]['shiftInput']=i
            dp.setdefault('bankChanges',[]).append({'channel':ch,'number':55,'onValue':127,'decks':['a','b'],'releaseShiftChannels':[]})
        buttons=[('play',26),('cuePreview',25),('sync',56),('keylock',57),('cue',53),('load',61),('loopIn',22),('loopOut',23),('reloop',24),('pitchBendDown',59),('pitchBendUp',60)]+[(f'hotcue{j+1}',n) for j,n in enumerate([9,10,11,12])]
        for action,n in buttons:normal_button(dp,action,i,n,deck,alternate=i+3,feedback=action in ['play','cuePreview','sync','keylock','cue'] or action.startswith('hotcue'))
        for action,n in [('level',22),('high',20),('low',21)]:add(dp,action,i,n,'control',deck=deck)
        add(dp,'tempo',i,18,'control',deck=deck);dp['inputs'][-1]['inverted']=True
    add(dp,'master',1,19,'control')
    for action,n in [('crossfader',5),('monitor',3),('cueMix',2)]:add(dp,action,2,n,'control')
    add(dp,'browse',2,1,'control','binaryStep');add(dp,'openGroup',2,1)
    return [nv,go,dp]

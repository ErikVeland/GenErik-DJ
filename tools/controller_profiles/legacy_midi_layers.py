"""Independent X1600 MIDI layers and PCM-1 manufacturer factory input facts."""
from curated import add, profile
X1600='Denon DJ X1600'
PCM1='Synq PCM-1'
BASE='https://cdn.inmusicbrands.com/denondj/legacy/'
PCM_URL='https://synq-audio.com/de/fileuploader/download/download/?d=0&file=custom%2Fupload%2FFile-1438589424.zip&name=PCM-1_MIDIMAP_Traktor_Pro'
LEGACY_LAYER_REFERENCES={
    X1600:{'url':BASE+'dnx1600/dnx1600-ownersmanual.zip','sha256':'98a68fc29fa8f24453bc7c163cae56add0eaefa3cfc40536030f957576ea55ec','cacheName':'x1600-manual.zip','member':'DN-X1600_ownersmanual_english.pdf','memberSHA256':'cd131b07988d02c1d02fd0505852174edebeb6bc93bab0f56664898901dc0f78','visuallyReviewedPages':[24],
        'review':'Own manufacturer manual printed18 explains the enabled MIDI layer and hardware EQ/fader lock on return. Printed20/PDF24 independently qualifies four three-band/fader strips, Cue note buttons, crossfader/master, strip layer reports70..73, preset74, page76 and four distinct parameter/function address pages. Native assigns each page to A/B/C/D: FUNC1/2/3/4 are Play/held Cue/Sync/Load; PARAM1 browse/push group; PARAM2 loop-size/push Auto Loop. Those are explicit native assignments, not claimed factory software actions. Per-strip layer reports reset their own strip; preset/page reports retire owned holds across all four. Manual MIDI channel1 and enabled hardware MIDI layers are required. No gain, headphone globals, hardware bus/FX/mic/booth/feedback writes, X1800/X1850 compatibility or automatic audio route is inferred. Full modes/lifecycle/audio/OS and physical acceptance remain open.'},
    PCM1:{'url':PCM_URL,'sha256':'e039bf8ac16eccc5f97ad0b2f0ebda2baf9ba18d90d95b3a279c7c07a5da4d78','cacheName':'pcm1-traktor.zip','member':'Traktor Settings for PCM1.tsi','memberSHA256':'a32965bbcc64db327a974cd1f3aa2e3edc25b86106c5f633b05b966f47ff0aba','usedRows':156,'inputRows':94,
        'relatedSources':[{'url':'https://synq-audio.com/de/pcm-1'},{'url':'https://synq-audio.com/de/fileuploader/download/download/?d=0&file=custom%2Fupload%2FFile-1418208092.pdf&name=PCM-1_Manual_v1.0','sha256':'38fb14f694f5c1ddf9b83699ed33362ae062600609281376a029015535e70ed3'},{'url':'https://synq-audio.com/de/fileuploader/download/download/?d=0&file=custom%2Fupload%2FFile-1466781040.pdf&name=PCM-1_FAQ_MIDI_problem','sha256':'43e259edeb376db81d9744d57ac95577fba3513d25cffc12c9995ee1ca418ed6'}],
        'review':'Own manufacturer-distributed TSI has156 used rows,94 inputs. Normal transport and mixer channels1/2, globals3, pitch18 inverted, level22, high19/mid20/low21, monitor3/cueMix2 and binary65/63 library come from separate used input definitions. Native normal buttons keep Play26/held Cue25/Sync56/key lock57/PFL53/Load61 and held bends59/60. Shift55 guards normal positives, retires source-owned holds on the documented factory-mapping full-value path and has only the independently used alternate Cue25 release aliases on raw channels3/4. No DP2 inheritance: its manufacturer EQ addresses differ. Generic USB Audio Device names prevent automatic qualification. Unresolved crossfader/master, gain encoder calibration, jog/contact, sampler/FX/loops, full modes/feedback/lifecycle/audio/OS and physical acceptance remain open. No TSI action, program, driver, preset or hardware/audio write executes.'}}


def legacy_layer_profiles():
    x=profile(X1600,LEGACY_LAYER_REFERENCES[X1600]['url']);x.update(autoSelect=False,definition='manufacturer:denon-x1600-native-midi-layers',aliases=[X1600,'Denon DN-X1600','DN-X1600','X1600'],excludedAliases=['X1800','X1850','DN-X1700'],
        hardwareMode='Manual MIDI channel1 with hardware MIDI layers enabled. PARAM/FUNC pages1/2/3/4 control native A/B/C/D. FUNC1/2/3/4: Play/held Cue/Sync/Load. PARAM1 browses/groups; PARAM2 changes/toggles loops. Enable C/D and configure audio separately.',
        scope='Manual four-strip three-band/fader/PFL mixer, crossfader/master and explicit native four-page transport/library/loop layout with owned layer/page cleanup.',
        gaps=['Hardware layer selection, analogue/audio ownership, remaining parameter/FX/mic/booth/headphone controls, full modes/feedback/state/lifecycle/OS and physical/iPad/A10X acceptance remain open. No hardware or audio write.'])
    x['bankChanges']=[]
    for i,deck in enumerate('abcd'):
        for action,number in [('high',[2,8,13,18][i]),('mid',[3,9,14,19][i]),('low',[4,10,15,20][i]),('level',[5,11,16,21][i])]:add(x,action,0,number,'control',deck=deck)
        add(x,'cue',0,[3,7,11,15][i],deck=deck)
        for value in [0,127]:x['bankChanges'].append({'kind':'control','channel':0,'number':70+i,'onValue':value,'decks':[deck]})
        for j,action in enumerate(['play','cuePreview','sync','load']):add(x,action,0,68+8*i+j,deck=deck)
        add(x,'browse',0,80+4*i,'control','zeroForward');add(x,'openGroup',0,64+8*i)
        add(x,'loopSize',0,81+4*i,'control','zeroForward',deck);add(x,'loop',0,65+8*i,deck=deck)
    add(x,'crossfader',0,22,'control');add(x,'master',0,25,'control')
    for number,values in [(74,[0,127]),(76,[0,1,2,3])]:
        for value in values:x['bankChanges'].append({'kind':'control','channel':0,'number':number,'onValue':value,'decks':list('abcd')})

    p=profile(PCM1,PCM_URL);p.update(autoSelect=False,definition='manufacturer:synq-pcm1-factory-tsi-core',aliases=[PCM1,'SYNQ PCM-1','PCM-1','Synq PCM1'],excludedAliases=['American Audio DP2','DP2','DMC-2000','DMC-1000'],
        hardwareMode='Manual PCM-1 normal MIDI. Deck channels1/2 and library/headphone channel3 follow its own factory mapping. Native alternate positive commands stay inactive. Configure audio separately; generic USB Audio Device names do not select automatically.',
        scope='Manual normal A/B transport, held Cue/bends, inverted pitch position, three-band mixer and qualified library/headphone controls with owned Shift guards.',
        gaps=['Generic endpoint identity, complete alternate Shift/modes, unresolved crossfader/master, gain/jog/contact calibration, loops/sampler/FX, full feedback/state/lifecycle/audio/OS and physical/iPad/A10X acceptance remain open. No source action or hardware/audio write.'])
    for ch,deck in enumerate('ab'):
        add(p,'shift',ch,55);p.setdefault('bankChanges',[]).append({'channel':ch,'number':55,'onValue':127,'decks':['a','b'],'releaseShiftChannels':[]})
        for action,n in [('play',26),('cuePreview',25),('sync',56),('keylock',57),('cue',53),('load',61),('pitchBendDown',59),('pitchBendUp',60)]:
            add(p,action,ch,n,deck=deck);p['inputs'][-1]['shifted']=False
            p['inputs'].append(dict(p['inputs'][-1],shifted=True,releaseOnly=True))
        add(p,'cuePreview',ch+3,25,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for action,n in [('level',22),('high',19),('mid',20),('low',21)]:add(p,action,ch,n,'control',deck=deck)
        add(p,'tempo',ch,18,'control',deck=deck);p['inputs'][-1]['inverted']=True
    for action,n in [('monitor',3),('cueMix',2)]:add(p,action,2,n,'control')
    add(p,'browse',2,1,'control','binaryStep');add(p,'openGroup',2,1)
    return [x,p]

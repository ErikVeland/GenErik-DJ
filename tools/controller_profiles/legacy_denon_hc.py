"""Independent HC1000S and HC4500 manufacturer MIDI and lamp-trigger facts."""
from curated import add, profile

HC1000='Denon DJ HC1000S'
HC4500='Denon DJ HC4500'
BASE='https://cdn.inmusicbrands.com/denondj/legacy/'
LEGACY_HC_REFERENCES={
    HC1000:{'url':BASE+'dnhc1000s/DN-HC1000S_ownersmanual.pdf','sha256':'3ee803eafe162a7925d39e8b0d55174d2a16cb07d9ac87efb2b792df4bbbb8eb','cacheName':'hc1000s-manual.pdf','pages':[1,2],'visuallyReviewedPages':[1],
        'review':'Own manufacturer A2 manual independently qualifies raw channels0..3, note press64/release0, each A/B address and separate LED74/75 trigger commands. Native keeps five Hot Cues, bends, loops, Load, library and loop-size encoders. Native Shift Cue1/2/3/4/5 give held Cue/Play/Sync/Load/PFL; Shift Censor gives key lock. All four channel aliases share one source-owned Shift input, with cleanup on both edges even if MIDI channel changes while held. Encoders accept exact0/127 only. Hot Cue/Auto Loop lamps retain normal state while native Shift transport is active. Legacy Cue deletion/instant doubles, TAP/reverse/roll/sampler, full mode feedback/lifecycle and physical/iPad/A10X acceptance remain open. No private SDK, stored setting, setup write or audio route is used.'},
    HC4500:{'url':BASE+'dnhc4500/DN-HC4500_midicommandlist.pdf','sha256':'13d7ee9d3177fe2e1a9c55ecbc37755a0efccb555f20146b34a98ff66a7f712c','cacheName':'hc4500-midi.pdf','pages':[1,2],'visuallyReviewedPages':[1,2],
        'relatedSources':[{'url':BASE+'dnhc4500/DN-HC4500_ownersmanual.pdf','sha256':'d95a7ba9d9eba1572b5e0cf896575d65ee0e121783df47ff858b20db957be64a','cacheName':'hc4500-manual.pdf','pages':[8,9]}],
        'review':'Own manufacturer wire table independently qualifies note press64/release0, raw pitch centre8192 and reverse slider direction, strict browse0/127 and separate LED74/75 triggers. Its own manual documents MIDI channel pairs1/2,3/4,5/6, default HC4500 MIDI mode and configurable jog pulse counts. Native maps each pair to the same physical A/B players, not C/D. Source/Preset messages retire only source-owned holds and pickup. Pitch follows app range, not a claim of the hardware printed percentage. Native five Hot Cues, Play/Cue, bends, A1 loop In/B loop Out/Reloop and Parameter push Load are retained. Jog/contact and configurable pulse calibration, A2/Flip, Pitch-Key/TAP/FX, complete displays/state/lifecycle/audio and physical/iPad/A10X acceptance remain open. No HC5000 HID, private SDK, stored setting, SysEx request, hardware mode write or automatic audio assignment is inferred.'}}


def lamp(result,action,channel,identifier,deck):
    result['outputs'].append({'action':action+('A' if deck=='a' else 'B'),'targetDeck':deck,'kind':'control','channel':channel,'number':74,'offNumber':75,'onValue':identifier,'offValue':identifier,'offUsesNoteOn':False})


def legacy_hc_profiles():
    pad=profile(HC1000,LEGACY_HC_REFERENCES[HC1000]['url'])
    pad.update(role='accessory',definition='manufacturer:denon-dn-hc1000s-native-midi',
        aliases=[HC1000,'Denon DN-HC1000S','DN-HC1000S','DNHC1000S'],excludedAliases=['DN-HC4500','DN-HC5000','HC1000S clone'],
        hardwareMode='All four documented MIDI channels are accepted. Shift Cue1/2/3/4/5 control held Cue, Play, Sync, Load and PFL. Shift Censor controls key lock. Use separate app audio.',
        scope='Automatic five-Hot-Cue A/B accessory layout with native Shift transport, bends, loops, loop-size and library controls. Lamps show normal Hot Cue and loop state.',
        gaps=['Legacy Cue deletion/instant doubles, TAP/reverse/roll/sampler, remaining modes, complete Shift feedback/lifecycle, OS behaviour and physical/iPad/A10X acceptance remain open. Audio requires a separate device.'])
    for channel in range(4):
        add(pad,'shift',channel,96);pad['inputs'][-1]['shiftInput']=0
        pad.setdefault('bankChanges',[]).append({'channel':channel,'number':96,'onValue':64,'decks':['a','b'],'releaseShiftChannels':[]})
        for deck,hotcues,bends,load,loops,cut,leds,loop_led,censor,next_track,previous in [
            ('a',[23,24,25,32,33],[17,16],98,[55,57,64,29],85,[17,19,21,23,25],43,6,12,13),
            ('b',[117,118,119,120,121],[115,114],99,[123,124,125,122],90,[97,99,101,103,105],111,94,112,113)]:
            for slot,number in enumerate(hotcues):
                add(pad,f'hotcue{slot+1}',channel,number,deck=deck);pad['inputs'][-1]['shifted']=False
                add(pad,['cuePreview','play','sync','load','cue'][slot],channel,number,deck=deck);pad['inputs'][-1]['shifted']=True
                lamp(pad,f'hotcue{slot+1}',channel,leds[slot],deck)
            controls=[('pitchBendDown',bends[0]),('pitchBendUp',bends[1]),('load',load)]+list(zip(['loopIn','loopOut','reloop','loop'],loops))
            for action,number in controls:
                add(pad,action,channel,number,deck=deck);pad['inputs'][-1]['shifted']=False
                pad['inputs'].append(dict(pad['inputs'][-1],shifted=True,releaseOnly=True))
            add(pad,'keylock',channel,censor,deck=deck);pad['inputs'][-1]['shifted']=True
            add(pad,'loopSize',channel,cut,'control','zeroForward',deck);pad['inputs'][-1]['shifted']=False
            for action,number in [('browseNext',next_track),('browsePrevious',previous)]:
                add(pad,action,channel,number);pad['inputs'][-1]['shifted']=False
            lamp(pad,'loop',channel,loop_led,deck)
        for action,number,kind,encoding in [('browse',84,'control','zeroForward'),('openGroup',40,'note','absolute'),('browsePreviousGroup',48,'note','absolute'),('browseNextGroup',41,'note','absolute')]:
            add(pad,action,channel,number,kind,encoding);pad['inputs'][-1]['shifted']=False

    rack=profile(HC4500,LEGACY_HC_REFERENCES[HC4500]['url'])
    rack.update(definition='manufacturer:denon-dn-hc4500-native-midi',
        aliases=[HC4500,'Denon DN-HC4500','DN-HC4500','DNHC4500'],excludedAliases=['DN-HC5000','DN-HC1000S','HC4500 clone'],
        hardwareMode='Select PC source and HC4500 MIDI mode. All three documented MIDI channel pairs control the same physical A/B players. The pitch slider follows app range. Configure audio separately.',
        scope='Automatic A/B Play/held Cue, five Hot Cues, bends, manual loop In/Out/Reloop, track browse/load/group control and pitch position. Dedicated lamps show Play, Cue and Hot Cues.',
        gaps=['Jog/contact and configurable pulse calibration, A2/Flip, Pitch-Key/TAP/FX, complete displays/state/lifecycle, hardware/audio routing, OS behaviour and physical/iPad/A10X acceptance remain open. The app range determines pitch; printed hardware percentages are not inferred. No stored setting or mode write.'])
    for channel in range(6):
        deck='a' if channel%2==0 else 'b'
        for action,number in [('play',67),('cuePreview',66),('pitchBendDown',9),('pitchBendUp',8),('loopIn',55),('loopOut',57),('reloop',64),('load',40)]+[(f'hotcue{s+1}',n) for s,n in enumerate([23,24,25,32,33])]:add(rack,action,channel,number,deck=deck)
        add(rack,'browse',channel,84,'control','zeroForward');add(rack,'openGroup',channel,48)
        add(rack,'tempo',channel,0,'pitch','centredPitch',deck);rack['inputs'][-1]['inverted']=True
        for number,decks in [(49,[deck]),(82,['a','b'])]:rack.setdefault('bankChanges',[]).append({'channel':channel,'number':number,'onValue':64,'decks':decks})
        for action,identifier in [('play',39),('cuePreview',38)]+[(f'hotcue{s+1}',n) for s,n in enumerate([17,19,21,23,25])]:lamp(rack,action,channel,identifier,deck)
    return [pad,rack]

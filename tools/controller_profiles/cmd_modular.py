"""Independent default-channel CMD facts with explicit native control layouts."""
from curated import add, profile
PL1='Behringer CMD PL-1'
DC1='Behringer CMD DC-1'
LC1='Behringer CMD LC-1'
DV1='Behringer CMD DV-1'
PL1_REV='0b8bed36ad461359b1bfadff14627044bf80fe01'
CMD_REFERENCES={
    PL1:{'url':'https://www.parts-express.com/pedocs/tech-docs/behringer-cmd-pl-1-platter-module-midi-map--248-6846.pdf','sha256':'7312917c4731d9e99194b83f65913f79b39dfa9f893d4582a8c046115981783a','visuallyReviewedPages':[1],
        'files':[{'cacheName':'cmd-pl1-midi.pdf','sha256':'7312917c4731d9e99194b83f65913f79b39dfa9f893d4582a8c046115981783a'},{'cacheName':'pl1/behringer.cmd.pl-1.js','sha256':'a15361b63cbd801f52e33b0e809d56432abf837272710dffd8727de472d60ebf'},{'cacheName':'pl1/behringer.cmd.pl-1.midi.xml','sha256':'df47f0bff2cf00918e129a7d0bbbda49d43a1808eab4b3ff0f1a4874a1a838b7'},{'cacheName':'pl1/behringer.cmd.pl-1.custom.js','sha256':'31cc5e7b09e0860293fb7ca5dbe1220e8741fb99a560a5625019c279b9ca27b4'}],
        'relatedSources':[{'url':'https://gist.github.com/geenloop/0a8cfa5728c9f9909765d150f96779f4/'+PL1_REV,'revision':PL1_REV}],
        'review':'Own manufacturer sheet visually qualifies default channel group1..4, note addresses and button LED1 solid/0 off. Independent model-specific mapping qualifies CC31 and Note31 wheel/contact, binary-offset encoders and400-count source scratch scale. Native retains default four targets only, eight Hot Cues each and named Play/held Cue/Sync/Load/key lock. E1..8 deliberately control gain/high/mid/low/filter/loop size/library/headphones; E6/7/8 push loop/group/PFL. These are native assignments, not copied software actions. Jog counts require owned contact; free spin/scratch-toggle and pitch polarity remain inactive or open. Any positive Deck26 retires only owned contacts; its release preserves fresh contacts. HH channel groups5..16, exact physical scale/direction, tempo, remaining buttons, rings/meters, full lifecycle/OS and physical acceptance remain open. No source code, setup, channel changer, stored setting or audio command runs.'},
    DC1:{'url':'https://raw.githubusercontent.com/mpiraux/CMD-DC-1-Ableton-9-Control-Surface-Script/c2a122474cb81469352493c393e4a985b9ca9753/DC1.py','revision':'c2a122474cb81469352493c393e4a985b9ca9753','sha256':'c8da7571d54a14b9c00151a108ffe10db4b7b78af632814884292d0dd5f5473b',
        'files':[{'cacheName':'dc1/DC1.py','sha256':'c8da7571d54a14b9c00151a108ffe10db4b7b78af632814884292d0dd5f5473b'},{'cacheName':'dc1/DC1_Map.py','sha256':'b5db5c55ca11891c109b36ec0c723e6208dbaddacbada486e32a0ea1ed690d49'},{'cacheName':'dc1/CMDEncoderElement.py','sha256':'6e8dd8872115ad9f25b67ebd64afcb7a0bc80eca8517b19cf6a885e446272a5c'},{'cacheName':'dc1/FlashingButtonElement.py','sha256':'cba7c3d78b61e40ee6440d33373a3f598721f8a6cd0a02746285356ed76b962f'}],
        'review':'Own pinned port of the manufacturer Ableton mapping explicitly uses raw channel5,16 ordered pad addresses, encoder CC16..23, their note pushes and CC/Note32 library wheel. Native gives four vertical Hot Cues per A/B/C/D column, first-row level encoders, second-row filters and Load/PFL pushes. Library uses the bounded65/63 directions; eight knobs retain declared binary-offset decoding. Used pad feedback derives through the actual colour-output function: logical green2 sends1 and amber1 sends0. Unused generic/commented templates and copied CNTRL:R comments do not qualify extra controls. Framework compatibility of the old script does not run or become an app dependency. Remaining software modes, custom channels, rings/full feedback/lifecycle and physical acceptance remain open. No vendor program, script, hardware setting or audio write.'},
    LC1:{'url':'https://raw.githubusercontent.com/mpiraux/CMD-LC-1-Ableton-9-Control-Surface-Script/5363aa49d6006f80c71891d8bcb38cdfe80a14e1/LC1.py','revision':'5363aa49d6006f80c71891d8bcb38cdfe80a14e1','sha256':'ef3216a6d1e5c2ae58dbfbbdddd188ab619bf3e7b2ee6bd7939b0c06b51c5b8f',
        'files':[{'cacheName':'lc1/LC1.py','sha256':'ef3216a6d1e5c2ae58dbfbbdddd188ab619bf3e7b2ee6bd7939b0c06b51c5b8f'},{'cacheName':'lc1/LC1_Map.py','sha256':'96c55da7a34ba59e44fc9817a4a047cdb22eb1e4d672c09739084697996f4393'},{'cacheName':'lc1/CMDEncoderElement.py','sha256':'42f7472e472de367609c3bd45b7078e22f508ce0e14ae2c6b63808ba3afd181e'},{'cacheName':'lc1/FlashingButtonElement.py','sha256':'75a6bb0e4639f73b04617c27d45cf80ef5fea4adf4ca97534f67390b9899d048'}],
        'relatedSources':[{'url':'https://manualzz.com/doc/3036438/behringer-cmd-lc-1-midi-controller-midi-map','review':'Manufacturer-authored sheet transcript corroborates channel8 and clip LED1 green/127 fully off; graphical address OCR is not used.'}],
        'review':'Own pinned port explicitly uses raw channel7, five selected clip rows per four columns, encoder CC16..23 and note pushes, and four named navigation buttons. Native gives five Hot Cues per A/B/C/D column, level/filter encoders with Load/PFL pushes, and library navigation. Declared relative-binary-offset knobs preserve counts. Actual colour conversion maps logical green2 to1 and off127 to127, rather than copying logical colour constants as MIDI bytes. Only the selected used clip rows qualify; remaining clip/transport/mute/arm/solo controls, custom channels, rings/full feedback/lifecycle and physical acceptance remain open. No script, old framework, startup, stored setting or audio command runs.'}}
CMD_REFERENCES[DV1]={
    'url':'https://raw.githubusercontent.com/pavallin/CMD-DV1-Ableton/5536b5cf1aba7b9f5150e83e97129390363e072f/DV1.py','revision':'5536b5cf1aba7b9f5150e83e97129390363e072f','sha256':'a65a6d7b82dbb0d1216be94efb9eefa625e3b4779c40ef3e84122899b42832f4',
    'files':[{'cacheName':'dv1/DV1.py','sha256':'a65a6d7b82dbb0d1216be94efb9eefa625e3b4779c40ef3e84122899b42832f4'},{'cacheName':'dv1/DV1_Map.py','sha256':'cf95ff1c93b21672dea91daef2502db649c8cbb463df6d98a2c2b16118f28358'},{'cacheName':'dv1/CMDEncoderElement.py','sha256':'6e8dd8872115ad9f25b67ebd64afcb7a0bc80eca8517b19cf6a885e446272a5c'},{'cacheName':'dv1/ReadMe.txt','sha256':'63037658c68d3db933ac10316b075641d86906e2e09cde4f338ce5dbce435af9'}],
    'review':'Independent mapping explicitly identifies itself as experimental/WIP and retains unused copied DC-1 files. Only used raw channel6, three eight-encoder FX banks, eight clip notes and four Focus-navigation notes qualify. Native manual layout assigns the three qualified encoder banks to A/B/C gain/high/mid/low/filter/level/loop-size/browse, plus four Hot Cues per A/B and Focus library navigation. Actual relative-smooth-binary-offset constructors qualify the decoder; comments and unused templates do not. FX4, other Focus/Master/Double/Shift buttons, complete modes/feedback/lifecycle and physical acceptance remain open. No automatic selection, downloaded code, old framework, preset, startup, output or audio write.'}



def lamp(p,action,ch,n,deck,off=0):
    p['outputs'].append({'action':action+('A' if deck in 'ac' else 'B'),'targetDeck':deck,'kind':'note','channel':ch,'number':n,'onValue':1,'offValue':off,'offUsesNoteOn':True})


def cmd_profiles():
    p=profile(PL1,CMD_REFERENCES[PL1]['url']);p.update(definition='reviewed:cmd-pl1-default-native-core',aliases=[PL1,'CMD PL-1','CMDPL1'],excludedAliases=['CMD DC-1','CMD DV-1','CMD LC-1','CMD MM-1'],
        hardwareMode='Default PL-1 channel group1..4 maps to native A/B/C/D. Enable C/D separately. E1..8: gain/high/mid/low/filter/loop size/library/headphones. E6/7/8 push: loop/group/PFL. Wheel requires contact and uses source scale400. Configure audio separately.',
        scope='Automatic default four-target Play/held Cue/Sync/Load/key lock, eight Hot Cues, contact-gated source-scale jog, relative native mixer/library/loop controls and steady button lamps.',
        gaps=['Other channel groups, physical jog scale/direction, pitch polarity/range, free-spin/scratch-toggle, remaining buttons, rings/meters, full modes/lifecycle/OS and physical/iPad/A10X acceptance remain open. No setup, stored setting or audio write.'])
    for ch,deck in enumerate('abcd'):
        for action,n in [('play',35),('cuePreview',34),('sync',32),('load',24),('keylock',25)]+[(f'hotcue{i+1}',16+i) for i in range(8)]:
            add(p,action,ch,n,deck=deck)
            if action!='load':lamp(p,action,ch,n,deck)
        add(p,'jogTouch',ch,31,deck=deck);add(p,'jog',ch,31,'control','binaryOffset',deck);p['inputs'][-1].update(argument=400,requiresTouch=True)
        for n,action in enumerate(['gain','high','mid','low','filterKnob','loopSize','browse','monitor']):add(p,action,ch,n,'control','binaryOffset',deck if action not in ['browse','monitor'] else None)
        add(p,'loop',ch,5,deck=deck);add(p,'openGroup',ch,6);add(p,'cue',ch,7,deck=deck)
    p['bankChanges']=[{'channel':ch,'number':26,'anyPositive':True,'decks':list('abcd')} for ch in range(4)]
    results=[p]
    for name,ch,pads,off in [(DC1,5,[[48,44,40,36],[49,45,41,37],[50,46,42,38],[51,47,43,39]],0),(LC1,7,[[32,36,40,44,48],[33,37,41,45,49],[34,38,42,46,50],[35,39,43,47,51]],127)]:
        p=profile(name,CMD_REFERENCES[name]['url']);p.update(role='accessory',definition='reviewed:'+('cmd-dc1' if name==DC1 else 'cmd-lc1')+'-native-columns',aliases=[name,name.removeprefix('Behringer '),name.removeprefix('Behringer ').replace(' ','').replace('-','')],excludedAliases=[x.removeprefix('Behringer ') for x in [PL1,DC1,LC1,'Behringer CMD DV-1'] if x!=name],
            hardwareMode='Use the source-layout MIDI channel'+str(ch+1)+'. Columns control native A/B/C/D. First encoder row controls level; second controls filter. First/second push rows Load/PFL. Enable C/D and configure separate audio.',
            scope='Automatic native four-column '+str(len(pads[0]))+'-Hot-Cue accessory layout with relative level/filter, Load/PFL, library and qualified clip lamps.',
            gaps=['Remaining software/clip/transport/FX modes, custom channels, encoder rings/full state/feedback/lifecycle/OS and physical/iPad/A10X acceptance remain open. No source code, setup, preset or audio write.'])
        for i,deck in enumerate('abcd'):
            for j,n in enumerate(pads[i]):add(p,f'hotcue{j+1}',ch,n,deck=deck);lamp(p,f'hotcue{j+1}',ch,n,deck,off)
            add(p,'level',ch,16+i,'control','binaryOffset',deck);add(p,'filterKnob',ch,20+i,'control','binaryOffset',deck)
            add(p,'load',ch,16+i,deck=deck);add(p,'cue',ch,20+i,deck=deck)
        if name==DC1:add(p,'browse',ch,32,'control','binaryStep');add(p,'openGroup',ch,32)
        else:
            for action,n in [('browsePreviousGroup',58),('browseNextGroup',59),('browsePrevious',56),('browseNext',57)]:add(p,action,ch,n)
        results.append(p)
    p=profile(DV1,CMD_REFERENCES[DV1]['url']);p.update(role='accessory',autoSelect=False,definition='reviewed:cmd-dv1-experimental-public-inputs',aliases=[DV1,'CMD DV-1','CMDDV1'],excludedAliases=['CMD PL-1','CMD DC-1','CMD LC-1'],
        hardwareMode='Manual DV-1 MIDI channel7. Qualified FX1/2/3 encoder banks control native A/B/C gain/high/mid/low/filter/level/loop-size/browse. Clip rows provide four Hot Cues per A/B. Focus buttons navigate the library. Configure audio separately.',
        scope='Manual public-input accessory subset from an explicitly experimental mapping. Three relative native encoder banks, eight Hot Cues and Focus library navigation.',
        gaps=['Experimental source does not qualify automatic startup or hardware acceptance. FX4, remaining Master/Double/Shift/FX modes, full feedback/lifecycle/OS and physical/iPad/A10X acceptance remain open. No code, hardware or audio write.'])
    for i,deck in enumerate('abc'):
        numbers=list(range(20+4*i,24+4*i))+list(range(36+4*i,40+4*i))
        for action,n in zip(['gain','high','mid','low','filterKnob','level','loopSize','browse'],numbers):add(p,action,6,n,'control','binaryOffset',deck if action!='browse' else None)
    for deck,numbers in [('a',[92,93,94,95]),('b',[88,89,90,91])]:
        for i,n in enumerate(numbers):add(p,f'hotcue{i+1}',6,n,deck=deck)
    for action,n in [('browsePreviousGroup',66),('browseNextGroup',67),('browsePrevious',64),('browseNext',65)]:add(p,action,6,n)
    results.append(p);return results

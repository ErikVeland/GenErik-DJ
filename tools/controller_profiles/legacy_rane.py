"""Independent public Rane MIDI input facts and software-owned lamp boundaries."""
from curated import add, profile
TWO='Rane SIXTY TWO'
FOUR='Rane SIXTY FOUR'
TTM='Rane TTM57 MKII'
LEGACY_RANE_REFERENCES={
    TWO:{'url':'https://www.ranecommercial.com/legacy/pdf/sixtytwo_manual_dj.pdf','sha256':'f44874c5435959181ae5676c3904291a570e5f8cdfcd19fdff090c17b59e9afe','cacheName':'sixtytwo-manual.pdf','pages':[29,32,33,34,35],'visuallyReviewedPages':[35],
        'review':'Own manufacturer manual independently separates read-only mixer MIDI output, writable software controls and mixer-input configuration addresses. Native uses default MIDI Layer1, two six-control strips, four globals, five Hot Cues per deck, distinct manual/auto loop buttons and encoders and library. The manual explicitly gives different MIDI addresses for Cue versus Sample and Auto versus Manual loop controls. Software-owned Hot Cue/Loop lamps use primary-full velocity64 and off0. Hardware-only Cue/FX, input settings and mixer-control LEDs are not written. Source selector CC116/117 values1..4 reset only owned strip pickup. Other layers use non-sequential channels1/3/4/5/6 and are not silently aliased. Complete modes/feedback/audio/OS and physical acceptance remain open.'},
    FOUR:{'url':'https://cdn.inmusicbrands.com/rane/pdf/sixtyfour_manual_dj.pdf','sha256':'15f81f7976e454c22136464a4804e3a2415f234d067023bb85d8928dbf9ca992','cacheName':'sixtyfour-manual.pdf','pages':[33,34,35,36,37,38,39],'visuallyReviewedPages':[38],
        'review':'Own manufacturer table independently qualifies four fixed targets in physical C/A/B/D strip order, dedicated alternate bank addresses and default MIDI Layer1. Native keeps31 unambiguous Hot Cues, four Sync/load/loop/library sets, four six-control mixer strips and globals. Note16 is duplicated as Deck3 Trigger6 and FX joystick east, so it stays inactive, including feedback. CC122/123 overlap crossfader-assign and layer reports and stay inactive. Source selector CC116..119 values1..4 reset C/A/B/D strip pickup respectively. Only software-owned Hot Cue/Sync/Loop notes receive primary-full64/off0. No mixer setting, contour/reverse, hardware Cue/FX/LED, sibling byte, startup or audio write is inferred. Other layers, full modes/feedback/lifecycle/audio/OS and physical acceptance remain open.'},
    TTM:{'url':'https://cdn.inmusicbrands.com/rane/pdf/ttm57mk2_manual.pdf','sha256':'4518a534c438a039dd858ffdf3251b656480cabba7b3dbd540164cb2df9d8078','cacheName':'ttm57mk2-manual.pdf','pages':[22,23,24,25,26,27,28],'visuallyReviewedPages':[27],
        'review':'Own manufacturer table independently qualifies deck mixer channels1/2, loop channels5/6, general channel15 and library/crossfader channel16. Encoders explicitly use65/63 single steps. Native has two six-control strips, master/headphone/cue mix/crossfader, loop size/toggle and library browse/load/group. USB Port Active channel15 CC32 values1/4/5 reset only owned pickup. The same pad addresses represent different Cues/Samples functions, with pad mode reported by channel15 CC58; these pads and their LEDs remain inactive until the mode contract is implemented. No default pad mode, original TTM57 compatibility, driver, setup, source action, mixer preference, firmware or audio route is inferred. Full modes/feedback/lifecycle/audio/OS and physical acceptance remain open.'}}


def software_lamp(p,action,number,deck):
    suffix='A' if deck in 'ac' else 'B'
    p['outputs'].append({'action':action+suffix,'targetDeck':deck,'kind':'note','channel':0,'number':number,'onValue':64,'offValue':0,'offUsesNoteOn':True})


def legacy_rane_profiles():
    results=[]
    for name in [TWO,FOUR]:
        four=name==FOUR;p=profile(name,LEGACY_RANE_REFERENCES[name]['url'])
        p.update(autoSelect=False,definition='manufacturer:rane-'+('sixty-four' if four else 'sixty-two')+'-layer1',
            aliases=[name,'Rane Sixty-Four' if four else 'Rane Sixty-Two','Sixty-Four' if four else 'Sixty-Two'],excludedAliases=['Rane Seventy','Rane Seventy-Two','Rane Seventy-Two MKII','Rane TTM57mkII'],
            hardwareMode='Manual default MIDI Layer1. Select the connected USB port for each hardware source group and configure separate app audio. '+('Physical mixer order is C/A/B/D; enable C/D in the app separately.' if four else 'Other MIDI layers use non-sequential channels and remain outside this subset.'),
            scope='Manual '+('four' if four else 'two')+'-deck three-band mixer, gain/filter, Hot Cues, loops and library with owned source pickup cleanup. Software-owned lamps only.',
            gaps=['Other MIDI layers, complete pad/Shift/FX/sampler modes, hardware Cue/audio ownership, full state/feedback/lifecycle/OS and physical/iPad/A10X acceptance remain open. No mixer setting or automatic audio write.'])
        decks='abcd' if four else 'ab'
        for deck in decks:
            i=decks.index(deck)
            strip={'a':[90,102,78,72,66,84],'b':[91,103,79,73,67,85],'c':[89,101,77,71,65,83],'d':[92,104,80,74,68,86]}[deck] if four else [[89,101,77,71,65,83],[90,102,78,72,66,84]][i]
            for action,n in zip(['gain','high','mid','low','filterKnob','level'],strip):add(p,action,0,n,'control',deck=deck)
            pads=({'a':[104,105,98,99,100,32,38,48],'b':[78,73,74,75,76,53,84,86],'c':[18,23,22,21,20,None,33,39],'d':[101,102,103,106,107,54,85,87]}[deck] if four else [[18,23,22,21,20],[78,73,74,75,76]][i])
            for j,n in enumerate(pads):
                if n is not None:add(p,f'hotcue{j+1}',0,n,deck=deck);software_lamp(p,f'hotcue{j+1}',n,deck)
            if four:
                sync,load,browse,group,loop,size={'a':(121,123,10,125,28,44),'b':(79,55,18,52,113,19),'c':(19,44,16,43,109,17),'d':(122,124,11,126,63,45)}[deck]
                add(p,'sync',0,sync,deck=deck);software_lamp(p,'sync',sync,deck)
                add(p,'loop',0,loop,deck=deck);software_lamp(p,'loop',loop,deck)
                add(p,'loopSize',0,size,'control','binaryOffset',deck)
            else:
                load,browse,group=[(44,16,43),(55,18,52)][i]
                for action,n in zip(['loopIn','loop','loopOut'],[[28,29,30],[63,57,61]][i]):add(p,action,0,n,deck=deck)
                software_lamp(p,'loop',[29,57][i],deck)
                add(p,'loop',0,[109,113][i],deck=deck);software_lamp(p,'loop',[109,113][i],deck)
                for n in [[17,44],[19,45]][i]:add(p,'loopSize',0,n,'control','binaryOffset',deck)
            add(p,'load',0,load,deck=deck);add(p,'browse',0,browse,'control','binaryOffset');add(p,'openGroup',0,group)
        for action,n in [('crossfader',0),('master',93),('monitor',99),('cueMix',105)]:add(p,action,0,n,'control')
        p['bankChanges']=[]
        for deck,n in ([('c',116),('a',117),('b',118),('d',119)] if four else [('a',116),('b',117)]):
            for value in [1,2,3,4]:p['bankChanges'].append({'kind':'control','channel':0,'number':n,'onValue':value,'decks':[deck]})
        results.append(p)

    p=profile(TTM,LEGACY_RANE_REFERENCES[TTM]['url']);p.update(autoSelect=False,definition='manufacturer:rane-ttm57mkii-independent-midi',aliases=[TTM,'Rane TTM57mkII','TTM57mkII','TTM57 MK2'],excludedAliases=['TTM57','TTM57SL','Rane Sixty-Two','Rane Seventy'],
        hardwareMode='Manual TTM57mkII input. Keep the published deck1/2, loop5/6, general15 and library16 MIDI channels. Choose the connected USB source for each deck and configure app audio separately. Shared Cues/Samples pads remain inactive.',
        scope='Manual two-deck gain/three-band/filter/fader mixer, master/headphones/cue mix/crossfader, loop size/toggle and library controls.',
        gaps=['Shared Cues/Samples pad state and feedback, Shift/FX/joystick modes, USB audio/hardware ownership, full lifecycle/OS and physical/iPad/A10X acceptance remain open. No mixer preference, driver or hardware/audio write.'])
    for i,deck in enumerate('ab'):
        for action,n in [('gain',22),('high',23),('mid',24),('low',25),('filterKnob',26),('level',28)]:add(p,action,i,n,'control',deck=deck)
        add(p,'loopSize',i+4,52,'control','binaryStep',deck);add(p,'loop',i+4,50,deck=deck);add(p,'load',15,i+2,deck=deck)
    for action,ch,n in [('master',14,35),('monitor',14,47),('cueMix',14,39),('crossfader',15,8)]:add(p,action,ch,n,'control')
    add(p,'browse',15,0,'control','binaryStep');add(p,'openGroup',15,7)
    p['bankChanges']=[{'kind':'control','channel':14,'number':32,'onValue':v,'decks':['a','b']} for v in [1,4,5]]
    results.append(p);return results

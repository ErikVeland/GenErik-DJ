"""Independent APC40 generation wire contracts with native column-pair functions."""
from curated import add, profile

APC40_REFERENCES={
    'Akai APC40 MKII':{'url':'https://cdn.inmusicbrands.com/akai/attachments/apc40II/APC40Mk2_Communications_Protocol_v1.2.pdf','sha256':'3af85d0b338a68581360633f38db9267119a34d3e9f7ffaf68be24658ce932b1','version':'1.2','pages':[12,13,30,31,32,33,34,35,36,37],
        'visuallyReviewedPages':[12,13,32,34,35,36,37],
        'review':'Independent MKII protocol: product41, Mode1 identifier65,40 distinct Clip Launch notes0..39 and per-track notes48..52 on0..7. Global note functions ignore MIDI channel. Native retains strict track channels and any-channel global input, with Shift cleanup on all16 channels. An explicit paired-unbanked contract permits these global inputs only with bounded mode setup/exit and one Shift selector covering every channel. Selected input/mode/LED header tables were visually checked; remaining sequential grid/global/ring rows were checked as extracted text. The inbound table repeats ring-type IDs24..31/56..63 and lists Cue Level as both absolute and relative. Native uses only unambiguous position families16..23/48..55, the explicit relative Cue Level assignment47 and relative Tempo13. Duplicated ring-type input rows remain inactive. Full geometry/mode/state/feedback/calibration and physical/iPad/A10X acceptance remain open.'},
    'Akai APC40':{'url':'https://cdn.inmusicbrands.com/akai/apc40/APC40_Communications_Protocol_rev_1.pdf_1db97c1fdba23bacf47df0f9bf64e913.pdf','sha256':'b8c62fb7e69ed2c8e926a72ff48b4c823eca586ff2f798d1c81d2bd98a80d698','version':'Rev1,1May2009','pages':[7,8,9,10,11,16,17,18,19,20],
        'visuallyReviewedPages':[7,8,9,16,18,19,20],
        'review':'Independent original protocol: product115, Mode1 identifier65, Clip Launch rows53..57 repeated on track channels0..7 and explicit original1/3/5 pad colours. Selected mode/input/LED tables were visually checked; remaining global/ring rows were checked as extracted text. Global note functions ignore MIDI channel. An explicit paired-unbanked contract requires bounded mode setup/exit and all16 Shift cleanup channels. Relative Cue Level47 has its own signed table. No MKII product/grid/RGB or Tempo13 input is inherited. Native app column-pair functions follow documented control order; physical orientation, complete modes/state/feedback/calibration and physical/iPad/A10X acceptance remain open.'},
}


def _input(result,action,channel,number,deck=None,kind='note',encoding='absolute',global_control=False,colour=None):
    add(result,action,channel,number,kind,encoding,deck,feedback=colour is not None)
    if global_control:result['inputs'][-1]['anyChannel']=True
    if kind=='note' and action!='shift':result['inputs'][-1]['shifted']=False
    if colour is not None:result['outputs'][-1].update(onValue=colour,offUsesNoteOn=False)


def apc40_profiles():
    results=[]
    for name,ref in APC40_REFERENCES.items():
        mk2=name.endswith('MKII')
        product=41 if mk2 else 115
        result=profile(name,ref['url'])
        result.update(role='accessory',unbankedGlobalInputs=True,definition='manufacturer:'+name.lower().replace(' ','-')+'-native-mode1',
                      aliases=[name,'APC40 MKII','APC40 MK2','APC40mkII'] if mk2 else [name,'APC40','APC 40'],
                      excludedAliases=['APC40','APC mini','APC20','APC64'] if mk2 else ['APC40 MKII','APC40 MK2','APC mini','APC20','APC64'],
                      hardwareMode='Native selects the documented Mode1 for momentary buttons and unbanked device knobs. Close other controlling software. Adjacent track pairs1/2,3/4,5/6,7/8 target A/B/C/D. C/D require opt-in. Shutdown restores Generic Mode0.',
                      scope='Automatic native four-pair grid/strip/knob accessory. Each pair has eight Hot Cues, Play/held Cue, Sync/Load, PFL/key lock, manual loops, half/double, Reloop/toggle, level/gain. Sixteen knobs control high/mid/low/filter across A..D with value/ring feedback. Selected library/global controls and68 feedback bindings.',
                      gaps=['This is an app layout following published control order. Physical pad orientation, full source modes, global transport/foot controls, source-specific Shift/FX, remaining LEDs/ring styles/state, startup analogue response, complete feedback/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. Generic exit does not restore an arbitrary previous mode or state. No DAW script, private authentication, persistent preset or audio route is used.'])
        for side,deck in enumerate('abcd'):
            left=2*side
            for column,action in [(left,'play'),(left+1,'cuePreview')]:
                channel,number=(0,32+column) if mk2 else (column,57)
                colour=(19 if action=='play' else 5) if mk2 else (1 if action=='play' else 3)
                _input(result,action,channel,number,deck,global_control=mk2,colour=colour)
            for slot in range(8):
                row,column=slot//2,left+slot%2
                channel,number=(0,8*row+column) if mk2 else (column,53+row)
                _input(result,f'hotcue{slot+1}',channel,number,deck,global_control=mk2,colour=45 if mk2 else 5)
            for column,actions in [(left,[('sync',48,1),('cue',49,1),('loopIn',50,None),('loopDown',51,None),('reloop',52,None)]),
                                   (left+1,[('load',48,None),('keylock',49,1),('loopOut',50,None),('loopUp',51,None),('loop',52,None)])]:
                for action,number,colour in actions:_input(result,action,column,number,deck,colour=colour)
            _input(result,'level',left,7,deck,kind='control')
            _input(result,'gain',left+1,7,deck,kind='control')
            knob_base=16+4*side if side<2 else 48+4*(side-2)
            for offset,action in enumerate(['high','mid','low','filterKnob']):
                _input(result,action,0,knob_base+offset,deck,kind='control',global_control=True)
                suffix='A' if deck in 'ac' else 'B'
                result['outputs'].append({'action':('filter' if action=='filterKnob' else action)+suffix,'kind':'control','channel':0,'number':knob_base+offset,
                                          'onValue':127,'offValue':0,'offUsesNoteOn':True,'targetDeck':deck})
        for action,number in [('browsePreviousGroup',82),('browseNextGroup',83),('openGroup',84),('browsePrevious',85),('browseNext',86)]:
            _input(result,action,0,number,global_control=True)
        for action,number in [('master',14),('crossfader',15)]:_input(result,action,0,number,kind='control',global_control=True)
        _input(result,'monitor',0,47,kind='control',encoding='twosComplement',global_control=True)
        if mk2:_input(result,'browse',0,13,kind='control',encoding='twosComplement',global_control=True)
        _input(result,'shift',0,98,global_control=True)
        result['bankChanges']=[{'channel':channel,'number':98,'onValue':127,'decks':list('abcd')} for channel in range(16)]
        def mode(value):return [240,71,127,product,96,0,4,value,0,1,0,247]
        result['startup']=[mode(65)]
        result['shutdown']=[[0x80+r['channel'],r['number'],0] for r in result['outputs'] if r['kind']=='note']+[mode(64)]
        result['startupAbort']=[mode(64)]
        results.append(result)
    return results

"""Independent current Launch Control DAW wire contracts with native app functions."""
from curated import add, profile

LAUNCH_CONTROL_DAW_REFERENCES={'Novation Launch Control 3': {'url': 'https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_3_programmer_s_reference_guide.pdf', 'sha256': 'a8eb5814ebb5214332aa378469db903986b327a9672483debaf9ccc3eca978e9', 'version': '1.1', 'pages': [5, 6, 8, 9, 10, 11, 12, 16, 17], 'visuallyReviewedPages': [9], 'review': 'Independent manufacturer DAW-port contract and product identifier. Surface indices on page9 were visually reviewed. Mode, channel, colour, absolute-encoder and feature-control contracts were checked as extracted text. Native app functions use four adjacent column pairs. Temporary DAW mode and absolute encoder setup do not edit custom templates or non-volatile settings. The decoder normalises exact0/127 momentary button CCs to logical notes. Source-local mode changes retire holds and pickup. Complete modes/screen/state/feedback/lifecycle, OS port-name variants and physical/iPad/A10X acceptance remain open.'}, 'Novation LaunchControl XL3': {'url': 'https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_xl_3_programmer_s_reference_guide-pdf_en.pdf', 'sha256': '4ac520cae51280b6c21fee35cb6b30ef4f50d80d5e1161d921ffe3c36c2736ad', 'version': '1.0', 'pages': [5, 6, 8, 9, 10, 11, 12, 16, 17], 'visuallyReviewedPages': [9], 'review': 'Independent manufacturer DAW-port contract and product identifier. Surface indices on page9 were visually reviewed. Mode, channel, colour, absolute-encoder and feature-control contracts were checked as extracted text. Native app functions use four adjacent column pairs. Temporary DAW mode and absolute encoder setup do not edit custom templates or non-volatile settings. The decoder normalises exact0/127 momentary button CCs to logical notes. Source-local mode changes retire holds and pickup. Complete modes/screen/state/feedback/lifecycle, OS port-name variants and physical/iPad/A10X acceptance remain open.'}}


def launch_control_daw_profiles():
    results=[]
    for name,ref in LAUNCH_CONTROL_DAW_REFERENCES.items():
        xl=name.endswith('XL3')
        label='Launch Control XL 3' if xl else 'Launch Control 3'
        product=21 if xl else 22
        result=profile(name,ref['url'])
        result.update(role='accessory',inputProtocol='launchControlDAW',
                      aliases=[name,label,label.replace('Control ','Control'),label.replace(' ','')],
                      excludedAliases=['Launch Control','Launch Control XL','Launch Control XL MK2']+(['Launch Control 3'] if xl else ['Launch Control XL 3','LaunchControl XL3']),
                      portAliases=[label+' DAW',label+' DAW In',label+' DAW Out','DAW In','DAW Out','DAW'],
                      definition='manufacturer:'+('launch-control-xl3' if xl else 'launch-control3')+'-native-daw',
                      hardwareMode='Native uses the paired DAW USB interface, enters DAW Control and sets absolute encoder output. Close other controlling software. Adjacent column pairs target A/B/C/D. C/D require opt-in. Custom modes suspend native input. Returning to DAW Mixer or Control resumes it. Shutdown exits DAW mode.',
                      scope='Automatic four-deck native mixer and held-Cue/Play accessory. Selected button colour and encoder position feedback. XL3 adds paired level/gain faders, filter controls, Sync/Load and library navigation.',
                      gaps=['This is an app layout following each published surface diagram. Complete modes, Shift functions, feature controls, screen/labels, remaining LEDs, saved-state restoration and physical/iPad/A10X acceptance remain open. Only explicitly matched DAW ports are enabled. No custom template, DAW script, private SDK, non-volatile setting, DIN route or audio route is written. Mode exit is best effort, not restoration of arbitrary previous state.'])
        for side,deck in enumerate('abcd'):
            column=2*side
            for row,actions in enumerate([['high','mid'],['low','filterKnob' if xl else 'gain']]+([['gain','level']] if xl else [])):
                for offset,action in enumerate(actions):
                    number=13+8*row+column+offset
                    add(result,action,15,number,'control',deck=deck)
                    result['outputs'].append({'action':('filter' if action=='filterKnob' else action)+('A' if deck in 'ac' else 'B'),
                                              'kind':'control','channel':15,'number':number,'onValue':127,'offValue':0,'offUsesNoteOn':True,'targetDeck':deck})
            if xl:
                for offset,action in enumerate(['level','gain']):add(result,action,15,5+column+offset,'control',deck=deck)
            for row,actions in enumerate([['play','cuePreview']]+([['sync','load']] if xl else [])):
                for offset,action in enumerate(actions):
                    add(result,action,0,37+8*row+column+offset,'note',deck=deck,feedback=action!='load')
                    result['inputs'][-1]['shifted']=False
                    if action!='load':result['outputs'][-1].update(kind='control',onValue={'play':19,'cuePreview':5,'sync':45}[action])
        if xl:
            for action,number in [('browsePreviousGroup',106),('browseNextGroup',107),('browsePrevious',103),('browseNext',102),('openGroup',104)]:
                add(result,action,0,number,'note')
                result['inputs'][-1]['shifted']=False
        add(result,'shift',6,63,'control')
        result['bankChanges']=[{'kind':'control','channel':6,'number':63,'onValue':127,'decks':list('abcd')}]
        def mode(value):return [240,0,32,41,2,product,2,value,247]
        clear=[[176,n,0] for n in range(37,53 if xl else 45)]
        result['startup']=[mode(127),[182,30,2]]+[[182,n,0] for n in [69,72]+([73] if xl else [])]+[[182,71,0]]+([[182,70,0]] if xl else [])+clear
        result['shutdown']=clear+[mode(0)]
        result['startupAbort']=[mode(0)]
        results.append(result)
    return results

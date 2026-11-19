"""Independent model-specific public MIDI facts with conservative manual app layouts."""
from curated import add, profile
from promixer_public import INSTALLER, INSTALLER_SHA

REMAINING_PROMIXER_REFERENCES={
    'Akai Pro AMX':{'url':INSTALLER,'sha256':INSTALLER_SHA,'member':'Devices/AKAI AMX.xml','memberSHA256':'a2702abeef7052284715d8bbbccc1dd5f788211c25317d1c1e8b469d08b21116',
        'relatedSources':[{'url':'https://www.akaipro.com/downloads-and-support/downloads/?legacy=true'}],
        'review':'Own public factory XML qualifies a manual32-binding normal-layer mixer/transport subset: five buttons per deck, five seven-bit strip controls per deck, crossfader and global Shift. Ten release-only shifted guards preserve held releases and button rearming. Shift0 retires only source-owned holds and resets normal control pickup. Native omits virtual pitch numbers160/161 rather than wrapping them. Browser direction/encoder values, touch-sensitive kill/FX functions, higher-resolution pairs, full Shift/modes/feedback/lifecycle/audio and physical/iPad/A10X acceptance remain open. No AFX/sibling byte, source action, hardware setting or audio route is inherited.'},
    'ION ICUE':{'url':INSTALLER,'sha256':INSTALLER_SHA,'member':'Devices/ION ICUE.xml','memberSHA256':'78faba4bd106eed6e06964db0f686ff6f4ad7f5e582e27141c65ae647b2d9572',
        'relatedSources':[{'url':'https://djpromixerblog.com/2015/03/21/ion-icue/'}],
        'review':'Own public factory XML qualifies30 manual inputs: ten transport/loop/PFL buttons and five seven-bit mixer controls per deck on wire channel0. Publisher setup explicitly identifies iCUE as MIDI-only with separate soundcard selection. Native does not infer Total Control compatibility. Crossfader is marked CtrlI without an independently qualified direction contract, and HeadMaster appears at both15/23, so those globals stay inactive. Separate Pause, sampler/FX, jog/tempo/browser calibration, full state/feedback/lifecycle and physical/iPad/A10X acceptance remain open. No source action, setting or audio route is executed.'},
    'Reloop DIGITAL JOCKEY':{'url':INSTALLER,'sha256':INSTALLER_SHA,'member':'Devices/RELOOP DIGITAL JOCKEY.xml','memberSHA256':'9425ea7d5597dad5741a893f369340ae99228ac22e4684a598a0fddd847092cf',
        'manualURL':'https://www.reloop.com/media/catalog/product/pdf/2/2/1/221833_Reloop_IM.pdf','manualSHA256':'666d4b5c1b0f124d02595e3e164b6b1f704ad963f27aa294288b515f601ff516','pages':[41,42],'visuallyReviewedPages':[41,42],
        'relatedSources':[{'url':'https://www.reloop.com/reloop-digital-jockey'}],
        'review':'Own original-model public factory XML qualifies both A/B signal families on channel0. Native deliberately gives normal and plus30 hardware families the same transport/mixer app functions. Forty-eight release guards rearm both families and release the same physical Cue/bend owner without another command. Native118 bindings cover twelve buttons and five mixer controls per side across both families, crossfader and group-open. The original manufacturer manual independently confirms held Shift doubles MIDI functions and explains the physical transport/mixer. Native Play toggles and Loop/Reloop use app behaviour; original Attack stutter/independent Pause are not emulated. No Digital Jockey2 address or calibration is inherited. Browser delta encoding, jog/contact/tempo, software virtual pitch, kill/sampler/FX, remaining modes/state/feedback/lifecycle/audio and physical/iPad/A10X acceptance remain open.'}}


def remaining_promixer_profiles():
    results=[]
    for name,ref in REMAINING_PROMIXER_REFERENCES.items():
        amx=name=='Akai Pro AMX';ion=name=='ION ICUE';rdj=not amx and not ion
        result=profile(name,ref['url'])
        result.update(autoSelect=False,definition='reviewed:'+name.lower().replace(' ','-')+'-public-native-subset',
            aliases=[name,'Akai AMX','AMX'] if amx else [name,'ION iCUE','iCUE'] if ion else [name,'Digital Jockey','Reloop Digital Jockey original'],
            excludedAliases=['AFX','Akai AFX','AMX clone'] if amx else ['Numark Total Control','ION Discover DJ','iCUE clone'] if ion else ['Digital Jockey2','Digital Jockey2 IE','Digital Jockey2 CE','Digital Jockey2 ME','Digital Jockey clone'],
            hardwareMode='Manual native A/B subset on MIDI channel1. Use normal mode and separate app audio. '+('Shift retires held controls and resets pickup.' if amx else 'Both original hardware signal families keep the same native A/B transport and mixer functions.' if rdj else 'Use app crossfader, headphone globals and library navigation.'),
            scope='Manual normal-layer Play/held Cue, Sync, PFL/load, mixer/crossfader and owned Shift cleanup.' if amx else 'Manual30-input transport, held Cue/bends, key lock/PFL, manual loops/load and mixer subset. Ambiguous globals remain inactive.' if ion else 'Manual118-binding original-model transport/loop/PFL/load and mixer subset across both hardware signal families, with cross-family release guards. Native Play toggles; native Loop/Reloop use app behaviour.',
            gaps=['Full hardware modes, jog/pitch and encoder calibration, feedback, audio setup and physical acceptance remain open. '+('Touch/FX and library controls are inactive.' if amx else 'Crossfader, headphone globals, browser rotation, sampler/FX and separate Pause are inactive.' if ion else 'Original Attack stutter and separate Pause, browser rotation, kills and sampler/FX are inactive.')])
        if amx:
            result['role']='accessory';add(result,'shift',0,0)
            result['bankChanges']=[{'channel':0,'number':0,'onValue':127,'decks':['a','b']}]
            for index,deck in enumerate('ab'):
                for action,number in [('play',10),('cuePreview',8),('sync',6),('cue',12),('load',4)]:
                    add(result,action,0,number+index,deck=deck);result['inputs'][-1]['shifted']=False
                    result['inputs'].append(dict(result['inputs'][-1],shifted=True,releaseOnly=True))
                for action,number in [('level',7+4*index),('gain',60+index),('high',10+4*index),('mid',9+4*index),('low',8+4*index)]:
                    add(result,action,0,number,'control',deck=deck);result['inputs'][-1]['shifted']=False
            add(result,'crossfader',0,1,'control');result['inputs'][-1]['shifted']=False
        elif ion:
            for deck,buttons,numbers in [
                ('a',[('play',67),('cuePreview',51),('sync',64),('keylock',56),('cue',48),('load',75),('pitchBendDown',65),('pitchBendUp',66),('loopIn',73),('loopOut',74)],[8,13,16,18,20]),
                ('b',[('play',76),('cuePreview',60),('sync',71),('keylock',63),('cue',55),('load',52),('pitchBendDown',69),('pitchBendUp',70),('loopIn',77),('loopOut',78)],[9,14,17,19,21])]:
                for action,number in buttons:add(result,action,0,number,deck=deck)
                for action,number in zip(['level','gain','high','mid','low'],numbers):add(result,action,0,number,'control',deck=deck)
        else:
            buttons=[('play',25),('cuePreview',23),('sync',1),('keylock',2),('cue',5),('load',19),('pitchBendDown',3),('pitchBendUp',4),('loopIn',15),('loopOut',16),('loop',17),('reloop',18)]
            for deck,base in [('a',0),('b',60)]:
                for action,number in buttons:
                    for family in [0,30]:
                        add(result,action,0,base+family+number,deck=deck)
                        result['inputs'].append(dict(result['inputs'][-1],releaseOnly=True))
                for family in [0,30]:
                    for action,number in [('level',6),('gain',2),('high',3),('mid',4),('low',5)]:add(result,action,0,base+family+number,'control',deck=deck)
            add(result,'crossfader',0,18,'control');add(result,'openGroup',0,60)
        results.append(result)
    return results

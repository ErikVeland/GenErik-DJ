"""Original QUARK manufacturer facts, separate from QUARK SC."""
from curated import add, profile

QUARK_SOURCE='https://device.report/m/9d92b3513df25546696fa6025330c3e39fcac4c7165d91b0137a53259af71fa6.pdf'
QUARK_REFERENCES={'Akiyama QUARC':{
    'url':QUARK_SOURCE,'sha256':'39abfa44a2409b983d76457a9706f2f0adebd87f9d52eddab8e8533d8feda10a',
    'files':[{'cachePath':'TestBuilds/r451/upstream/quark-midi-public-text.txt','sha256':'39abfa44a2409b983d76457a9706f2f0adebd87f9d52eddab8e8533d8feda10a'}],
    'relatedSources':[{'url':'https://virtualdj.com/products/hardware.html?model=QUARK'}],
    'review':'Own original QUARK English manufacturer manual pp14..18 supplies separate NOTE/CC types, raw deck channels0/1/2/3 for A/B/C/D, global4, explicit64-offset relative encoders and127/0 switches/lamps. The pinned SHA identifies the public numeric-table text excerpt, not original PDF bytes. Direct PDF download and screenshots were unavailable; legible public table rows were checked against the own worked example Play34hex=52. The catalogue spelling QUARC comes from the VirtualDJ entry whose model identifier is QUARK. Native164 automatic inputs use normal Play52/Cue53/Sync54/PFL60/Load59, manual loops47/48/49, bends50/51 and normal AutoLoop44/current-loop toggle, with explicit shifted release aliases plus64. Six normal Hot Cues23/26/29/32/35/38 use shifted clear wires only as release guards. AutoLoop/Roll pad wires are distinct and remain inactive. Gain9/high10/mid11/low12/level59 are7bit CC per deck. LoopSizeCC44 and global browseCC2 use binary offset64. Native assigns Track List push2 to group entry. Global CC1 is master and CC4 crossfader. Forty-four optional normal static lamps include six yellow Hot Cues per deck and five transport/loop/PFL lamps; Loop In/Out/Reloop lamps and green/shifted/mode/FX/sample/meter outputs stay inactive. Deck selector7 retires only its physical A/C or B/D pair, and mode selectors41/42/43 retire their own deck. Jog/contact calibration, tempo polarity/range, full shifted continuous pickup/alternate functions, remaining pad/FX/sample/modes, full feedback/lifecycle/recovery, USB/OS/power/audio and physical/iPad/A10X acceptance remain open. Own power specification is USB5V500mA or DC6V1.75A; iPad power is not qualified. No setup, identity query, preset, firmware, driver or audio-route packet runs. QUARK SC bytes are not inherited.'}}


def quark_profiles():
    """Return the original four-target core with explicit shifted release guards."""
    p=profile('Akiyama QUARC',QUARK_SOURCE)
    p.update(definition='reviewed:akiyama-quark-original',
        aliases=['Akiyama QUARC','QUARC','Akiyama QUARK','QUARK'],
        excludedAliases=['QUARK SC','Akiyama QUARK SC','Quark SC clone'],
        hardwareMode='Original QUARK factory MIDI channels1..5. C/D require app opt-in. Normal Hot Cue mode uses six distinct pads. Shifted clears, alternate loop/roll pads, jog and tempo remain inactive. QUARK SC is a separate model. Power/audio and complete modes need separate qualification.',
        scope='Automatic164-input original QUARK core: transport/held Cue/bends, manual loops/size, six Hot Cues per deck, mixer/PFL/Load, browse/group entry, master/crossfader. Forty-four optional normal lamps. Full modes/lifecycle/audio and physical acceptance remain open.',
        bankChanges=[{'channel':ch,'number':7,'anyPositive':True,'decks':list('ac' if ch%2==0 else 'bd')} for ch in range(4)]+[{'channel':ch,'number':n,'anyPositive':True,'decks':[deck]} for ch,deck in enumerate('abcd') for n in [41,42,43]],
        gaps=[QUARK_REFERENCES['Akiyama QUARC']['review']])
    for ch,deck in enumerate('abcd'):
        for action,n in [('play',52),('cuePreview',53),('sync',54),('cue',60),('load',59),('loopIn',47),('loopOut',48),('reloop',49),('pitchBendDown',50),('pitchBendUp',51),('loop',44)]:
            add(p,action,ch,n,deck=deck,feedback=action in ['play','cuePreview','sync','cue','loop'])
            add(p,action,ch,n+64,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for slot,n in enumerate([23,26,29,32,35,38]):
            add(p,f'hotcue{slot+1}',ch,n,deck=deck,feedback=True)
            add(p,f'hotcue{slot+1}',ch,n+64,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for action,n in [('gain',9),('high',10),('mid',11),('low',12),('level',59)]:add(p,action,ch,n,'control',deck=deck)
        add(p,'loopSize',ch,44,'control','binaryOffset',deck)
    add(p,'master',4,1,'control');add(p,'crossfader',4,4,'control')
    add(p,'browse',4,2,'control','binaryOffset');add(p,'openGroup',4,2)
    return [p]

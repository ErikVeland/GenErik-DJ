"""DJinn own-manual channels and controls with separate mixer ownership."""
from copy import deepcopy
from curated import add, profile

DJINN='Audiophony DJINN'
DJINN_MODE3=DJINN+' (MIDI mode 3)'
DJINN_SOURCE='https://www.audiophony.com/downloads/DJinn_v3-EN.pdf'
DJINN_REVIEW='Own manufacturer v3 English manual pp12/15..19/21. Numeric tables visually reviewed. Factory MIDI channels1-2-3 mean raw0 Deck A, raw1 mixer and raw2 Deck B. Default TAP is Hold. All three MIDI/audio modes expose player controls; Mode2 excludes mixer MIDI and Mode1 excludes crossfader/master MIDI. The automatic64-input core therefore excludes the mixer. The manual90-input Mode3 variant adds only qualified software-mixer controls and requires separate audio. Native normal Play32/Cue31/Keylock29/In2/Out3/Reloop4/Bends34/35/Load1 and four Hot Cues8..11 keep explicit shifted plus63 release-only guards. CuePlay30 is not held Cue and stays inactive. Folder push5 opens a native group. Track push1 loads that deck. Per-deck Track CC22/38 and Folder CC23/39, plus63 alternatives, use explicitly defined offset64 relative messages; both wire families deliberately step native tracks/groups. TAP33 both edges retire only the source-owned deck holds. No global Shift latch is invented. Fourteen optional normal Play/Cue/Keylock/red Hot Cue lamps use127/0. Mode3 adds gain17/33, high18/34, mid19/35, low20/36, level16/32 on their own raw0/2 channels, and each explicit shifted plus63 CC family. Global raw1 master49/crossfader48/headphone level51 and their plus63 families retain the same native actions. Cue Pan CC52 blends hardware channels1/2, not Cue/Master, so it is not native cueMix. No PFL selector is invented. Jog encodings are published but physical calibration/complete cue/vinyl/classic modes remain unqualified; no standalone touch hold is added without motion. Pitch polarity/range, source/menu/channel/preset discovery, sample/save/clear/loop-pad/FX/kill/centres/mic/booth/relay/meter/fader-start/curve controls, full feedback/screens/lifecycle/recovery, USB/Link/OS/audio/DVS routing and physical/iPad/A10X acceptance remain open. SGL/CTN and BPM are not assigned a native Sync toggle. Mode3 is controller-only and disables internal USB/Input audio use. No setup, mode query/change, preset, driver, firmware or audio-route packet runs. Other Audiophony/Voxoa/OEM protocols are not inherited.'
DJINN_REFERENCES={name:{'url':DJINN_SOURCE,'sha256':'dc003a9729ca46458f8d9c521c6bf721a81ddede1e5d0f7843d6ce2401bf846a','files':[{'cachePath':'TestBuilds/r459/upstream/djinn-manual.pdf','sha256':'dc003a9729ca46458f8d9c521c6bf721a81ddede1e5d0f7843d6ce2401bf846a'}],'review':DJINN_REVIEW} for name in [DJINN,DJINN_MODE3]}


def djinn_profiles():
    """Return common players plus a manual Mode3 extension for this same hardware."""
    p=profile(DJINN,DJINN_SOURCE)
    p.update(definition='reviewed:djinn-common-player-core',aliases=[DJINN,'DJINN'],
        excludedAliases=['DJAZZ','DJAM','S70','M70','MIDI mode 3'],
        hardwareMode='Hardware MIDI mode with factory channels1-2-3 (A-mixer-B) and Hold TAP. The common player subset works in all three MIDI/audio modes. Mixer/automatic audio ownership remains unqualified. Select the separate manual Mode3 layout only after hardware configuration.',
        scope='Automatic64-input two-deck player core: Play, held Cue/bends, Keylock, four Hot Cues, manual loops, Load and relative native track/group browse. Fourteen optional normal lamps. No mixer, jog/tempo or audio setup.',
        bankChanges=[{'channel':ch,'number':33,'anyPositive':True,'decks':[deck],'releaseShiftChannels':[]} for ch,deck in [(0,'a'),(2,'b')]],
        gaps=[DJINN_REVIEW])
    for ch,deck in [(0,'a'),(2,'b')]:
        for action,n in [('play',32),('cuePreview',31),('keylock',29),('loopIn',2),('loopOutOrExit',3),('reloop',4),('pitchBendDown',34),('pitchBendUp',35),('load',1)]:
            add(p,action,ch,n,deck=deck,feedback=action in ['play','cuePreview','keylock'])
            add(p,action,ch,n+63,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for slot in range(4):
            add(p,f'hotcue{slot+1}',ch,8+slot,deck=deck,feedback=True)
            add(p,f'hotcue{slot+1}',ch,71+slot,deck=deck);p['inputs'][-1]['releaseOnly']=True
        add(p,'openGroup',ch,5)
        add(p,'openGroup',ch,68);p['inputs'][-1]['releaseOnly']=True
        for action,n in [('browse',22 if ch==0 else 38),('browseGroups',23 if ch==0 else 39)]:
            for number in [n,n+63]:add(p,action,ch,number,'control','binaryOffset')
    manual=deepcopy(p)
    manual.update(id=DJINN_MODE3,catalogueName=DJINN,definition='reviewed:djinn-manual-mode3',autoSelect=False,
        aliases=[DJINN_MODE3,'DJinn MIDI mode 3'],excludedAliases=['DJAZZ','DJAM','S70','M70'],
        hardwareMode='Manual native layout. Select hardware MIDI/audio Mode3, factory channels1-2-3 and Hold TAP. Mode3 is controller-only; configure separate app audio. Mixer source/curve/reverse ownership still needs qualification. Cue Pan is not Cue/Master blend.',
        scope='Manual90-input Mode3 core: the same64 player rows plus26 explicit gain/EQ/level/master/crossfader/headphone-level rows. Fourteen optional player lamps. No jog/tempo, invented PFL/cueMix or audio setup.')
    for ch,deck,base,level in [(0,'a',17,16),(2,'b',33,32)]:
        for action,n in [('gain',base),('high',base+1),('mid',base+2),('low',base+3),('level',level)]:
            for number in [n,n+63]:add(manual,action,ch,number,'control',deck=deck)
    for action,n in [('master',49),('crossfader',48),('monitor',51)]:
        for number in [n,n+63]:add(manual,action,1,number,'control')
    return [manual,p]

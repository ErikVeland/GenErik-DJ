"""Independent TOUR1 primary-bus MIDI mixer with source-local pickup reset."""
from curated import add, profile

TOUR1_NAME='Pioneer DJM-TOUR1'
TOUR1_SPEC='https://downloads.support.alphatheta.com/manuals/DJM_TOUR1_DJM_TOUR1_MIDI_Message_e_v100_addendum/'
TOUR1_REFERENCES={TOUR1_NAME:{
    'url':TOUR1_SPEC,'sha256':'99e99068f1f9149a35687e08aee862fdbd58f13965e010975bcaad3a86769eb5',
    'version':'1.00','pages':[2,3,4],'visuallyReviewedPages':[2,3,4],
    'supportURL':'https://support.alphatheta.com/en-US/articles/21934589697945',
    'acquisition':'The current support page links the public MIDI addendum. Direct curl returned404, but the browser document viewer displayed all four pages and its Download button supplied the pinned PDF. No account, EULA or private SDK was required.',
    'review':'Independent manufacturer table qualifies32 selected controls on manually chosen channel1 with BUTTON TYPE TOGGLE. Primary PFL is CC70..73, not the separate second-headphone Note1..4. All four strips have their own explicit gain/three-band EQ/Color/level addresses. Master24, primary headphone level26/blend27 and crossfader11 are seven-bit absolute app controls. Each of24 source-selector Note messages resets pickup only on its own source and strip when the new source reports127. Footnote2 explicitly sends old selection OFF/new selection ON. C/D require opt-in. Separate headphone bus, hardware audio ownership, touchscreen/PRO DJ LINK, source/audio routing, effects, physical taper/calibration, full feedback/lifecycle and physical/iPad/A10X acceptance remain open. No sibling table, stored-setting write, hardware output or automatic audio route is inferred.'}}


def tour1_profiles():
    result=profile(TOUR1_NAME,TOUR1_SPEC)
    result.update(autoSelect=False,role='accessory',
        aliases=[TOUR1_NAME,'Pioneer DJ DJM-TOUR1','DJM-TOUR1','DJM-TOUR1 MIDI 1'],
        excludedAliases=['CDJ-TOUR1','DJM-V5','DJM-900NXS2','DJM-2000','DJM-2000NXS'],
        hardwareMode='Manually select MIDI channel1 and BUTTON TYPE TOGGLE. Enable MIDI transmission. Use separate app audio. Physical CH1-4 map to A-D; C/D require opt-in. Only the primary headphone controls are mapped.',
        scope='Manual independent four-strip gain/EQ/Color/fader and direct CC PFL-state controls, primary headphone/master/crossfader controls and per-strip pickup reset after input selection.',
        gaps=['Manual channel1/TOGGLE only; no factory setting is inferred. Second headphone bus, full touchscreen/PRO DJ LINK/FX/microphone/AUX/curve controls, hardware/software audio ownership, external deck routing, physical taper/calibration, complete feedback/lifecycle and physical/iPad/A10X acceptance remain open. No setting, output, sibling protocol or audio route is written.'])
    strips=[(1,2,3,4,5,17),(6,7,8,9,10,18),(12,14,15,21,22,19),(80,81,92,82,83,20)]
    selectors=[(0x35,0x42,0x32,0x33,0x34,0x43),(0x39,0x44,0x36,0x37,0x38,0x45),(0x3D,0x46,0x3A,0x3B,0x3C,0x47),(0x41,0x48,0x3E,0x3F,0x40,0x49)]
    result['bankChanges']=[]
    for index,(deck,numbers) in enumerate(zip('abcd',strips)):
        for action,number in zip(['gain','high','mid','low','filterKnob','level'],numbers):add(result,action,0,number,'control',deck=deck)
        add(result,'cueState',0,70+index,'control',deck=deck)
        result['bankChanges'] += [{'channel':0,'number':number,'onValue':127,'decks':[deck]} for number in selectors[index]]
    for action,number in [('master',24),('monitor',26),('cueMix',27),('crossfader',11)]:add(result,action,0,number,'control')
    return [result]

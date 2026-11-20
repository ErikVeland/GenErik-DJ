"""Independent DJ-707M MIDI facts without a direct iPad route claim."""
from curated import add, profile

DJ707M_SOURCE = 'https://static.roland.com/assets/media/pdf/DJ-707M_MIDI_Imple_Chart_jpn01_W.pdf'
DJ707M_REFERENCES = {'Roland DJ-707M': {
    'url': DJ707M_SOURCE, 'sha256': '1e36cb927bb1248f09cb0404575b81c35b850d0f29995ee5f195ee1333e2400e',
    'files': [{'cachePath': 'TestBuilds/r449/upstream/dj707m-midi-jpn.pdf', 'sha256': '1e36cb927bb1248f09cb0404575b81c35b850d0f29995ee5f195ee1333e2400e'}, {'cachePath': 'TestBuilds/r449/upstream/dj707m-manual.pdf', 'sha256': '0207dab3084c6f52b0ecd05aeb99f40c6ec094ddb94a1332a66741fbe62facbb'}],
    'relatedSources': [{'url': 'https://static.roland.com/assets/media/pdf/DJ-707M_eng01_W.pdf'}],
    'review': 'Own manufacturer v1.02 three-page MIDI chart visually reviewed. Raw0..3 Note0 Play,1 Instant Cue,2 Sync,3 Sync Off,5 Return to beginning,8 Deck,13 Key,14 Range and27 monitoring Cue. Own manual identifies Shift+Cue as Return to beginning and Shift+Range as Keylock. Global Shift is raw15 Note0. Native normal transport/PFL/Load/filter/browse is Shift-guarded; Key13 requires Shift. Cue5,Sync3,Range14 and shifted pad28..35 are release-only guards. Raw4..7 pads20..27 require explicit Hot Cue mode0, with other modes1..11 blocking. Own deck selector8 invalidates its pad mode. Global raw15 Loads2..5, Back7 and CC0 Select are independently charted. CC0 has binary offset64: left63 down, right65 up. FilterCC26 is separate7bit. High-resolution paired numbers do not by themselves establish byte significance or pitch polarity, so tempo/gain/EQ/level/crossfader remain inactive. No jog/calibration/LED colour/output/SysEx/FX/TR-S/mic/OSC state is inherited from DJ-202/DJ-505/DJ-808. This manual107-input subset requires an already available, independently qualified MIDI bridge from PC-A. Own manual p22 routes iOS audio through PC-B Generic, explicitly excludes DJ software there and sends standalone controller MIDI through PC-A. Native does not provide the PC-A USB driver/bridge or a direct iPad controller route. Audio ownership/routes, PC host handover, complete pad/deck modes/feedback/lifecycle/recovery and physical/iPad/A10X acceptance remain open. No setup, identity query, mode, driver, firmware, reset or audio-route packet runs.'}}


def dj707m_profiles():
    """Return a manual bridge-input subset with unknown pad modes at startup."""
    p = profile('Roland DJ-707M', DJ707M_SOURCE)
    p.update(definition='reviewed:roland-dj707m-bridge-core', autoSelect=False, role='accessory',
        excludedAliases=['DJ-202','DJ-505','DJ-808'],
        hardwareMode='Manual MIDI bridge input only. Independently qualify a PC-A MIDI bridge before selecting this profile. PC-B Generic iOS audio does not establish controller MIDI. Select Hot Cue on each deck before using pads. C/D require app opt-in. Native does not configure the bridge, driver, hardware mode or audio.',
        scope='Manual107-input bridge-only four-target transport/PFL/filter, guarded Hot Cues, Keylock, Load and browse subset. No direct iPad controller route, output, high-resolution controls or audio setup. Full hardware modes/lifecycle remain open.',
        inputModes=[{'channel': ch+4, 'numbers': list(range(12)), 'invalidatingSelectors': [{'channel': ch, 'number':8}]} for ch in range(4)],
        bankChanges=[{'channel': ch, 'number':8, 'anyPositive':True, 'decks':list('ac' if ch%2==0 else 'bd')} for ch in range(4)],
        gaps=[DJ707M_REFERENCES['Roland DJ-707M']['review']])
    add(p,'shift',15,0)
    for ch, deck in enumerate('abcd'):
        for action,n in [('play',0),('cuePreview',1),('sync',2),('cue',27)]:
            add(p,action,ch,n,deck=deck);p['inputs'][-1]['shifted']=False
        for action,n in [('cuePreview',5),('sync',3),('keylock',14)]:
            add(p,action,ch,n,deck=deck);p['inputs'][-1]['releaseOnly']=True
        add(p,'keylock',ch,13,deck=deck);p['inputs'][-1]['shifted']=True
        add(p,'filterKnob',ch,26,'control',deck=deck);p['inputs'][-1]['shifted']=False
        add(p,'load',15,2+ch,deck=deck);p['inputs'][-1]['shifted']=False
        for slot in range(8):
            add(p,f'hotcue{slot+1}',ch+4,20+slot,deck=deck);p['inputs'][-1].update(requiredMode=0,shifted=False)
            add(p,f'hotcue{slot+1}',ch+4,28+slot,deck=deck);p['inputs'][-1]['releaseOnly']=True
    add(p,'browse',15,0,'control','binaryOffset');p['inputs'][-1]['shifted']=False
    add(p,'browsePreviousGroup',15,7);p['inputs'][-1].update(shifted=False,pulse=True)
    return [p]

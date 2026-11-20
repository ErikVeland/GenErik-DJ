"""Encore 2000 manufacturer facts with configured deck channels and no Mix CH guess."""
from curated import add, profile

ENCORE_SOURCE='https://d295jznhem2tn9.cloudfront.net/ItemRelatedFiles/8330/encore_2000.pdf'
ENCORE_REFERENCES={'American Audio ENCORE 2000':{
    'url':ENCORE_SOURCE,'sha256':'d014dd7cdded5ef6767e38e135b7281da589b217cfd4bf2548afce9c40b308c2',
    'files':[{'cachePath':'TestBuilds/r454/upstream/encore2000-manual.pdf','sha256':'d014dd7cdded5ef6767e38e135b7281da589b217cfd4bf2548afce9c40b308c2'}],
    'review':'Own manufacturer pp26/27 numeric MIDI table visually reviewed. NOTE switches and lamps use9n127/0. Absolute CCs useBn0..127. MIDI2(TAP) numbers are explicit normal+63 aliases. This manual68-input subset requires separately configured left MIDI channel1/raw0 and right channel2/raw1. The manual documents TAP+Pitch Bend channel changes but does not establish factory deck channel numbers or numeric Mix CH. No default or Mix CH is guessed. Normal Play17hex/Cue13hex/TempoLock06hex/In0F/Out0B/Reloop0C/BendDown08/Up10 have release-only TAP aliases. TAP Note04 both edges retire only the source/deck held controls, before possible channel changes. Both normal and TAP CC families21..25hex/60..64hex deliberately retain the same native gain/EQ/level functions. Native assigns normal Folder0D to group entry, TAP Folder4C to Load for that deck and opposite-layer releases to rearming. Track11/15hex step native tracks, TAP50/54hex step native groups; all four are directional pulses. Six optional normal Play/Cue/Keylock lamps use127/0. Mix CH controls/master/headphones/crossfader/relay, jog calibration, pitch polarity/range, other switches, full mode/channel discovery/feedback/lifecycle/recovery, USB/driver/OS/power/audio and physical/iPad/A10X acceptance remain open. Enter MIDI mode manually with Source Select held3seconds before using the profile. No source-mode, query, pickup, preset, driver, firmware or audio-route command runs. Encore1000/ELMC1/VMS protocols are not inherited.'}}


def encore2000_profiles():
    """Return the configured two-deck manual subset without hardware channel writes."""
    p=profile('American Audio ENCORE 2000',ENCORE_SOURCE)
    p.update(definition='reviewed:encore2000-configured-core',autoSelect=False,role='accessory',
        aliases=['American Audio ENCORE 2000','Encore 2000','ENCORE2000'],
        excludedAliases=['Encore 1000','ELMC-1','VMS4'],
        hardwareMode='Manual configured channels only. Enter MIDI mode before use. Configure left channel1 and right channel2 with the documented TAP/Pitch Bend controls. Factory channel defaults and numeric Mix CH are not established. Folder enters a group and TAP+Folder loads its deck. Full mode/audio/USB ownership remains open.',
        scope='Manual68-input two-deck transport/held Cue/bends, manual loops, Keylock, mirrored normal/TAP gain/EQ/level and track/group navigation/Load subset. Six optional lamps. No Mix CH, jog/tempo or automatic audio setup.',
        bankChanges=[{'channel':ch,'number':4,'anyPositive':True,'decks':[deck],'releaseShiftChannels':[]} for ch,deck in enumerate('ab')],
        gaps=[ENCORE_REFERENCES['American Audio ENCORE 2000']['review']])
    for ch,deck in enumerate('ab'):
        for action,n in [('play',23),('cuePreview',19),('keylock',6),('loopIn',15),('loopOut',11),('reloop',12),('pitchBendDown',8),('pitchBendUp',16)]:
            add(p,action,ch,n,deck=deck,feedback=action in ['play','cuePreview','keylock'])
            add(p,action,ch,n+63,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for action,n in [('gain',33),('high',34),('mid',35),('low',36),('level',37)]:
            for number in [n,n+63]:add(p,action,ch,number,'control',deck=deck)
        add(p,'openGroup',ch,13)
        add(p,'openGroup',ch,76);p['inputs'][-1]['releaseOnly']=True
        add(p,'load',ch,76,deck=deck)
        add(p,'load',ch,13,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for action,n in [('browsePrevious',17),('browseNext',21),('browsePreviousGroup',80),('browseNextGroup',84)]:
            add(p,action,ch,n);p['inputs'][-1]['pulse']=True
    return [p]

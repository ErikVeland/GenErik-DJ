"""Independent Radius1000 revisions and Radius3000 table facts."""
from curated import add, profile

RADIUS_1000='American Audio RADIUS 1000'
RADIUS_OLD=RADIUS_1000+' (2009 factory mapping)'
RADIUS_3000='American Audio RADIUS 3000'
MANUAL_1000='https://assets.centryngroup.com/dl/files/RADIUS_1000__DL__001.%20March%202010%29'
FACTORY_1000='https://www.adj.com/cdn/shop/files/84368c9268e29e2f3d38f814e4029167dcd9bcb4_vdj6_radius1000.zip?v=9125319635821468713'
MANUAL_3000='https://d295jznhem2tn9.cloudfront.net/ItemRelatedFiles/8354/radius_3000.pdf'
RADIUS_PLAYER_REFERENCES={
    RADIUS_OLD:{'url':FACTORY_1000,'sha256':'03f6262414642ea81c87c451c24ef46097cb04c1265479ae41c1d6ed7b0c2522','files':[
        {'cachePath':'TestBuilds/r457/upstream/radius1000-vdj.zip','sha256':'03f6262414642ea81c87c451c24ef46097cb04c1265479ae41c1d6ed7b0c2522'},
        {'cachePath':'TestBuilds/r457/upstream/radius1000-data/Devices/American Audio Radius 1000 definition.xml','sha256':'c545bf2465d35282947e1ed142182ff26685519779b028aa75737ea677be8d75'},
        {'cachePath':'TestBuilds/r457/upstream/radius1000-data/Mappers/American Audio Radius 1000 mapping.xml','sha256':'94f3166daa06d5ec3a147344e623cdddc2fbb6295ed67e8183dde4f15ff03a12'}],
        'review':'Own manufacturer product links the2009 VirtualDJ6 archive. Its NSIS container was listed and only two XML data files extracted with the archive reader; the executable and mapper were not run. This39-input manual old-protocol layout requires raw channel0, Relative encoders, pitch-bend pitch and1024-pulse jog. Its TAP32, touch38 and shifted normal+63 differ from the manufacturer2010 manual. Never combine these revisions. Own XML specifies binary-offset64 jogCC53 with full1024 and inverted pitch bend. Native normal jog/tempo are TAP-guarded and use fixed native touch scratch and+/-8percent tempo. Shifted touch101 only releases. Folder/Track CC54/56 and TAP117/119 step native groups/tracks. Folder25 opens a group and Track31 loads the current manual target. Play42/Cue48/Keylock6/In11/Out5/Reloop23/Bends7/13/Halve14/Double8 and three Hot Cues22/16/10 have explicit shifted release aliases. No native Sync toggle is assigned to the source one-off BPM match. TAP both edges retire source-owned holds before possible configuration changes. Manual profiles target A and do not gain automatic separate-player assignment. Revision detection, other channels/presets, source ADV/sample/FX/modes/encoder ranges, full feedback/lifecycle/recovery, USB/OS/audio routing and physical/iPad/A10X acceptance remain open. No setup, query, driver, firmware, reset, executable, mapper or audio-route command runs.'},
    RADIUS_1000:{'url':MANUAL_1000,'sha256':'2c98b2d66e553dcd3e5b18486372a0902d60a7a5f4bb1cadd2eaead9bfbefdce','files':[
        {'cachePath':'TestBuilds/r457/upstream/radius1000-manual.pdf','sha256':'2c98b2d66e553dcd3e5b18486372a0902d60a7a5f4bb1cadd2eaead9bfbefdce'}],
        'review':'Own manufacturer March2010 manual pp35/36 visually reviewed. This38-input manual preset uses its distinct TAP46, touch32 and shifted plus61 NOTE family. The conflicting own2009 factory definition has a separate manual profile; neither is automatically selected. Select MIDI mode, default NOTE command assignments, Hold TAP and CC TYPE NOTE for directional encoder navigation. Native Play42/Cue48/Keylock6/In11/Out5/Reloop23/Bends7/13/Halve14/Double8 and three Hot Cues22/16/10 retain explicit shifted release aliases. Native assigns Folder25 to group entry and Track31 to Load A, with shifted86/92 only rearming. CW/CCW folder54/55 and track56/57 are directional native group/track pulses; shifted115/116/117/118 deliberately retain those native actions. Hardware channel changes remain on the manual A target, not an invented virtual deck. TAP46/P34 both edges retire only source-owned holds. Relative encoder encoding, jog/contact calibration, pitch polarity, revision/mode/preset discovery, hardware multi-deck paging, full feedback/lifecycle/recovery, USB/OS/audio routing and physical/iPad/A10X acceptance remain open. No native Sync toggle is assigned to the BPM-display control. No setup, identity query, preset, driver, firmware or audio-route write runs. Radius2000/3000 and the2009 mapping are not inherited.'},
    RADIUS_3000:{'url':MANUAL_3000,'sha256':'6616197b7f82b1d2ddb18e24946ae9cbe795b5539303a52a41f6287749136ffd','files':[
        {'cachePath':'TestBuilds/r457/upstream/radius3000-manual.pdf','sha256':'6616197b7f82b1d2ddb18e24946ae9cbe795b5539303a52a41f6287749136ffd'}],
        'review':'Own manufacturer pp38/39 numeric MIDI table visually reviewed. Factory raw0, Relative encoders, Pitch Bend and sensor1024 are explicit in the manual. This40-input automatic button core uses its own plus63 shifted NOTE family, four Hot Cues22/16/10/34 and normal Play42/Cue48/Keylock6/In11/Out5/Reloop23/Bends7/13/Halve14/Double8. Shifted positives only rearm the corresponding native action. Native assigns Folder25 to group entry and Track31 to Load on the app-assigned player deck, with shifted88/94 release guards. Directional folder54/55 and track56/57 only operate after selecting the documented CC TYPE NOTE; shifted117/118/119/120 retain those native group/track assignments. Default Relative encoder format is not guessed. MIDI channels1..16 keep the source-assigned app deck and do not implement hardware channel-selected virtual paging. TAP32/P46 both edges retire only source-owned holds. The manufacturer3000 page links an SSL archive containing only Radius1000 XML; it is not a3000 protocol source. Relative encoding/jog/contact calibration, pitch polarity, stored note edits, complete mode/preset/paging/feedback/lifecycle/recovery, USB/Link/OS/audio routing and physical/iPad/A10X acceptance remain open. Enter hardware MIDI mode and use default command assignments. No native Sync toggle is assigned to BPM-display control. No output, setup, query, preset, firmware, driver or audio-route write runs. Radius1000/2000 are not inherited.'}}


def radius_legacy_player_profiles():
    """Keep versioned manual profiles separate from the own3000 button core."""
    results=[]
    for name in [RADIUS_OLD,RADIUS_1000,RADIUS_3000]:
        old=name==RADIUS_OLD;current=name==RADIUS_1000;offset=61 if current else 63
        ref=RADIUS_PLAYER_REFERENCES[name];p=profile(name,ref['url'])
        p.update(definition='reviewed:radius1000-2009-factory' if old else 'reviewed:radius1000-2010-note-core' if current else 'reviewed:radius3000-note-core',
            role='player',autoSelect=name==RADIUS_3000,
            aliases=[name,'Radius1000 2009 factory mapping','Radius 1000 2009'] if old else [name,'Radius 1000','RADIUS1000','Radius 1000 2010'] if current else [name,'Radius 3000','RADIUS3000'],
            excludedAliases=['Radius 2000','Radius 3000','2010'] if old else ['Radius 2000','Radius 3000','2009'] if current else ['Radius 1000','Radius 2000'],
            hardwareMode='Manual2009 factory protocol only: raw channel0, Relative CC,1024-pulse normal jog, Hold TAP and pitch-bend pitch. Target A. Fixed native touch scratch. No automatic revision detection.' if old else 'Manual March2010 protocol only. Enter MIDI mode with default commands and Hold TAP. Directional navigation requires CC TYPE NOTE. Target A. The2009 definition has different TAP/touch/shift bytes.' if current else 'Hardware MIDI mode and default note commands. Native assigns a separate app deck per source. CC TYPE NOTE is required only for directional encoder navigation. Factory Relative jog/tempo remain inactive. Hardware virtual-deck paging and USB/Link/audio modes remain open.',
            scope='Manual39-input2009 transport/held Cue/bends, three Hot Cues, loops, documented1024-count jog/contact and inverted native tempo, track/group browse/Load. Target A. No outputs/setup/audio write.' if old else 'Manual38-input2010 button core with transport/held Cue/bends, three Hot Cues, loops, note-format track/group navigation and Load A. No jog/tempo/outputs/setup.' if current else 'Automatic40-input own3000 button core with transport/held Cue/bends, four Hot Cues, loops, note-format track/group navigation and source-owned Load. No jog/tempo/outputs/setup.',
            bankChanges=[{'channel':0,'number':n,'anyPositive':True,'decks':['a'],'releaseShiftChannels':[],**({} if old else {'anyChannel':True})} for n in ([32] if old else [46,34] if current else [32,46])],
            gaps=[ref['review']])
        if old:p['catalogueName']=RADIUS_1000
        for action,n in [('play',42),('cuePreview',48),('keylock',6),('loopIn',11),('loopOutOrExit',5),('reloop',23),('pitchBendDown',7),('pitchBendUp',13),('loopDown',14),('loopUp',8)]:
            add(p,action,0,n,deck='a')
            add(p,action,0,n+offset,deck='a');p['inputs'][-1]['releaseOnly']=True
        for slot,n in enumerate([22,16,10]+([34] if name==RADIUS_3000 else []),1):
            add(p,f'hotcue{slot}',0,n,deck='a')
            add(p,f'hotcue{slot}',0,n+offset,deck='a');p['inputs'][-1]['releaseOnly']=True
        add(p,'load',0,31,deck='a')
        add(p,'load',0,31+offset,deck='a');p['inputs'][-1]['releaseOnly']=True
        add(p,'openGroup',0,25)
        add(p,'openGroup',0,25+offset);p['inputs'][-1]['releaseOnly']=True
        if old:
            add(p,'jogTouch',0,38,deck='a')
            add(p,'jogTouch',0,101,deck='a');p['inputs'][-1]['releaseOnly']=True
            add(p,'jog',0,53,'control','binaryOffset','a');p['inputs'][-1].update(argument=1024,shifted=False)
            add(p,'tempo',0,0,'pitch',deck='a');p['inputs'][-1].update(inverted=True,shifted=False)
            for action,n in [('browseGroups',54),('browse',56)]:
                for number in [n,n+63]:add(p,action,0,number,'control','binaryOffset')
            add(p,'shift',0,32)
        else:
            for action,n in [('browseNextGroup',54),('browsePreviousGroup',55),('browseNext',56),('browsePrevious',57)]:
                for number in [n,n+offset]:
                    add(p,action,0,number);p['inputs'][-1]['pulse']=True
            for row in p['inputs']:row['anyChannel']=True
        results.append(p)
    return results

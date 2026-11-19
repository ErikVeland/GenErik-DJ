"""Independently reviewed manufacturer USB player defaults and native app functions."""
from curated import add, profile

LEGACY_USB_REFERENCES={
    'American Audio VERSADECK': {
        'url':'https://www.adj.com/cdn/shop/files/5be308675de7801329d188d3f0cf44323069d6d2_versadeck_user_manual.pdf?v=11627430234356086881',
        'sha256':'31c2ccf88db7d83704c8eea49c8761690d016feccf2fdd7b41078edea59b9bf9',
        'cacheName':'versadeck-manual.pdf','pages':[10,11,13,19,37,38,39], 'visuallyReviewedPages':[37,38],
        'productURL':'https://www.adj.com/products/versadeck',
        'review':'Own manufacturer table independently qualifies default wire channels0/1/2, selected normal and Shift addresses, 64-centred encoder deltas and note127/0 switches. Both source selectors must be PC and TAP must be Hold. Native Track push loads, Folder push opens groups, the lamp button13 controls app PFL. TAP21 and Cue Play30 stay inactive. Red Hot Cue feedback uses1, not127: manufacturer colour ranges are1..31 red and33..63 green. ProMixer uses conflicting channels/zero addresses and is not inherited. Jog/tempo calibration, complete alternate/FX/kill controls, display/meters, lifecycle/audio and physical/iPad/A10X acceptance remain open.'},
    'Synq DMC-2000': {
        'url':'https://synq-audio.com/fileuploader/download/download/?d=0&file=custom%2Fupload%2FFile-1466605574.pdf&name=DMC-2000_Manual_v2.0',
        'sha256':'8531ac0d5857cf028e55c7480fd9cf7f4ffae6830747bedb68fc4361ae9dcc1f',
        'cacheName':'dmc2000-v2.pdf','pages':[9,10,12,16,17,18,19,20,21], 'visuallyReviewedPages':[18,19], 'pageNumbering':'PDF page numbers',
        'productURL':'https://synq-audio.com/dmc-2000',
        'mappingURL':'https://synq-audio.com/fileuploader/download/download/?d=0&file=custom%2Fupload%2FFile-1438607731.zip&name=DMC-2000_Traktor2_mappings',
        'mappingSHA256':'d569f63552022c84d7aa66d6c8295ba85b35ab11d332941076afa0759510a0ab',
        'mappingMember':'DMC2000-TRAKTOR2_PRO-BASIC_mapping/DMC2000-TRAKTOR2_PRO-BASIC_mapping (WITH XFADER).tsi',
        'mappingMemberSHA256':'1667c7fdda330cb18d7c9b53456a4f70076a0c75239414960040df6ce61ce505',
        'review':'Own v2.0 manufacturer manual independently qualifies default wire channels0/1/2, normal/Shift addresses, 64-centred encoder deltas and note127/0 switches. Both deck selectors must be MIDI, mixer mode MIDI and TAP Hold. Native Track push and Load Track13 load the deck; Folder push opens groups. TAP/Shift30 and Database33 stay inactive. The separate official basic Traktor TSI independently corroborates overlapping raw wires without executing Traktor commands. Red Hot Cue lamps use127 on their dedicated addresses; green addresses differ from VERSADECK and stay inactive. ProMixer conflicts are not inherited. Jog/tempo calibration, complete alternate/FX/kill controls, display/meters, lifecycle/audio and physical/iPad/A10X acceptance remain open.'}}


LEGACY_USB_REFERENCES['CITRONIC MPX10']={
    'url':'https://www.billebro.se/proddoc/PRID_6104_doc_170700.pdf',
    'sha256':'caa911c15469f79a80a9ee3e0e20e6f7b81fadd9e53911f3bd7bb0f13ecc7e04',
    'cacheName':'citronic-mpx10-v3.pdf','cacheRequest':'r413','version':'3.0',
    'pages':[3,11,15,16,20,21,22,23,24],'visuallyReviewedPages':[20,21,22],
    'review':'Independent manufacturer-authored MP-X10 Version3.0 manual from a public retailer mirror qualifies default wire channels0/1/2 and selected normal/Shift note/CC families. Both deck selectors must be PC and Mixer Setup must be MIDI, not its documented default Mixer. TAP Hold and default channels1/2/3 are required. Selected wires independently match the bounded legacy USB observer; no sibling protocol or calibration is inferred. Native Track push loads, Folder push opens groups and lamp button13 controls app PFL. Dedicated red Hot Cue lamps use127; green Note48..51 differs from VERSADECK/DMC and remains inactive. The ProMixer MPX10/DJINN/Syncron XMLs are byte-identical and disagree with this primary default table, so they do not qualify this model. Full alternate/FX/kill/pad functions, jog/touch/tempo calibration, displays/meters, complete lifecycle/audio ownership and physical/iPad/A10X acceptance remain open. No stored setting, firmware, installer or mapping action is executed.'}


def legacy_usb_player_profiles():
    results=[]
    for name,ref in LEGACY_USB_REFERENCES.items():
        versa=name.startswith('American')
        dmc=name.startswith('Synq')
        citronic=name=='CITRONIC MPX10'
        result=profile(name,ref['url'])
        result.update(definition='manufacturer:'+('versadeck' if versa else 'citronic-mpx10' if citronic else 'synq-dmc-2000')+'-default-native',
            inputProtocol='legacyUSBPlayer',aliases=[name,'VERSADECK','American Audio VersaDeck','ADJ VERSADECK'] if versa else [name,'MPX10','MP-X10','Citronic MP-X10'] if citronic else [name,'DMC-2000','DMC2000','SYNQ DMC2000'],
            excludedAliases=['VERSADECK clone'] if versa else ['MPX10 clone','MP-X10 clone','MP-X10 sibling'] if citronic else ['DMC-2000 clone','DMC-1000'],
            hardwareMode=('Set both source selectors to PC.' if versa else 'Set both deck selectors to PC and Mixer Setup to MIDI.' if citronic else 'Set both deck selectors to MIDI and mixer mode to MIDI.')+' Use default MIDI channels1/2/3 and TAP Hold. Configure audio separately. Native uses normal controls; alternate positive commands are inactive.',
            scope='Automatic normal-layer A/B transport, held Cue/bends, key lock, four Hot Cues, manual loops, mixer and library controls. Shift wire changes release held controls and reset pickup on that channel. '+('The lamp button controls app PFL.' if versa or citronic else 'Both Track push and Load Track load the deck.'),
            gaps=['Jog/touch/tempo calibration, dedicated Sync, complete Shift/FX/kill/pad and configurable channel modes, display/meters, complete lifecycle/audio routing and physical/iPad/A10X acceptance remain open. Shift alone does not select an app layer; the next qualified wire change clears held controls/pickup. No stored preset, firmware, source mapping action or automatic audio route is written.'])
        for channel,deck,offset in [(0,'a',0),(2,'b',16)]:
            controls=[('play',32),('cuePreview',31),('keylock',29),('pitchBendDown',34),('pitchBendUp',35),('loopIn',2),('loopOut',3),('reloop',4),('load',1),('openGroup',5)]+[(f'hotcue{s+1}',8+s) for s in range(4)]+[('cue' if versa or citronic else 'load',13)]
            for action,number in controls:
                # Library navigation is global even when its physical input is on a deck channel.
                add(result,action,channel,number,deck=None if action=='openGroup' else deck)
                normal=result['inputs'][-1]
                add(result,action,channel,number+63,deck=None if action=='openGroup' else deck);result['inputs'][-1]['releaseOnly']=True
                if action in ['play','cuePreview','keylock','reloop'] or action.startswith('hotcue'):
                    result['outputs'].append({k:v for k,v in normal.items() if k not in ['encoding','inverted']})
                    if action=='reloop':result['outputs'][-1]['action']='loop'+('A' if deck=='a' else 'B')
                    result['outputs'][-1].update(onValue=1 if versa and action.startswith('hotcue') else 127,offValue=0,offUsesNoteOn=True)
            for action,number in [('level',16),('gain',17),('high',18),('mid',19),('low',20)]:add(result,action,channel,number+offset,'control',deck=deck)
            add(result,'browse',channel,22+offset,'control','binaryOffset')
            add(result,'browseGroups',channel,23+offset,'control','binaryOffset')
        for action,number in [('crossfader',48),('master',49),('monitor',51),('cueMix',52)]:add(result,action,1,number,'control')
        results.append(result)
    return results

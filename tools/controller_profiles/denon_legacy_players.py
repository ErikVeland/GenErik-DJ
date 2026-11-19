"""Independent normal-MIDI facts for legacy Denon single-player sources."""
from curated import add, profile
BASE='https://cdn.inmusicbrands.com/denondj/legacy/'
DENON_PLAYER_REFERENCES={
    'Denon DJ SC2900':{'url':BASE+'sc2900/sc2900em-om-20130513-owners-manual-en.pdf','sha256':'75a523cdb6a9fb37ad5df544391aa52d74089603bd6f683e9e1c4f1f92fedc2e','cacheName':'sc2900-manual.pdf','pages':[41,42,43],'visuallyReviewedPages':[42],
        'review':'Own Normal-mode MIDI table independently qualifies pressure64 transport, four normal and four MIDI Bank2 Hot Cue addresses, key adjust, Sync107 and zeroForward library. Native keeps those fixed functions; hardware Shift/Shift Lock/MIDI Bank reports retire owned contacts rather than importing Hybrid/DVS or Shift software actions. Pitch CC122/123, three contact/jog families and3600-pulse calibration, full feedback/displays/state/lifecycle/audio/OS and physical acceptance remain open.'},
    'Denon DJ S3900':{'url':BASE+'sc3900/sc3900em-om-20130513-en.pdf','sha256':'05e2900187c9fb22ad7b69d7bb747443b3bb4159b702adbd637218bfc7210d58','cacheName':'sc3900-manual.pdf','pages':[38,39,40],'visuallyReviewedPages':[39],
        'review':'Own SC3900 Normal-mode MIDI table independently qualifies pressure64 transport, four normal and four MIDI Bank2 Hot Cue addresses, key adjust, Sync107 and zeroForward library. The catalogue retains its S3900 name and explicit SC3900 aliases. Native does not inherit SC2900 contact streams: SC3900 has separate motor/jog pulse-width reports. Motors, Hybrid/DVS, pitch CC122/123, scratch pulse calibration, complete feedback/displays/state/lifecycle/audio/OS and physical acceptance remain open.'},
    'Denon DJ S3700':{'url':BASE+'dns3700/dns3700-midi-command-list.pdf','sha256':'54e5b974b7a60dd7050fa6ac4a2d76f8aff1a0ef32b7d28e4649d567baf3cbaa','cacheName':'s3700-midi.pdf','pages':[1,2],'visuallyReviewedPages':[1,2],
        'relatedSources':[{'url':BASE+'dns3700/dns3700_ownersmanual.zip','member':'DNS3700_ownersmanual_english.pdf','memberSHA256':'484e15503bb8d1a248e2ef32b450232dafd9f812251b696dec509fde894a4c79'}],
        'review':'Own command table qualifies pressure64 transport, three Hot Cues, separate Auto Loop Set/Exit, Key Adjust6 and zeroForward library. Native Auto Loop Set uses app loop behaviour; Exit disables it. Jog/scratch CC81 and platter CC86 are separate1480-pulse streams and are not conflated. Its own manual defaults MIDI channel1 with1..6 selection. Native accepts the table channel envelope0..15 without inferring motor, Hybrid/DVS, pitch direction/calibration, full modes/displays/feedback/lifecycle/audio/OS or physical acceptance.'},
    'Denon DJ S1200':{'url':BASE+'dns1200/DN-S1200_midicommandlist.pdf','sha256':'9ca1ff5d73419b7ef8894fafd247a9752d121638651547cdac64bb6a06b31536','cacheName':'s1200-midi.pdf','pages':[1,2],'visuallyReviewedPages':[1],
        'relatedSources':[{'url':BASE+'dns1200/DN-S1200_ownersmanual.zip','member':'DN-S1200_ownersmanual_english.pdf','memberSHA256':'1f2591b4bd0ddb92ca590a8fa0717fe45188d0c06ca0b68635933709f9835a51'}],
        'review':'Own command table qualifies pressure64 transport, A1 loop In/B loop Out/Exit-Reloop, held bends and zeroForward library. Its own manual defaults MIDI channel1 with1..6 selection. Native accepts the table channel envelope0..15 and does not invent Hot Cues, a separate Sync button or an independent key-lock meaning for combined Pitch/KEY5. A2/Flip, contact/jog/pitch calibration, FX, complete displays/feedback/state/lifecycle/audio/OS and physical acceptance remain open.'}}


def denon_player_profiles():
    results=[]
    for name,ref in DENON_PLAYER_REFERENCES.items():
        sc=name in ['Denon DJ SC2900','Denon DJ S3900']
        s3700=name=='Denon DJ S3700'
        short='SC3900' if name.endswith('S3900') else name.split()[-1]
        p=profile(name,ref['url']);p.update(role='player',definition='manufacturer:denon-'+short.lower()+'-normal-midi',aliases=[name,'Denon '+short,'DN-'+short,short],excludedAliases=[x for x in ['SC2900','SC3900','S3700','S1200','SC5000','SC6000','DN-HC4500'] if x!=short],
            hardwareMode='Select ordinary USB-MIDI / Normal mode on '+short+'. Each physical input is assigned to its own app deck. The documented channel envelope is accepted. Configure app audio separately.',
            scope='Automatic single-player native transport, held Cue/bends, manual loops and strict library browse/load. '+('Eight native Hot Cues, key lock, Auto Loop and Sync. ' if sc else 'Three Hot Cues, key lock and Auto Loop Set/Exit. ' if s3700 else '')+'Mode reports retire only source-owned contacts on the assigned deck.',
            gaps=['Hybrid/DVS, unqualified jog/contact/pitch calibration, motors, remaining Shift/FX/modes, complete feedback/displays/state/lifecycle/audio/OS and physical/iPad/A10X acceptance remain open. No setup, preset, firmware, motor or audio write.'])
        buttons=[('play',67),('cuePreview',66),('pitchBendDown',9),('pitchBendUp',8),('loopIn',55),('loopOut',57),('reloop',64),('load',40)]
        if sc or s3700:
            buttons += [('keylock',6),('loop',29)]+[(f'hotcue{i+1}',n) for i,n in enumerate([23,24,25,32,115,116,117,118] if sc else [23,24,25])]
            buttons += [('sync',107)] if sc else [('loopDisable',30)]
        for action,n in buttons:add(p,action,0,n,deck='a')
        add(p,'browse',0,84,'control','zeroForward');add(p,'openGroup',0,48)
        for row in p['inputs']:row['anyChannel']=True
        context=[82,51,53,86,96,113,119] if sc else [49,82,51,53,86] if s3700 else [49,82]
        p['bankChanges']=[{'channel':0,'anyChannel':True,'number':n,'onValue':64,'decks':['a'],'releaseShiftChannels':[]} for n in context]
        results.append(p)
    return results

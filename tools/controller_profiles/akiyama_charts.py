"""Independent Akiyama chart subsets with disputed wires kept inactive."""
from curated import add, profile

AKIYAMA_REFERENCES = {
    'Akiyama Quattro': {'url':'https://media.djmania.net/manuales/pdf/118rOPK_Ym0.pdf','cacheName':'quattro-manual.pdf','sha256':'a5b77f2388e42509a10d97a0387091e9b3604a409836506371f58fdbca7dbc59','pages':[20,21,22],
        'review':'Manufacturer manual, mirrored by a retailer. Input chart pages21/22 visually reviewed; channel explanation on20. Four independent deck channels0..3, fixed mixer channel4. Mixer strip labels repeat in error; ordered strips independently agree with the visible model-specific public ProMixer XML. Shift changes transport notes by32. Pitch/crossfader pitch-bend rows use an unclear fixed data byte; software MSB-only scaling and jog calibration remain open. No output or hardware mode write is imported.'},
    'Akiyama Quark SC': {'url':'https://media.djmania.net/manuales/pdf/Manual_Akiyama_Quark_SC.pdf','cacheName':'quark-sc-manual.pdf','sha256':'7c32c6beb499e9c0db199f64fac9bf35c8ef299cd9abf798cc2323db27dd132f','pages':[21,22,23],
        'review':'Independent manufacturer chart pages21..23 visually reviewed. Decks are wire channels0..3; common controls4, separate FX/sample slots5..8. Hardware Shift adds64 to the listed wires. Only normal six-Cue/manual-loop layout is qualified. Native composes the two physical Shift contacts across their paged channel aliases; source-owned holds retire on either Shift, deck or pad-mode transition. Jog calibration, AutoLoop/Roll modes, slot processing, LED state and complete setup remain open.'},
    'Akiyama TTWO': {'url':'https://media.djmania.net/manuales/pdf/Manual_Akiyama_TTwo.pdf','cacheName':'ttwo-manual.pdf','sha256':'294769de28e27e6a9c6d2ead05f5e58a2309e0d14a913dd38af608530cd5dfda','pages':[20,21],
        'review':'Independent manufacturer chart pages20/21 visually reviewed. Deck channels0..3 and direct loads/PFL on4/5 remain separate. Visible model-specific ProMixer facts confirm the selected normal mixer fields. The chart repeats Quattro labels/values in mixer maxima and its LED heading. Pitch54/118 conflicts with filter54, jog forward32/reverse33 and Shift33 are ambiguous, browser press/release differ, and LED on/off rows disagree. These disputed pitch/filter/jog/browser-press/crossfader/output rows remain inactive. No sibling mapping or hardware write is inferred.'},
}

for _name, _digest in [('Akiyama Quattro','17d2d4b9250f7251f1955a43ea3b3b011f25dca27a442c2e4af2783f7430a7d4'),
                       ('Akiyama Quark SC','55bee8213c1b13c4fccb4edc654c3a2df5ff04312685e14a3319d69cfb7c9971'),
                       ('Akiyama TTWO','b8b4e5b58068ad878d720ac2c6ee377459d6374a53c636e252a00327715ac459')]:
    AKIYAMA_REFERENCES[_name]['relatedSources']=[{
        'url':'https://dmsdown.com/descargas/DMS_DJPROMIXER/DJProMixer_3.0_Setup.exe',
        'sha256':'0557173bb5cb8bce866bbd439bd10140d8c281fd550486541dc4ddfff46edbec',
        'member':'Devices/AKIYAMA '+_name.split(' ',1)[1].upper()+'.xml','memberSHA256':_digest,
        'evidenceLimit':'Visible XML address facts only; no source action, installer or script is copied or executed.'}]


def _normal(result, action, channel, number, deck, alternate=None):
    add(result,action,channel,number,deck=deck)
    result['inputs'][-1]['shifted']=False
    if alternate is not None:
        add(result,action,channel,alternate,deck=deck)
        result['inputs'][-1]['releaseOnly']=True


def _base(name, mode):
    result=profile(name,AKIYAMA_REFERENCES[name]['url'])
    result.update(autoSelect=False,definition='reviewed:'+name.lower().replace(' ','-')+'-manual-chart',
                  hardwareMode=mode+' Manual selection only. Configure audio separately.',
                  excludedAliases=[n for n in AKIYAMA_REFERENCES if n!=name],
                  scope='Independent manual normal-layer chart subset with four explicit deck targets, source-owned Cue release, native mixer pickup and bounded mode cleanup. No hardware write or automatic audio route.')
    return result


def akiyama_chart_profiles():
    quattro=_base('Akiyama Quattro','Normal MIDI channels0..3 with fixed mixer channel4. Shared Shift guards unsupported alternate functions.')
    add(quattro,'shift',4,114)
    quattro['bankChanges']=[{'channel':4,'number':114,'onValue':127,'decks':list('abcd')}]
    for channel,deck in enumerate('abcd'):
        for action,number in [('play',51),('cuePreview',50),('sync',49),('keylock',48),('loopIn',45),('loopOut',46),('loopDown',53),('loopUp',54)]:
            _normal(quattro,action,channel,number,deck,{51:83,50:82,49:81}.get(number))
        for slot in range(4):_normal(quattro,f'hotcue{slot+1}',channel,40+slot,deck)
        for index,action in enumerate(['gain','high','mid','low','filterKnob','level']):
            add(quattro,action,4,33+6*channel+index,'control',deck=deck)
        add(quattro,'load',4,97+channel,deck=deck)
        add(quattro,'cue',4,102+channel,deck=deck)
        quattro['bankChanges'].append({'channel':channel,'number':55,'onValue':127,'decks':list('ac' if channel%2==0 else 'bd')})
    for action,number in [('master',57),('cueMix',58),('monitor',59)]:add(quattro,action,4,number,'control')
    add(quattro,'browse',4,5,'control','binaryStep')
    add(quattro,'openGroup',4,96)
    quattro['gaps']=['Pitch/crossfader MSB scaling, jog/touch calibration and scratch mode, sampler/FX, alternate Shift actions, thru/source ownership, complete feedback/lifecycle/audio and physical/iPad/A10X acceptance remain open. No ambiguous pitch packet, source script or hardware command is used.']

    quark=_base('Akiyama Quark SC','Normal six-Hot-Cue pad page, deck channels0..3 and common channel4. Shift CC aliases preserve selected mixer functions; other Shift actions release only.')
    quark['bankChanges']=[]
    for channel,deck in enumerate('abcd'):
        add(quark,'shift',channel,63)
        quark['inputs'][-1]['shiftInput']=channel%2
        quark['bankChanges'].append({'channel':channel,'number':63,'onValue':127,'decks':list('abcd')})
        quark['bankChanges'].append({'channel':channel,'number':7,'onValue':127,'decks':list('ac' if channel%2==0 else 'bd')})
        quark['bankChanges'] += [{'channel':channel,'number':n,'onValue':127,'decks':[deck]} for n in [41,42,43]]
        for action,number in [('play',52),('cuePreview',53),('sync',54),('load',59),('cue',60),('loopIn',47),('loopOut',48),('reloop',49),('loop',44),('pitchBendDown',50),('pitchBendUp',51)]:
            _normal(quark,action,channel,number,deck,number+64)
        for slot in range(6):_normal(quark,f'hotcue{slot+1}',channel,23+3*slot,deck,87+3*slot)
        for action,number in [('tempo',56),('gain',9),('high',10),('mid',11),('low',12),('level',59)]:
            for n in [number,number+64]:add(quark,action,channel,n,'control',deck=deck)
        add(quark,'loopSize',channel,44,'control','binaryDirection',deck)
        quark['inputs'][-1]['shifted']=False
    for action,number in [('master',1),('crossfader',4)]:
        for n in [number,number+64]:add(quark,action,4,n,'control')
    for action,number in [('browse',2),('browseGroups',66)]:add(quark,action,4,number,'control','binaryOffset')
    for number in [2,66]:add(quark,'openGroup',4,number)
    quark['gaps']=['Jog/touch calibration, pitch physical polarity/range, AutoLoop/Roll pad pages, separate FX/sample slots, source Shift alternatives, complete feedback/lifecycle/audio and physical/iPad/A10X acceptance remain open. Pitch follows increasing published CC values; physical calibration remains unresolved. No cue-delete, ring, meter or hardware mode command is sent.']

    ttwo=_base('Akiyama TTWO','Normal deck channels0..3, direct loads/PFL on4/5 and shared Shift on4. Disputed pitch/filter/jog/feedback rows remain inactive.')
    add(ttwo,'shift',4,36)
    ttwo['bankChanges']=[{'channel':4,'number':36,'onValue':127,'decks':list('abcd')}]
    for channel,deck in enumerate('abcd'):
        for action,number in [('play',47),('cuePreview',46),('sync',45),('loopIn',41),('loopOut',42),('loopDown',40),('loopUp',43),('pitchBendDown',38),('pitchBendUp',39)]:
            _normal(ttwo,action,channel,number,deck,{47:15,46:14,45:13,41:9,42:10}.get(number))
        for slot in range(4):_normal(ttwo,f'hotcue{slot+1}',channel,32+slot,deck,slot)
        for action,number in [('gain',50),('high',51),('mid',52),('low',53),('level',55)]:add(ttwo,action,channel,number,'control',deck=deck)
        common=4+channel//2
        _normal(ttwo,'load',common,32+channel%2,deck,64+channel%2)
        add(ttwo,'cue',common,34+channel%2,deck=deck)
        ttwo['bankChanges'].append({'channel':channel,'number':44,'onValue':127,'decks':list('ac' if channel%2==0 else 'bd')})
    for action,number in [('cueMix',82),('monitor',81)]:add(ttwo,action,4,number,'control')
    for action,number in [('browse',24),('browseGroups',25)]:add(ttwo,action,4,number,'control','binaryStep')
    ttwo['gaps']=['Conflicting pitch/filter54, paired resolution/order, jog direction/Shift/calibration, browser press/release, crossfader type, master channel and lamp rows remain inactive. Sampler/FX, alternate Shift actions, complete feedback/lifecycle/audio and physical/iPad/A10X acceptance remain open. The table labels do not authorise Quattro protocol inheritance.']
    return [quattro,quark,ttwo]

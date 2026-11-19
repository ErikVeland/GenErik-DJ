"""Original MDJ-1000 facts from the primary owner's captured-message appendix."""
from curated import add, profile

MDJ1000_REFERENCES = {'Gemini MDJ-1000': {
    'url': 'https://www.theseus.fi/bitstream/handle/10024/133340/opinnaytetyo_joakim_mattson_8.pdf?sequence=1',
    'sha256': None,
    'relatedSources': [{
        'url': 'https://www.recordcase.de/media/94/11/39/1700636206/gemini-mdj-1000-manual.pdf?ts=',
        'cachePath': 'TestBuilds/r481/upstream/mdj1000-original-manual.pdf',
        'sha256': '04a4cbb41e4df5b64909f143b3eb9f78a3dacbe94038ac23a8e0fb1ed6454995',
    }],
    'review': """Primary owner Joakim Mattson published Gemini MDJ-1000 midi programming for Mixxx DJ software in2017. Appendix1 records his own MIDI-OX captures, raw channels0..3, normal/Shift notes and values. The thesis is web-reviewed through its repository text; its PDF was not downloaded and no PDF hash or visual table proof is claimed. The separately cached original48-page manufacturer manual is hash-pinned; printed pages9..11 qualify held Cue, temporary bends, tempo direction, Hot Cue deletion and normal auto loops. Manual raw0 player A only, with separate audio. Load targets A rather than copying the owner's first-stopped-deck customisation. Temporary bends follow the physical held function rather than permanent rate-step customisation. The eight auto-loop lengths use native fixed loops in normal mode; Loop Roll/Slip remain inactive. Dedicated normal/Shift opcodes have paired negative aliases without an inferred app Shift button. No MDJ-900/500/600/V2/CDMP/GMX protocol is inherited. Relative jog/contact resolution, complete mode transitions, reverse/search/Track Search/Auto Cue/grid/FX/source/Link/eject, output/display/lifecycle/recovery and USB/channel/driver/OS/power/audio/DVS remain open. No unique USB identity or automatic channel assignment is established. No mapper, script, settings, query, reset, driver, firmware, installer or audio-route write executes. Physical/iPad/A10X acceptance remains open.""",
}}


def mdj1000_profiles():
    """Keep own raw0 documented roles separate from unknown motion, output and host contracts."""
    ref=MDJ1000_REFERENCES['Gemini MDJ-1000'];p=profile('Gemini MDJ-1000',ref['url'])
    p.update(definition='reviewed:original-mdj1000-owner-manual-player-core',autoSelect=False,role='player',
        aliases=['Gemini MDJ-1000','Gemini MDJ1000','MDJ-1000','MDJ1000'],
        excludedAliases=['MDJ-1000V2','MDJ-1000 V2','MDJ1000V2','MDJ-900','MDJ-500','MDJ-600','CDMP-7000','GMX'],
        hardwareMode='Manual original MDJ-1000 MIDI raw channel0, native target A. Use normal MIDI and Auto Loop modes with Loop Roll/Slip off. Configure audio separately. Other channels, automatic identity, jog, output and V2 remain unqualified.',
        scope='Manual58-input original player subset: transport, held Cue/bends, Sync/Keylock/Load, manual loops, four Hot Cues/clears, eight fixed-loop lengths, browse pulses, inverted tempo and filter. Dedicated alternate negative aliases rearm their own role. Full modes, motion, output/display and host/audio remain open.',
        gaps=[ref['review']])
    for action,n in [('play',2),('cuePreview',1),('loopIn',4),('loopOut',5),('reloop',6),('loopDown',7),('loopUp',8),('keylock',19),('load',9),('sync',52),('pitchBendDown',18),('pitchBendUp',17)]:
        add(p,action,0,n,deck='a')
    for slot in range(1,5):
        add(p,f'hotcue{slot}',0,37+slot,deck='a');add(p,f'clearHotcue{slot}',0,41+slot,deck='a')
    for action,n in [('browsePrevious',11),('browseNext',12)]:
        add(p,action,0,n);p['inputs'][-1]['pulse']=True
    add(p,'tempo',0,1,'control',deck='a');p['inputs'][-1]['inverted']=True
    add(p,'filterKnob',0,4,'control',deck='a')
    for n,length in [(34,2),(35,4),(36,8),(37,16),(30,0.125),(31,0.25),(32,0.5),(33,1)]:
        add(p,'fixedLoop',0,n,deck='a');p['inputs'][-1]['argument']=length
    positives=list(p['inputs'])
    for normal,alternate in [(4,7),(5,8),(6,47),(19,28),(9,49),(52,13),(18,24),(17,21)]+[(37+s,41+s) for s in range(1,5)]+[(34+s,30+s) for s in range(4)]:
        for number,negative in [(normal,alternate),(alternate,normal)]:
            binding=next((r for r in positives if r['kind']=='note' and r['number']==number),None)
            if binding is not None:p['inputs'].append({**binding,'number':negative,'releaseOnly':True})
    return [p]

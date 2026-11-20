"""Jockey 3 Remix facts from its own manufacturer manual."""
from curated import add, profile

JOCKEY_REMIX_SOURCE = 'https://www.reloop.com/media/catalog/product/pdf/2/2/5/225124_Reloop_IM.pdf'
JOCKEY_REMIX_REFERENCES = {'Reloop Jockey 3 Remix': {
    'url': JOCKEY_REMIX_SOURCE,
    'sha256': '3dbbbde197b64a792d25e8a81f2f1271da64541d23ebf255adecf093fb910326',
    'files': [{'cachePath': 'TestBuilds/r448/upstream/jockey3-remix-primary.pdf', 'sha256': '3dbbbde197b64a792d25e8a81f2f1271da64541d23ebf255adecf093fb910326'}],
    'relatedSources': [{'url': 'https://www.reloop.com/reloop-jockey-3-remix'}],
    'review': 'Own manufacturer manual function descriptions and MIDI chart jointly qualify factory MIDI channels1..4 for A/B/C/D. The chart names alternate printed legends: MASTER23 is normal Sync, KEYLOCK24 is normal CUP, FX MODE25 is normal Cue, TAP26 is normal Play and FADERSTART28 is normal monitoring Cue. Shifted Keylock87 is independently assigned. Normal CUP24 only rearms Keylock on release. Main Cue25 and bends41/42 retain shifted release aliases88/104/105. Four Hot Cues11..14 use shifted74..77 only as release guards; positive shifted clears stay inactive. Six continuous mixer controls per deck are gain121/high122/mid123/low124/level49/filter50. VR/Low denotes separate CC and NOTE, not a paired14bit control. Native assigns loop push43 to the current loop toggle, push44 to Reloop, and relative CC43 to loop size. Global channel0 CC53 browses tracks and shifted push116 opens the selected group. Cue mix54/crossfader55 are global channel0. Source selectors are all channel0: A/C/IN1 retire only A/C and B/D/IN2 only B/D. Sample/Remix selectors retire held state but do not implement or discover those modes. Thirty-two optional normal static lamps use127/0. Select this manual profile only in Track mode with Sample/Remix off and factory channel preset1..4. Jog calibration/current resolution, pitch polarity, other presets/channels, sampler/remix/roll/mash/FX, shifted clears, full source/mode/feedback/lifecycle/recovery, audio/USB/OS/power and physical/iPad/A10X acceptance remain open. Master/booth/phone level are analogue and have no MIDI signal. No setup, query, preset, firmware, driver or audio-route packet runs. Jockey 3 ME bytes are not inherited.'}}


def jockey3_remix_profiles():
    """Return the manual factory-channel Track core without hardware mode writes."""
    p = profile('Reloop Jockey 3 Remix', JOCKEY_REMIX_SOURCE)
    p.update(definition='reviewed:jockey3-remix-core', autoSelect=False, role='accessory',
        aliases=['Reloop Jockey 3 Remix', 'Jockey 3 Remix', 'Jockey3 Remix'],
        excludedAliases=['Reloop Jockey 3 ME', 'Jockey 3 Master Edition', 'Digital Jockey'],
        hardwareMode='Select this manual profile in Track mode with Sample/Remix off. Use factory MIDI channel preset1..4. C/D require app opt-in. Hardware source/audio ownership needs separate qualification. Jog, tempo, alternate modes and presets remain inactive.',
        scope='Manual144-input four-deck factory-channel Track core: transport, held Cue/bends, four Hot Cues per deck, mixer/PFL, loops/size, Load and browse. Thirty-two optional static lamps. Full modes, audio and physical acceptance remain open.',
        bankChanges=[{'channel': 0, 'number': n, 'anyPositive': True, 'decks': decks} for n, decks in [(59,list('ac')),(60,list('ac')),(58,list('ac')),(62,list('bd')),(63,list('bd')),(61,list('bd'))]] +
            [{'channel': ch, 'number': n, 'anyPositive': True, 'decks': [deck]} for ch, deck in enumerate('abcd') for n in [19,20]],
        gaps=[JOCKEY_REMIX_REFERENCES['Reloop Jockey 3 Remix']['review']])
    for ch, deck in enumerate('abcd'):
        for action, n, release in [('play',26,89),('cuePreview',25,88),('sync',23,86),('cue',28,91),('load',27,90),('pitchBendDown',41,104),('pitchBendUp',42,105),('keylock',87,24),('loop',43,106),('reloop',44,107)]:
            add(p, action, ch, n, deck=deck, feedback=action in ['play','cuePreview','sync','cue'])
            add(p, action, ch, release, deck=deck); p['inputs'][-1]['releaseOnly'] = True
        for slot in range(4):
            add(p, f'hotcue{slot+1}', ch, 11+slot, deck=deck, feedback=True)
            add(p, f'hotcue{slot+1}', ch, 74+slot, deck=deck); p['inputs'][-1]['releaseOnly'] = True
        for action, n in [('gain',121),('high',122),('mid',123),('low',124),('level',49),('filterKnob',50)]:
            add(p, action, ch, n, 'control', deck=deck)
        add(p, 'loopSize', ch, 43, 'control', 'binaryOffset', deck)
    add(p, 'crossfader', 0, 55, 'control')
    add(p, 'cueMix', 0, 54, 'control')
    add(p, 'browse', 0, 53, 'control', 'binaryOffset')
    add(p, 'openGroup', 0, 116)
    return [p]

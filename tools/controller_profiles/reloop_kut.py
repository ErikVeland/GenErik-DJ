"""Independent Reloop KUT continuous MIDI chart with explicit manual audio separation."""
from curated import add, profile

KUT_SOURCE = 'https://www.reloop.com/media/custom/upload/Reloop-236497_Reloop_IM.pdf'
KUT_REFERENCES = {'Reloop KUT': {
    'url': KUT_SOURCE, 'sha256': 'ae87d922ba873fd8f284cf575ab5ce131edf2b77a4f5aed7a84545c4492decb1',
    'files': [
        {'cachePath': 'TestBuilds/r444/upstream/reloop-kut-primary.pdf', 'sha256': 'ae87d922ba873fd8f284cf575ab5ce131edf2b77a4f5aed7a84545c4492decb1'},
        {'cachePath': 'TestBuilds/r444/upstream/reloop-kut-manual.pdf', 'sha256': 'ae87d922ba873fd8f284cf575ab5ce131edf2b77a4f5aed7a84545c4492decb1'}],
    'relatedSources': [
        {'url': 'https://www.reloop.com/reloop-kut'},
        {'url': 'https://s3.avecorp.com.au/wp-content/uploads/2018/01/30133455/Reloop-KUT-Manual.pdf'}],
    'review': 'Own manufacturer manual and distributor mirror are byte-identical. Visually reviewed English p7 MIDI chart explicitly gives Bn continuous0..127 controls. CH1 Gain/High/Mid/Low/Fader are CC01/02/03/04/05hex; CH2 CC07/08/09/0A/0Bhex; crossfader0D, Master10, headphone Level12/Mix13hex. Native14-input manual accessory accepts the documented n across MIDI channels1..16 without guessing a fixed factory channel. The narrow wildcard contract permits only unique absolute mixer CCs, manual accessory role and no button, mode, bank, protocol, setup, output or audio contract. Pickup and source boundaries remain native. Enable rear MIDI output separately. KUT hardware mixing remains active, so separate application audio and hardware routing must be qualified before combined use. Automatic selection/audio routing stays off. PFL Note01/03 edge/latch semantics, input-source switches, dynamic FX selection/parameters, mic/booth/curve controls, fader-start and full feedback/lifecycle/recovery remain inactive. Fader-start notes are not Play. The documented pickup-request SysEx is not sent because its complete effect/restoration is unqualified. No query, preset, driver, firmware or audio-route packet is sent. Full controller/audio/USB/OS/power and physical/iPad/A10X acceptance remain open. No RMX model is inherited.'}}


def kut_profiles():
    """Return manual continuous mixer inputs without fixed-channel or routing assumptions."""
    p = profile('Reloop KUT', KUT_SOURCE)
    p.update(definition='reviewed:reloop-kut-continuous', role='accessory', autoSelect=False,
        excludedAliases=['Reloop RMX-90 DVS', 'Reloop RMX-95', 'Reloop ELITE'],
        hardwareMode='Enable this manual MIDI accessory profile and the hardware MIDI switch separately. It maps continuous controls only. Hardware mixing stays active. Separate app audio and hardware routing need qualification before combined use. No PFL, FX, fader-start, light or audio setup is sent.',
        scope='Manual14-input continuous mixer subset on the documented Bn channel: gain/EQ/level A/B, crossfader, master, headphone level and cue blend. Full hardware/audio ownership, buttons, modes, feedback and lifecycle remain open.',
        gaps=[KUT_REFERENCES['Reloop KUT']['review']])
    for deck, offset in [('a', 0), ('b', 6)]:
        for n, action in enumerate(['gain', 'high', 'mid', 'low', 'level'], 1):
            add(p, action, 0, n + offset, 'control', deck=deck)
    for n, action in [(13, 'crossfader'), (16, 'master'), (18, 'monitor'), (19, 'cueMix')]:
        add(p, action, 0, n, 'control')
    for r in p['inputs']: r['anyChannel'] = True
    return [p]

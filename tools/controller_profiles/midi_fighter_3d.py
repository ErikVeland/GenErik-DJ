"""Maker-documented MIDI Fighter 3D banked notes and optional LED overrides."""
from curated import add, profile

MF3D_BASE = 'https://www.djtechtools.com/downloads/documents/Midi%20Fighter%203D%20MIDI%20Map%20'
MF3D_REFERENCES = {'DJ TechTools MIDI Fighter 3D': {
    'url': MF3D_BASE + 'ABLETON.pdf', 'sha256': 'd316f0685aaeb98e3f5ef204d284c68b6fbcf040e60b116d6791d3e0f182bdec',
    'files': [{'cachePath': 'TestBuilds/r437/upstream/mf3d-ableton.pdf', 'sha256': 'd316f0685aaeb98e3f5ef204d284c68b6fbcf040e60b116d6791d3e0f182bdec'}, {'cachePath': 'TestBuilds/r437/upstream/mf3d-traktor.pdf', 'sha256': 'dfe2ed5166596b2a8729047561f8d61653c3f473efd98d1eb8f59b28303a6d6a'}],
    'relatedSources': [{'url': MF3D_BASE + 'TRAKTOR.pdf', 'sha256': 'dfe2ed5166596b2a8729047561f8d61653c3f473efd98d1eb8f59b28303a6d6a'}, {'url': 'https://techtools.zendesk.com/hc/en-us/articles/7002414831629-Midi-Fighter-3D-App-Guide'}],
    'review': 'Separate maker Ableton and Traktor protocol documents independently specify banked arcade Notes36..99 on channel3, bank reports Notes0..3 on channel4 and the same LED override table. All64 numeric pad entries are checked against both own appendices; octave labels differ, so native uses explicit numeric notes. Four Banks is enabled by default; custom channels and disabled Hold/Toggle banks are separate modes. Native manual layout targets one bank per A/B/C/D deck. Bottom two rows supply eight Hot Cues, next row Play/held Cue/Sync/Load, top PFL/Loop In/Out/Reloop. C/D require app opt-in. Each positive bank report retires only its source and rearms its pads immediately. Late NoteOff/NoteOn-zero selector reports do not retire the new bank. Arcade releases retain their original addresses. Ableton channel6 duplicate CCs and channel4/5 rotation/tilt traffic stay inactive. Optional manual feedback provides52 static arcade overrides: green76, yellow80, red84 and black67. NoteOn0/NoteOff restores the configured default LED behaviour, so it is not used as a dark status value. Bank LED messages can force bank changes and are never emitted. Native sends no setup, bank selection, settings, utility, driver, firmware or audio route. Firmware-dependent names/defaults, side/motion controls, custom channels, disabled-bank modes, saved LED restoration, complete feedback/lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. Manual feedback needs separate destination selection and opt-in. No Spectra,64,Pro or Twister contract is inherited.'}}


def midi_fighter_3d_profiles():
    """Return the manual default-channel four-bank native pad layout."""
    p = profile('DJ TechTools MIDI Fighter 3D', MF3D_BASE + 'ABLETON.pdf')
    p.update(definition='manufacturer:midi-fighter-3d-banked-native', autoSelect=False, role='accessory',
        aliases=['DJ TechTools MIDI Fighter 3D', 'MIDI Fighter 3D', 'Midifighter3D'],
        excludedAliases=['MIDI Fighter Spectra', 'MIDI Fighter 64', 'MIDI Fighter Pro', 'MIDI Fighter Twister'],
        hardwareMode='Use default base channel3 with Four Banks enabled in Ableton or Traktor mode. Select this profile manually. Banks1/2/3/4 target A/B/C/D; enable C/D separately. Bottom two rows: eight Hot Cues. Next row: Play/Cue/Sync/Load. Top row: PFL/Loop In/Out/Reloop. Feedback requires separate manual opt-in. Deactivate before changing channel or bank mode.',
        scope='Manual64-input banked native layout, immediate source-owned bank-selector cleanup and52 optional static arcade lamps. Motion, custom channels, disabled banks and full lifecycle remain open.',
        bankChanges=[{'channel': 3, 'number': n, 'anyPositive': True, 'decks': list('abcd')} for n in range(4)], gaps=[MF3D_REFERENCES['DJ TechTools MIDI Fighter 3D']['review']])
    for bank, deck in enumerate('abcd'):
        base = 36 + 16 * bank
        for slot in range(8):
            add(p, f'hotcue{slot + 1}', 2, base + slot, deck=deck, feedback=True)
        for action, offset, feedback in [('play', 8, True), ('cuePreview', 9, True), ('sync', 10, True), ('load', 11, False), ('cue', 12, True), ('loopIn', 13, False), ('loopOut', 14, False), ('reloop', 15, False)]:
            add(p, action, 2, base + offset, deck=deck, feedback=feedback)
        p['outputs'].append({'action': 'loop' + ('A' if deck in 'ac' else 'B'), 'kind': 'note', 'channel': 2, 'number': base + 15, 'onValue': 76, 'offValue': 67, 'offUsesNoteOn': True, 'targetDeck': deck})
    for lamp in p['outputs']:
        lamp.update(onValue=84 if lamp['action'].startswith('cuePreview') else 80 if lamp['action'].startswith(('sync', 'hotcue')) else 76, offValue=67)
    return [p]

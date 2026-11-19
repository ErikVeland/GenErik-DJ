"""Independent APC64 Session-mode facts from Bitwig's primary integration source."""
from curated import add, profile
from native_dj_grid import add_native_dj_grid

APC64_BASE = 'https://raw.githubusercontent.com/bitwig/bitwig-extensions/35a3bc35f6e69da01137d1923f4c9f3636b21336/src/main/java/com/bitwig/extensions/controllers/akai/'
APC64_MEMBERS = [
    ('apc64/Apc64MidiProcessor.java', 'cbb44dae3a61dbc78276ad064b659808d44e917fa05518fd91b5d64a5b6b8616'),
    ('apc64/Apc64ExtensionDefinition.java', '7adfb03c338c5a78ab23292748a8bc408aea1e79178f432c713ec5d5041aaf7e'),
    ('apc64/HardwareElements.java', 'df4ec5815d1393e4855d45f54d1c8620e7b4c5e9c3b4e955a9f2298c578c12d5'),
    ('apc64/Apc64CcAssignments.java', '441b80ed54e0b7bf56e9627c362bb2e0482f9686c9520c5cbf52b842171f1a65'),
    ('apc64/PadMode.java', 'd17291e98c91aecc43e636cf0f92503c581b7464e25b2c39a14f7425fa79f473'),
    ('apc64/control/TouchSlider.java', 'f7b553bdd228b9efa382e3da019de7f619e4480ed2167b9f647693811d01af54'),
    ('apc/common/control/ApcButton.java', '7cd079cb2f0dbace0b374fa4bbb66b540409994598de9a953f76c449786c08c8'),
    ('apc/common/control/RgbButton.java', '70ad076c0428a1b454289cd838aa2fadb9b10dbf67b4066ecf5cb0800885cd11'),
    ('apc/common/led/RgbLightState.java', '3d5cb14c7a86ca4d9daba4053ed4cc9de2f464c7f50734f1c700ede4e920635c'),
    ('apc/common/led/LedBehavior.java', 'ecea25c0161012f727f67ea99b74140964666b02db84d7f7fa4204c794813853')]
APC64_REFERENCES = {'Akai APC64': {
    'url': APC64_BASE + APC64_MEMBERS[0][0], 'sha256': APC64_MEMBERS[0][1],
    'files': [{'cachePath': 'TestBuilds/r439/upstream/' + path.rsplit('/', 1)[-1], 'sha256': sha} for path, sha in APC64_MEMBERS],
    'relatedSources': [{'url': APC64_BASE + path, 'sha256': sha} for path, sha in APC64_MEMBERS[1:]],
    'review': 'Pinned Bitwig primary integration independently qualifies APC64 DAW/Notes port separation, Session mode0, own identity response family53/member1901, pad Notes0..63 on raw channel6, eight14-bit Pitch Bend strips on raw channels0..7 and ShiftNote120/channel0. Native accepts only the confirmed own device after the source normal-routing and Session setup plus identity request. DAW enable is sent only after own identity; readiness confirms local send success, not an undocumented acknowledgement. Other reported modes immediately retire only that source, block its pads/strips/feedback and request DAW exit. Returning to Session requires another successful local DAW-enable send. Fragmented/bounded SysEx and real-time bytes are handled separately from MIDI actions. Native uses the existing64-pad four-quadrant layout, A/B below and opt-in C/D above. Eight strips set levels A-D and filters A-D with pickup. Shift retires its source and guards all normal controls. Own static palette channel6 supports52 lamps with red5/yellow13/green21/off0. Shutdown clears those52 lamps and requests DAW exit; the exit is also attempted after any failed shutdown lamp or exit send. Partial startup abort requests exit. No initial-state guarantee, previous mode/LED restoration or persistence guarantee for source routing flag1B is claimed. Other modes, strip touch/position/colour feedback, outer controls, OLED text, sequencer/CV/DIN, complete lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. No Bitwig code, preset dump, global-settings dump, driver, firmware or audio route executes. Original APC mini/MK2/APC20/APC40 contracts remain separate.'}}


def apc64_profiles():
    """Return the paired, identity-gated Session grid and eight pickup strips."""
    p = profile('Akai APC64', APC64_BASE + APC64_MEMBERS[0][0])
    p.update(definition='reviewed:apc64-session-native', role='accessory', inputProtocol='apc64',
        aliases=['Akai APC64', 'APC64'], portAliases=['APC64 DAW (APC64)', 'APC64'],
        excludedAliases=['APC64 Notes (APC64)', 'MIDIIN2 (APC64)', 'APC MINI', 'APC mini mk2', 'APC20', 'APC40'],
        hardwareMode='Use the APC64 DAW port and close other controller software. Native selects normal routing and Session mode, checks device identity, then enables DAW control. Other modes suspend controls. Select Session to resume. A/B below, C/D above with app opt-in. Strips1-4: levels A-D;5-8: filters A-D. Move strips to app values for pickup. Previous device mode/settings are not restored.',
        scope='Automatic73-input identity/Session-gated accessory:64 grid pads, eight14-bit strips and Shift;52 static grid lamps. Other modes/screens/full lifecycle remain open.',
        startup=[[240, 71, 0, 83, 27, 0, 1, 0, 247], [240, 71, 0, 83, 25, 0, 1, 0, 247], [240, 126, 127, 6, 1, 247]],
        startupAbort=[[240, 71, 0, 83, 28, 0, 1, 0, 247]],
        bankChanges=[{'channel': 0, 'number': 120, 'anyPositive': True, 'decks': list('abcd'), 'releaseShiftChannels': []}], gaps=[APC64_REFERENCES['Akai APC64']['review']])
    add_native_dj_grid(p, [[8 * y + x for x in range(8)] for y in range(8)], output_channel=6)
    for row in p['inputs']: row['channel'] = 6
    for column, deck in enumerate('abcd'):
        add(p, 'level', column, 0, 'pitch', deck=deck)
        add(p, 'filterKnob', column + 4, 0, 'pitch', deck=deck)
    for row in p['inputs']: row['shifted'] = False
    add(p, 'shift', 0, 120)
    for lamp in p['outputs']:
        lamp.update(onValue=5 if lamp['action'].startswith('cuePreview') else 13 if lamp['action'].startswith(('sync', 'hotcue')) else 21)
    p['shutdown'] = [[150, lamp['number'], 0] for lamp in p['outputs']] + [[240, 71, 0, 83, 28, 0, 1, 0, 247]]
    return [p]

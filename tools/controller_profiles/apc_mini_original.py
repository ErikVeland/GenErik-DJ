"""Original APC mini hardware-owner facts and the existing native DJ grid."""
from curated import add, profile
from native_dj_grid import add_native_dj_grid

APC_MINI_ORIGINAL_BASE = 'https://raw.githubusercontent.com/TomasHubelbauer/akai-apc-mini/9f72aef49d663959a6033dcef67ca3784a40f672/'
APC_MINI_ORIGINAL_GUIDE = 'https://cdn.inmusicbrands.com/akai/apc-mini/APC%20mini%20-%20User%20Guide%20-%20v1.0.pdf_079659375431bb679d17071da25ad6af.pdf'
APC_MINI_ORIGINAL_REFERENCES = {'Akai APC MINI': {
    'url': APC_MINI_ORIGINAL_BASE + 'README.md', 'sha256': 'bc3a8b786e82f999d9b2a395fefb6be7e473c23713b6f3728925fb97a84df475',
    'files': [{'cachePath': 'TestBuilds/r438/upstream/apc-mini-README.md', 'sha256': 'bc3a8b786e82f999d9b2a395fefb6be7e473c23713b6f3728925fb97a84df475'}, {'cachePath': 'TestBuilds/r438/upstream/apc-mini-apc_mini_midi.jpg', 'sha256': '50c9ce9e28fd8b6a1796a00118ea33bc1c462fb6f34f93f972db8cc8d72f8c4c'}, {'cachePath': 'TestBuilds/r438/upstream/apc-mini-akai.csv', 'sha256': '93e17ae962310e4994d3fe30f853f0d130f971f04b791c4f7df3099b4aeb707f'}, {'cachePath': 'TestBuilds/r438/upstream/apc-mini-guide.pdf', 'sha256': 'ca3eb68e6dceec0956af8155cc335d7398b8ed0ad89ab04a21b9750aa9cb5165'}],
    'relatedSources': [{'url': APC_MINI_ORIGINAL_BASE + 'apc_mini_midi.jpg'}, {'url': APC_MINI_ORIGINAL_BASE + 'akai.csv'}, {'url': APC_MINI_ORIGINAL_GUIDE}],
    'review': 'Pinned hardware-owner capture/table and separately credited protocol diagram qualify original APC MINI channel1 grid Notes0..63, bottom row0..7/top56..63, nine full-range CC faders48..56 and ShiftNote98. NoteOn127 presses and NoteOff127 releases are explicit; native also preserves NoteOn-zero releases. Own USB property capture identifies APC MINI. Native uses its existing64-pad four-quadrant DJ layout, A/B below and opt-in C/D above. Faders1..4 set levels A-D,5..8 filters A-D and9 master, each with pickup. Native adds a global Shift guard: all normal pads/faders stay inactive during Shift; both Shift edges retire only that source and rearm its controls/pickup. Other outer buttons remain inactive. Own diagram qualifies52 static grid status lamps using green1/red3/yellow5/off0. No MK2 RGB channel/palette/setup is inherited. Native sends no startup/identity/fader-confirmation/preset/firmware/settings/audio packets. Paired shutdown attempts NoteOn0 for all64 grid lamps, without outer LEDs or an application reset. Complete outer controls, Shift functions, advanced light modes, startup state, lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. Hardware-owner speculation about USB driver types is not used as a protocol fact.'}}


def apc_mini_original_profiles():
    """Return the independent original Mini grid, nine pickup faders and Shift guard."""
    p = profile('Akai APC MINI', APC_MINI_ORIGINAL_BASE + 'README.md')
    p.update(definition='reviewed:apc-mini-original-native', role='accessory',
        aliases=['Akai APC MINI', 'APC MINI'], excludedAliases=['APC mini mk2', 'APC mini MK 2 (Control)', 'APC KEY 25', 'APC40'],
        hardwareMode='Original APC mini USB MIDI. Native four-quadrant grid: A/B below and C/D above with app opt-in. Faders1-4: levels A-D;5-8: filters A-D;9: master. Move faders to current app values for pickup. Shift retires held controls and blocks normal actions; release it to resume.',
        scope='Automatic74-input original Mini accessory:64 grid pads, nine faders and a global Shift guard;52 static grid lamps. Other outer controls and complete lifecycle remain open.',
        bankChanges=[{'channel': 0, 'number': 98, 'anyPositive': True, 'decks': list('abcd'), 'releaseShiftChannels': []}],
        shutdown=[[144, n, 0] for n in range(64)], gaps=[APC_MINI_ORIGINAL_REFERENCES['Akai APC MINI']['review']])
    add_native_dj_grid(p, [[8 * y + x for x in range(8)] for y in range(8)])
    for column, deck in enumerate('abcd'):
        add(p, 'level', 0, 48 + column, 'control', deck=deck)
        add(p, 'filterKnob', 0, 52 + column, 'control', deck=deck)
    add(p, 'master', 0, 56, 'control')
    for r in p['inputs']: r['shifted'] = False
    add(p, 'shift', 0, 98)
    for lamp in p['outputs']:
        lamp.update(onValue=3 if lamp['action'].startswith('cuePreview') else 5 if lamp['action'].startswith(('sync', 'hotcue')) else 1)
    return [p]

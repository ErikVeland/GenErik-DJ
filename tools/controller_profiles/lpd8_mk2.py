"""Independent LPD8 MK2 published Program1 facts and native accessory layout."""
from curated import add, profile

LPD8_MK2_SOURCE = 'https://virtualdj.com/manuals/hardware/akai/lpd8mk2/advanced.html'
LPD8_MK2_REFERENCES = {'Akai LPD8 MK2': {
    'url': LPD8_MK2_SOURCE,
    'files': [
        {'cachePath': 'TestBuilds/r432/upstream/lpd8-program-editor.png', 'sha256': '43af45c4ea4f31b13632dd0e97b8175a0d7dc02882472e1f3a0205d577455e90'},
        {'cachePath': 'TestBuilds/r432/upstream/lpd8-vdj-programs.zip', 'sha256': 'd23bce6e19621b173fc08908e920f2727b43565268bf9bd870f648355b7c1683'},
        {'cachePath': 'TestBuilds/r432/upstream/lpd8-vdj/PROG1_VDJ.lpd8mk2', 'sha256': '2d9c78099a28249af30798ab43610c7ca0cd3fb66292805ba4aa0ba33000315a'},
        {'cachePath': 'TestBuilds/r434/upstream/lpd8-guide.pdf', 'sha256': 'dc4eee2c9294b75886e5b3eb47a3b1d703dcd1a978848fce16e87faf42424b81'}],
    'relatedSources': [{'url': 'https://virtualdj.com/img/372700/76537/ProgramEditor.png'}, {'url': 'https://virtualdj.com/documents/LPD8_MK2_Programs.zip'}, {'url': 'https://cdn.inmusicbrands.com/akai/LPD8/LPD8%20mk2%20-%20User%20Guide%20-%20v1.2.pdf'}],
    'review': 'The publisher Program1 editor image independently specifies momentary pads, Notes36..43 and knobsCC36..43, all channel1. Knobs span0..127. Bottom pad row is36..39; top row40..43. Top knobsK1..4 areCC36..39; bottomK5..8 areCC40..43. Native assigns bottom pads four Hot Cues A, top pads four Hot Cues B; top knobs gain/high/mid/low A and bottom knobs the same B. This is an explicit native layout, not the source software effect actions. Select the published VDJ Program1 in NOTE mode and apply this profile manually. Native does not load or send the preset. The guide confirms programmable assignments and four stored programs. Factory defaults have not been independently qualified. Other programs, CC/Program Change modes, pressure, RGB feedback, complete mode/preset/lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. Mode/program buttons do not supply a qualified observable transition. In the published preset pad CCs overlap knob CCs: CC-mode pads cannot be distinguished from knobs. Do not change mode/program while this profile is active. No setup, stored preset, colour, global setting, driver, firmware or audio route is written. Original LPD8 and LPD8 Wireless contracts stay separate.'}}


def lpd8_mk2_profiles():
    """Return the manual NOTE-mode accessory subset for the published Program1."""
    p = profile('Akai LPD8 MK2', LPD8_MK2_SOURCE)
    p.update(definition='reviewed:lpd8-mk2-vdj-program1', autoSelect=False, role='accessory',
        aliases=['Akai LPD8 MK2', 'LPD8 MK2', 'LPD8 mkII'], excludedAliases=['LPD8 Wireless'],
        hardwareMode='Use the published VDJ Program1 assignments in NOTE mode, then select this profile manually. Bottom pads: Hot Cues1-4 A. Top pads: Hot Cues1-4 B. Top knobs: gain/high/mid/low A. Bottom knobs: gain/high/mid/low B. Move knobs to current app values for pickup. Deactivate this profile before changing mode or program. Configure app audio separately.',
        scope='Manual16-input published-preset accessory layout. Factory defaults, other programs/modes, RGB feedback and complete lifecycle remain open.', gaps=[LPD8_MK2_REFERENCES['Akai LPD8 MK2']['review']])
    for deck, base in [('a', 36), ('b', 40)]:
        for slot in range(4): add(p, f'hotcue{slot + 1}', 0, base + slot, deck=deck)
        for offset, action in enumerate(['gain', 'high', 'mid', 'low']): add(p, action, 0, base + offset, 'control', deck=deck)
    return [p]

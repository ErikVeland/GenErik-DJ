"""Independent Mixars QUATTRO performance facts from a public hardware-owner export."""
from curated import add, profile

QUATTRO_DOWNLOAD = 'https://www.mediafire.com/file/dqqm12ter942giu/Mixars_Quattro-nr1.5.djayMidiMapping.zip/file'
MIXARS_QUATTRO_REFERENCES = {'Mixars QUATTRO': {
    'url': QUATTRO_DOWNLOAD, 'sha256': '0f6e75b0fd95e5906a4be30a501ad804cba2df0948fd72f334eda36b5d04a8ef',
    'files': [
        {'cachePath': 'TestBuilds/r442/upstream/quattro-owner.zip', 'sha256': '0f6e75b0fd95e5906a4be30a501ad804cba2df0948fd72f334eda36b5d04a8ef'},
        {'cachePath': 'TestBuilds/r442/upstream/quattro-owner.djayMidiMapping', 'sha256': '884afff200789fca49635d07af6c3222dff0683c866a64d2afd5f930d9a990e6'},
        {'cachePath': 'TestBuilds/r442/upstream/quattro-manual.pdf', 'sha256': '01a88a07bda75505ce610babf578cdfbcc2a26aa3f3eaef2788deda56630846f'}],
    'relatedSources': [
        {'url': 'https://community.algoriddim.com/t/midi-mapping-for-mixars-quattro-anyone-interested/15739'},
        {'url': 'https://www.mixars.com/wp-content/uploads/2017/01/quattro-manual-multi-language_102317rev.2.pdf'},
        {'url': 'https://mixars.com/product/quattro/'}],
    'review': 'Independent nice-record hardware-owner export,229 rows, djay Pro AI-3.1.9, endpoint Mixars Quattro. The original XML is retained unchanged. Four lineVolume rows have dangling output keys, so the full file is not a valid property list. Review removes only those four absent-output markers in a temporary test tree to read existing numeric input facts; no replacement output or executable source runs. Own manufacturer manual confirms deck selection3/1 and2/4, CUES/Shift+Transport and Sampler/User modes, two physical Shift buttons and non-Serato external hardware mixing. Native manual accessory implements32 Hot Cues on channels4..7/Notes96,100,97,101,98,102,99,103; Transport-mode Play27 and loop half25/double24; fixed-four-beat loop push64; global15 Load2..5; own Sync2 on0/1; and flipped rotary64 BrowseCC0/global15. Source numbered cuePositionOrJumpConsideringPlayState1/Note26 is not held main Cue and remains inactive. Four Shift reports0..3/Note32 compose the two physical contacts with fixed side keys; all normal inputs are guarded. Defensive release-only aliases across A/C and B/D rearm buttons without activating the other deck. No deck-selector wire is inferred. Native does not translate source hardware mixer/PFL/faders or dual14-bit fader reports into software mixing. Manufacturer non-Serato mode requires separate deck audio outputs, which remain unimplemented. Reported source import, pad-light and headphone issues do not establish working feedback or audio. Automatic selection, all other modes, feedback, cold routing discovery, full lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. No map import, output, setup, preset, driver, firmware or audio-route packet runs. DUO, PRIMO and Reloop Quattro remain separate.'}}


def mixars_quattro_profiles():
    """Return a manual four-target performance subset without external mixer ownership."""
    p = profile('Mixars QUATTRO', QUATTRO_DOWNLOAD)
    p.update(definition='reviewed:mixars-quattro-owner', role='accessory', autoSelect=False,
        aliases=['Mixars QUATTRO'], excludedAliases=['Reloop Quattro', 'Mixars DUO', 'Mixars PRIMO'],
        hardwareMode='Enable this manual MIDI accessory profile separately. Select non-Serato routing on the hardware. CUES provides eight Hot Cues; Shift+CUES selects Transport for Play and loop sizing. C/D require app opt-in. External deck audio routing and hardware mixer controls are not configured.',
        scope='Manual109-input-row performance subset with32 Hot Cues, Transport-mode Play/loop sizing, four-beat loop push, fixed Load, A/B Sync, flipped browsing and composed Shift. Includes48 bank-release aliases and two shifted Sync releases. No main Cue, mixer/PFL, output or audio setup.',
        bankChanges=[{'channel': ch, 'number': 32, 'anyPositive': True, 'decks': list('abcd'), 'releaseShiftChannels': []} for ch in range(4)],
        gaps=[MIXARS_QUATTRO_REFERENCES['Mixars QUATTRO']['review']])
    for index, deck in enumerate('abcd'):
        ch = 4 + index
        for action, n, argument in [('play', 27, None), ('toggleFixedLoop', 64, 4), ('loopDown', 25, None), ('loopUp', 24, None)] + [(f'hotcue{s + 1}', n, None) for s, n in enumerate([96, 100, 97, 101, 98, 102, 99, 103])]:
            add(p, action, ch, n, deck=deck)
            if argument is not None: p['inputs'][-1]['argument'] = argument
            add(p, action, ch ^ 2, n, deck=deck); p['inputs'][-1]['releaseOnly'] = True
            if argument is not None: p['inputs'][-1]['argument'] = argument
        add(p, 'load', 15, 2 + index, deck=deck)
        if index < 2:
            add(p, 'sync', index, 2, deck=deck)
            add(p, 'sync', index, 3, deck=deck); p['inputs'][-1]['releaseOnly'] = True
    add(p, 'browse', 15, 0, 'control', 'binaryOffset'); p['inputs'][-1]['inverted'] = True
    for row in p['inputs']: row['shifted'] = False
    for ch in range(4):
        add(p, 'shift', ch, 32); p['inputs'][-1]['shiftInput'] = ch % 2
    return [p]

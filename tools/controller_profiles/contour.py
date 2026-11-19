"""Independently checked Contour CE/IE default-channel MIDI facts."""
from curated import add, profile
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA

CONTOUR_REFERENCES = {'Reloop CONTOUR': {
    'url': 'https://www.reloop.com/media/catalog/product/pdf/2/2/3/223397_Reloop_IM.pdf',
    'sha256': '9a0c35e02ceb00fe232e9049114301378ab92aaba1c7f21b1c0600c7dab336d5',
    'files': [
        {'edition': 'Controller Edition', 'url': 'https://www.reloop.com/media/catalog/product/pdf/2/2/3/223397_Reloop_IM.pdf', 'cachePath': 'TestBuilds/r423/upstream/contour-ce.pdf', 'sha256': '9a0c35e02ceb00fe232e9049114301378ab92aaba1c7f21b1c0600c7dab336d5', 'reviewedPages': [14, 15, 16]},
        {'edition': 'Interface Edition', 'url': 'https://www.reloop.com/media/catalog/product/pdf/2/2/3/223396_Reloop_IM.pdf', 'cachePath': 'TestBuilds/r423/upstream/contour-ie.pdf', 'sha256': '7c107a78d1d046414fc7cec312c3dbe697e11b6c49cbf29a7ec5de681e38847a', 'reviewedPages': [38, 39, 40]}],
    'relatedSources': [{'url': 'https://www.reloop.com/reloop-contour-controller-edition'}, {'url': 'https://www.reloop.com/reloop-contour-interface-edition'}, {'url': FOUR_SOURCE, 'sha256': FOUR_PACKAGE_SHA, 'archiveMember': 'Applications/DEX4.app/Contents/Resources/controllers/Reloop__Contour_CE_IE.js', 'memberSHA256': '33d9ad6cff1b57b0933a85e1a9337675b2af7ac8428d4ca7bee2184c698f3ad5', 'review': 'Read-only corroboration of channel0..3 targets and source scratch scale150. Primary charts override copied software-role assumptions.'}],
    'review': 'Separate manufacturer charts independently qualify the same default-channel input and lamp addresses for both editions. Native channels0..3 target A/B/C/D. Normal notes use Shift +64 release-only aliases; alternate positive commands remain inactive. Play39/Cue38/Sync40, eight independently addressed Hot Cues, Load9, native beat jumps20/21, Loop18/Reloop19, binary-offset loop-size22/browser9 and filter45 are explicit native controls. Normal47 and Scratch48 wheel/contact families use owned touch and source scale150; primary reports raw40±N. Other wheel modes, no-touch direction notes, modified positive commands and physical scale remain unqualified. Deck-selection notes5..8 retire owned holds across all targets; normal wheel-mode32..35 reports retire only their deck, and releases preserve fresh contacts. Note8 is a shifted deck selector, never Key Lock; there is no pitch slider or primary pitch-bend input. Shifted filter/pan CC109/110 are not treated as headphone/master knobs. No source software, startup, channel changer, stored setting or audio command runs.'}}


def contour_profiles():
    """Map the independently reviewed shared wire core, retaining both editions."""
    ref = CONTOUR_REFERENCES['Reloop CONTOUR']; p = profile('Reloop CONTOUR', ref['url'])
    p.update(definition='manufacturer:reloop-contour-native',
        aliases=['Reloop CONTOUR', 'CONTOUR', 'Reloop Contour CE', 'Reloop Contour IE', 'Reloop Contour Controller Edition', 'Reloop Contour Interface Edition'],
        excludedAliases=['Reloop Digital Jockey', 'Reloop Jockey 3', 'Reloop RMP-4'],
        hardwareMode='Default four-channel group: MIDI1..4 target A/B/C/D. Enable C/D separately. Normal and Scratch wheel modes use fixed native contact. Configure app audio separately; Controller Edition has no audio interface.',
        scope='Automatic default-group transport, eight Hot Cues per deck, manual loop toggle/reloop, native beat jumps, library/loop encoders, filter and fixed touch/jog. Both editions retain separate catalogue rows.',
        gaps=[ref['review'], 'Custom channel groups, all Shift functions, CUP/save/delete, other wheel modes, FX/pan/EQ alternatives, rings/alternate lamp banks, complete state/lifecycle/audio/USB/OS and physical/iPad/A10X acceptance remain open.'])
    for ch, deck in enumerate('abcd'):
        buttons = [('play', 39), ('cuePreview', 38), ('sync', 40), ('load', 9), ('loop', 18), ('reloop', 19), ('jumpBack', 20), ('jumpForward', 21)]
        buttons += [(f'hotcue{i+1}', n) for i, n in enumerate([26, 27, 28, 29, 52, 53, 54, 55])]
        for action, number in buttons + [('jogTouch', 47), ('jogTouch', 48)]:
            add(p, action, ch, number, deck=deck, feedback=action in ['play', 'cuePreview', 'sync', 'loop'] or action.startswith('hotcue'))
            p['inputs'].append(dict(p['inputs'][-1], number=number+64, releaseOnly=True))
        for number in [47, 48]:
            add(p, 'jog', ch, number, 'control', 'binaryOffset', deck); p['inputs'][-1].update(argument=150, requiresTouch=True)
        add(p, 'filterKnob', ch, 45, 'control', deck=deck)
        add(p, 'loopSize', ch, 22, 'control', 'binaryOffset', deck)
        add(p, 'browse', ch, 9, 'control', 'binaryOffset')
        for number in [5, 6, 7, 8]: p.setdefault('bankChanges', []).append({'channel': ch, 'number': number, 'anyPositive': True, 'decks': list('abcd')})
        for number in [32, 33, 34, 35]: p['bankChanges'].append({'channel': ch, 'number': number, 'anyPositive': True, 'decks': [deck]})
    return [p]

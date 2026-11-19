"""Separate manufacturer MPD226/232 Bitwig input facts and native four-deck assignments."""
from curated import add, profile

MPD2_ARCHIVE_SHA = '8a927aa10cb07a2b5ce370fb0cf04c22462b92ebe283b9c3bd59eca0bfd74195'
MPD2_CACHE = 'TestBuilds/r432/upstream/mpd-bitwig/MPD2 Series v1.0.2/'
MPD2_REFERENCES = {}
for model, suffix, member_sha, guide_sha in [
    (226, 'a45537bcc8619b374fa020c5acb2d879', 'd591c87df42bf10e189927fe830c8aaa66b09f824060ca0cd69f7db2a75ae3a1', 'f49bd77f896f7f52105f6897ea805156745e7251496b7e69f9949acbe4721962'),
    (232, '2d5b4cb748f1b0cc256d5197f95cb66e', '3adfcc79065a5d25e91045ed45a5dccb61b1604d3d51516d6281904987d7c76a', '4ba19eedb423beacbaf018cd0b7ce6a2f05cf4c7210f702b001b1e9ea07f0d10')]:
    MPD2_REFERENCES[f'Akai MPD{model}'] = {
        'url': f'https://cdn.inmusicbrands.com/akai/MPD{model}/MPD2Seriesv1.0.2.zip_{suffix}.zip', 'sha256': MPD2_ARCHIVE_SHA,
        'files': [{'cachePath': f'TestBuilds/r432/upstream/mpd{model}-bitwig.zip', 'sha256': MPD2_ARCHIVE_SHA}, {'cachePath': MPD2_CACHE + f'MPD{model}.control.js', 'sha256': member_sha}, {'cachePath': MPD2_CACHE + 'MPD2_common.js', 'sha256': 'dcf7d9eb3faa0aa4e2cc6907eb2bbb5a3429f72c50fa05de89f5fb22660ca10c'}, {'cachePath': MPD2_CACHE + 'MPD2_PadInstrument.js', 'sha256': '6217f1370252cc06914a914a82454553fb6a7651e0556ad2865e17a43c3cf137'}, {'cachePath': MPD2_CACHE + 'MPD2 Series, MPK2 Series - Bitwig Studio Program Documentation - v1.0.pdf', 'sha256': '329ca379a22ac3c992fd7f48890e353805d683165c4a1a1f9f95c5b1265921c0'}, {'cachePath': f'TestBuilds/r433/upstream/mpd{model}-guide.pdf', 'sha256': guide_sha}],
        'relatedSources': [{'url': f'https://www.akaipro.com/downloads-and-support/downloads/?product=MPD{model}'}, {'url': f'https://cdn.inmusicbrands.com/akai/attachments/MPD{model}/MPD{model}-User_Guide-v1.1.pdf'}],
        'review': f'Own manufacturer product download includes the separate MPD{model} member and a documented shared input contract. Select the onboard Bitwig preset and use main Port A, not Remote/MIDI4. Pad Instrument handles channel10 Notes36..99, four16-pad banks. Shared control banks use channels2/3/4; first four switchesCC30..33, faders40..43 absolute0..127 and knobs50..53 signed increments. Native accepts only strict1/127 knob steps. Native assigns one pad bank per A/B/C/D deck. Four switches per control bank set native PFL/Sync/Key Lock; faders set level/high/low; knobs adjust gain/mid/filter. Pad and control banks stay independent. Pad changes retire only that source. Control changes rearm CC buttons and reacquire pickup on the new control bank without releasing held pad Cue. Late releases do not change contexts. Manual selection is required. ' +
            ('All four physical control columns are covered in this subset. ' if model == 226 else 'Only the first four of the eight physical control columns are active. The extra four columns stay inactive. ') +
            'Other presets, full relative magnitudes/calibration, dedicated transport, navigation, pressure/repeat, Remote display/colour-parameter writes, complete bank/preset/lifecycle/recovery/USB/OS/power and physical/iPad/A10X acceptance remain open. A standalone bank-selector report is not implemented; cleanup occurs at the next mapped report or original release. No source program/action, preset, global setting, tempo, firmware, driver, colour write or audio route executes. MPD218 and MPK contracts stay separate.'}


def mpd2_bitwig_profiles():
    """Return independent manual four-deck cores for the explicit Bitwig hardware preset."""
    result = []
    for model in [226, 232]:
        name = f'Akai MPD{model}'; ref = MPD2_REFERENCES[name]
        p = profile(name, ref['url'])
        p.update(definition=f'reviewed:mpd2-bitwig-{model}', autoSelect=False, role='accessory', inputProtocol='mpd2Bitwig',
            aliases=[name, f'MPD{model}', f'MPD{model} Port A', f'MPD{model} MIDI 1'],
            excludedAliases=[f'MPD{model} Remote', f'MPD{model} Port B', f'MPD{model} MIDI 4', f'MIDIIN4 (MPD{model})', 'MPD218', 'MPK225'],
            hardwareMode='Select the onboard Bitwig preset, then this model manually on main Port A. Enable C/D separately. Pad banks A-D target app A-D. Control banks A/B/C: switches PFL/Sync/Key Lock, faders level/high/low, knobs gain/mid/filter. Only the first four control columns are active. Keep Note Repeat off. Configure app audio separately.',
            scope='Manual100-input native four-deck core:64 pads plus36 controls across independent pad/control banks. Strict knob steps, source-owned cleanup and new-bank pickup only. Full presets/Remote/feedback remain open.', gaps=[ref['review']])
        for bank, deck in enumerate('abcd'):
            base = 36 + 16 * bank
            for slot in range(8): add(p, f'hotcue{slot + 1}', 9, base + slot, deck=deck)
            for action, offset in [('play', 8), ('cuePreview', 9), ('sync', 10), ('load', 11), ('loopIn', 12), ('loopOut', 13), ('reloop', 14), ('keylock', 15)]: add(p, action, 9, base + offset, deck=deck)
        for channel, button, fader, knob in [(1, 'cue', 'level', 'gain'), (2, 'sync', 'high', 'mid'), (3, 'keylock', 'low', 'filterKnob')]:
            for column, deck in enumerate('abcd'):
                add(p, button, channel, 30 + column, 'control', deck=deck)
                add(p, fader, channel, 40 + column, 'control', deck=deck)
                add(p, knob, channel, 50 + column, 'control', 'signedStep', deck)
        result.append(p)
    return result

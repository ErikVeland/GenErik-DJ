"""Independent Vestax VCI-380 manufacturer MIDI table and guarded native subset."""
from curated import add, profile

VCI380_SOURCE = 'https://www.bhphotovideo.com/lit_files/90259.pdf'
VCI380_REFERENCES = {'Vestax VCI-380': {
    'url': VCI380_SOURCE,
    'sha256': '24e403567edaebd28c0e2eb125844d30992b271618b29858df07dfd9a2cefde2',
    'files': [
        {'cachePath': 'TestBuilds/r441/upstream/vci380-midi-public-text.txt', 'sha256': '24e403567edaebd28c0e2eb125844d30992b271618b29858df07dfd9a2cefde2'},
        {'cachePath': 'TestBuilds/r441/upstream/vci380-owner-guide.pdf', 'sha256': '2ac49c1753474110cc4912f2fe2f7bab34f1b609b7a03112637d23e34b560d66'}],
    'relatedSources': [
        {'url': 'https://manualzz.com/doc/6742086/vestax-vci-380-dj-controller-owner-s-manual'},
        {'url': 'https://g-zi.de/Traktor/Vestax_VCI-380_Midi_Mapping_v3.4.pdf'},
        {'url': 'https://virtualdj.com/forums/166703/Old_versions/VESTAX_Hardware.html'}],
    'review': 'Vestax April2012 own owner manual MIDI table, recovered as public cached scan transcription at Manualzz lines1602..1654. The SHA identifies that saved factual excerpt, not the inaccessible original14MB PDF. Own table qualifies deck channels8/9 and shifted channels10/11 (one-based), Play23/Cue22/Sync19, Trim9, High72/Mid71/Low70, input fader7, latching headphone CUE10, shifted LOAD10, shifted Keylock27, Shift12, pads60..67 and global crossfader8/Cue-Master88. Native direct PFL state preserves both toggle edges. Per-deck Shift retires only its source/deck and guards normal deck functions. Pads start unselected and require explicit Hot Cue56. Other normal selectors57/58/59 block Hot Cues. Shifted Sampler56 invalidates the corresponding normal pad channel until Hot Cue is selected again. Shifted clear-pad notes remain inactive. The DJ Yoi owner guide separately confirms Shift+Hot Cue selects Sampler and ordinary panel functions. A partial hardware-owner VDJ device header corroborates the specific VCI-380 endpoint name only; its copied VCI400/channel assumptions do not run. Native sends no setup, query, output, preset, driver, firmware or audio route. TempoCC13/45 order/polarity, jogCC69/scrollCC85 encoding, the ambiguous OCR INPUT SWITCH number, other pad/FX/parameter modes, LED velocity contract, full lifecycle/recovery, source-switch ownership, USB/OS/power and physical/iPad/A10X acceptance remain open. Use the supplied7.5V adapter. Generic Vestax MIDI endpoints and other VCI models are excluded.'}}


def vci380_profiles():
    """Return transport, mixer and explicitly selected Hot Cues without guessed modes."""
    p = profile('Vestax VCI-380', VCI380_SOURCE)
    p.update(definition='reviewed:vci380-manufacturer-core',
        aliases=['Vestax VCI-380', 'VCI-380', 'VCI380'],
        excludedAliases=['Vestax MIDI In', 'Vestax MIDI Out', 'VCI-400', 'VCI-300', 'VCI-100'],
        hardwareMode='Use the VCI-380 USB MIDI endpoint with its supplied7.5V adapter and computer deck sources. Select Hot Cue on each deck before using its pads. Other pad modes block Hot Cues. Shift remains per deck. Jog, tempo, FX and audio routing are not configured.',
        scope='Automatic44-input documented MIDI subset: transport, mixer, direct PFL, Load, Keylock, Shift and sixteen explicitly selected Hot Cues. No output or audio setup. Full modes and physical acceptance remain open.',
        inputModes=[{'channel': ch, 'numbers': [56, 57, 58, 59], 'invalidatingSelectors': [{'channel': ch + 2, 'number': 56}]} for ch in [7, 8]],
        bankChanges=[{'channel': ch, 'number': 12, 'anyPositive': True, 'decks': [deck], 'releaseShiftChannels': [ch]} for ch, deck in [(7, 'a'), (8, 'b')]],
        gaps=[VCI380_REFERENCES['Vestax VCI-380']['review']])
    for ch, deck in [(7, 'a'), (8, 'b')]:
        for action, number in [('play', 23), ('cuePreview', 22), ('sync', 19)]:
            add(p, action, ch, number, deck=deck)
        for action, number in [('gain', 9), ('high', 72), ('mid', 71), ('low', 70), ('level', 7)]:
            add(p, action, ch, number, 'control', deck=deck)
        for slot in range(8):
            add(p, f'hotcue{slot + 1}', ch, 60 + slot, deck=deck)
            p['inputs'][-1]['requiredMode'] = 56
        for row in p['inputs']:
            if row.get('targetDeck') == deck: row.update(shifted=False, shiftChannel=ch)
        add(p, 'cueState', ch, 10, deck=deck)
        add(p, 'load', ch + 2, 10, deck=deck)
        add(p, 'keylock', ch + 2, 27, deck=deck)
        p['inputs'][-1].update(shifted=True, shiftChannel=ch)
        add(p, 'keylock', ch, 27, deck=deck)
        p['inputs'][-1].update(releaseOnly=True, shiftChannel=ch)
        add(p, 'shift', ch, 12)
        p['inputs'][-1]['shiftChannel'] = ch
    add(p, 'crossfader', 7, 8, 'control')
    add(p, 'cueMix', 7, 88, 'control')
    return [p]

"""Independent legacy dock MIDI facts from public editable factory presets."""
from curated import add, profile

DOCK_ARCHIVE = 'https://download.algoriddim.com/djay/202010171657/djay_Pro_2.2.9.zip'
DOCK_ARCHIVE_SHA = 'a3c00db3030859bdb71c74368ac5adcc85d62a06790e31a635fa6c8f663775ee'
ION_MANUAL = 'https://asset.conrad.com/media10/add/160267/c1/-/gl/000312642ML01/manual-312642-ion-audio-idj2go-dj-controller.pdf'
PHILIPS_MANUAL = 'https://www.documents.philips.com/assets/20231208/7ae14ad277064c378795b0d2011f4d72.pdf'
DOCK_REFERENCES = {
    'Ion iDJ2GO': {
        'url': DOCK_ARCHIVE, 'sha256': DOCK_ARCHIVE_SHA,
        'members': [{'path': 'djay Pro 2.app/Contents/Resources/MIDI Mappings/ION iDJ2GO.djayMidiMapping', 'sha256': '00df443d04bd488f544232aef9ba6a2825287899ce236cda9f3d4d7c7d11ce3c'}],
        'relatedSources': [{'url': ION_MANUAL, 'sha256': '58fb91b5f69e33469a82de2372253400de6f1356d13ac7bd11e35f82c1e9601f', 'pages': [3, 4]}],
        'review': 'The visible26-control iOS factory preset independently qualifies21 native manual inputs. The manufacturer quickstart page4 was visually reviewed and explicitly describes held Cue and pitch-bend release. Native Load buttons load the current selection directly. The source app opens its library. Its rotary sensitivity does not establish jog counts or encoder direction. Jog/browse streams and Back/Enter stay inactive. The30-pin connection, accessory authentication and any CoreMIDI exposure require implementation or qualification. No Numark sibling, source program, private custom class, output, startup or audio route is inherited.'},
    'Philips M1X-DJ': {
        'url': DOCK_ARCHIVE, 'sha256': DOCK_ARCHIVE_SHA,
        'members': [{'path': 'djay Pro 2.app/Contents/Resources/MIDI Mappings/Philips M1X DJ.djayMidiMapping', 'sha256': '6c6375b3daf7aea971def8b4cbcff658169e05deaf74a5a47ce0c14f5728c449'}],
        'relatedSources': [{'url': PHILIPS_MANUAL, 'sha256': '4e06e2522c0bc5323e18eef29a8da7f4783a3a7700b0cc92afd9f407ea979818', 'pages': [10, 11, 12]}],
        'review': 'The visible28-control factory preset independently qualifies21 native manual inputs. Manufacturer printed page10 was visually reviewed and distinguishes Cue Set from Cue recall. Native Cue Set/Goto preserve separate actions without a held-Cue inference. The private PhilipsM1XDJ class is neither inspected nor reproduced. Unqualified jog/mode/record controls and nested output addresses do not establish full wire contracts. The Lightning accessory connection, authentication, custom initialisation, audio ownership, two-second Cue clear, full modes/calibration/lifecycle and physical/iPad/A10X acceptance remain open. Bluetooth audio is not Bluetooth MIDI.'},
}


def legacy_djay_dock_profiles():
    ion = profile('Ion iDJ2GO', DOCK_ARCHIVE)
    ion.update(autoSelect=False, definition='reviewed:idj2go-public-factory-inputs',
               aliases=['Ion iDJ2GO', 'ION iDJ2GO', 'iDJ2GO'],
               excludedAliases=['DJ2GO', 'Numark DJ2GO', 'iDJ Live', 'iDJ Live II', 'iDJ Pro'],
               hardwareMode='Manual exposed MIDI port only. Original hardware uses a hard-wired30-pin dock. Native Load directly loads the selected track. Dock authentication and audio require separate work.',
               scope='Manual21-input transport, held Cue/bend, Load and mixer subset. No rotary stream, private accessory transport, hardware write or automatic audio route.',
               gaps=['Original30-pin accessory authentication/CoreMIDI exposure, library Back/Enter, jog/browse direction and calibration, long-Load modes, full feedback/lifecycle and physical/iPad/A10X acceptance remain open.'])
    for deck, play, cue, sync, pfl, down, up, load, level, tempo in [
        ('a', 59, 51, 64, 72, 67, 68, 75, 8, 6), ('b', 66, 60, 71, 73, 69, 70, 52, 9, 7),
    ]:
        for action, number in [('play', play), ('cuePreview', cue), ('sync', sync), ('cue', pfl),
                               ('pitchBendDown', down), ('pitchBendUp', up), ('load', load)]:
            add(ion, action, 0, number, deck=deck)
        add(ion, 'level', 0, level, 'control', deck=deck)
        add(ion, 'tempo', 0, tempo, 'control', deck=deck)
        ion['inputs'][-1]['inverted'] = True
    for action, number in [('crossfader', 10), ('master', 23), ('monitor', 5)]:
        add(ion, action, 0, number, 'control')
        ion['inputs'][-1]['inverted'] = action == 'crossfader'

    philips = profile('Philips M1X-DJ', DOCK_ARCHIVE)
    philips.update(autoSelect=False, definition='reviewed:m1x-dj-public-factory-inputs',
                   aliases=['Philips M1X-DJ', 'Philips M1X DJ', 'M1X-DJ', 'DS8900'],
                   excludedAliases=['M1X-DJ Bluetooth', 'M1X Bluetooth', 'M1X-DJ clone'],
                   hardwareMode='Manual exposed MIDI port only. The manufacturer specifies its Lightning dock for DJ controls. Bluetooth is audio-only. Native uses separate Cue Set and Cue recall. Configure audio separately.',
                   scope='Manual21-input two-channel mixer, transport, separate Cue Set/Goto and tempo subset. No private custom class, rotary mode, hardware write or automatic audio route.',
                   gaps=['Lightning authentication/CoreMIDI exposure, private custom initialisation, jog/mode/record controls, two-second Cue clear, hardware/software audio ownership, complete output/lifecycle/calibration and physical/iPad/A10X acceptance remain open.'])
    for channel, deck in [(1, 'a'), (2, 'b')]:
        for action, number in [('play', 1), ('cueSet', 3), ('cueGoto', 2), ('sync', 5), ('cue', 10)]:
            add(philips, action, channel, number, deck=deck)
        for action, number in [('tempo', 7), ('high', 5), ('mid', 6), ('low', 4)]:
            add(philips, action, channel, number, 'control', deck=deck)
        add(philips, 'level', 0, channel + 1, 'control', deck=deck)
    add(philips, 'crossfader', 0, 1, 'control')
    return [ion, philips]

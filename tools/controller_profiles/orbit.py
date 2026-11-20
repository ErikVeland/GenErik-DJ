"""Orbit factory pad facts and an explicit native four-bank performance layout."""
from curated import add, profile

ORBIT_ARCHIVE = 'https://www.numark.com/images/product_downloads/Orbit-NEBUL4_%282Decks%29.zip'
ORBIT_REFERENCES = {'Numark Orbit': {
    'url': ORBIT_ARCHIVE, 'sha256': 'dd1af1b90a6f6e4a1221558016c5a1c5322ef8b74efc598d639e5cf764a5ec75',
    'files': [{'cachePath': 'TestBuilds/r431/upstream/orbit/nebula-two.zip', 'sha256': 'dd1af1b90a6f6e4a1221558016c5a1c5322ef8b74efc598d639e5cf764a5ec75'}, {'cachePath': 'TestBuilds/r431/upstream/orbit/nebula-two/Orbit - Default MIDI.json', 'sha256': 'f43a75a4547028e55ee48e24589fbee3b3aba4ecf37a3e522c8da29c08e1744d'}, {'cachePath': 'TestBuilds/r431/upstream/orbit/nebula-two/Installation Instuctions Orbit - NEBUL4.docx', 'sha256': '31cf3dee080aedfad684c3e05822a4723c96a3bc755c255258749d35d4288b7d'}, {'cachePath': 'TestBuilds/r431/upstream/orbit/user-guide.pdf', 'sha256': '0b51ee22ed159cea3a2bc78b1146b9c0ded63b7f42d5d55569aac53aa5d73b8b'}, {'cachePath': 'TestBuilds/r431/upstream/orbit/editor-guide.pdf', 'sha256': '3d6753ddd7115c342486a5bd83d5a34568a66d488cf3ea7016f1b9f50b31524c'}],
    'relatedSources': [{'url': 'https://www.numark.com/product/orbit'}, {'url': 'https://www.numark.com/images/product_downloads/Orbit_Editor_-_User_Guide.pdf', 'pages': [5, 10, 11]}, {'url': 'https://www.numark.com/images/product_downloads/Orbit_-_User_Guide_-_v1.1.pdf', 'pages': [3, 4]}],
    'review': 'Manufacturer archive includes its Default MIDI JSON and installation instructions explicitly allowing a default device to skip editor programming. All64 pads use momentary mode, Notes36..51 on distinct channels1..4. Each exact pad wire and mode is checked against the own template. Editor guide qualifies distinct Numark ORBIT port names and the momentary mode. Native assigns one bank to each A/B/C/D deck. Notes36..43 are eight Hot Cues;44..51 are Play, held Cue, Sync, Load, Loop In, Loop Out, Reloop and Key Lock. C/D require app opt-in. This explicit native layout does not execute NEBUL4 Traktor actions. The next mapped positive pad on a changed channel retires only that source before its new action. NoteOff and NoteOn-zero keep the original bank. No standalone bank-selector message is qualified; a held control awaits its original release or next mapped bank report. Custom pad assignments/toggle mode, virtual knobs/accelerometer/shoulder controls, complete bank lifecycle/recovery, pad/ring feedback, wired/wireless receiver/OS/power and physical/iPad/A10X acceptance remain open. No saved preset, editor, application, driver, firmware, identity probe, LED colour or audio route is written.'}}


def orbit_profiles():
    """Assign documented factory pads to the native four-deck performance layout."""
    p = profile('Numark Orbit', ORBIT_ARCHIVE)
    p.update(definition='reviewed:orbit-factory-native-pads', role='accessory', inputProtocol='orbit',
        aliases=['Numark Orbit', 'Numark ORBIT', 'ORBIT'], excludedAliases=['Numark Orbit Editor', 'USB Audio Device'],
        hardwareMode='Use factory-default momentary pads. Pad banks1/2/3/4 target A/B/C/D. C/D require app opt-in. In note order36..51: eight Hot Cues, Play, Cue, Sync, Load, Loop In, Loop Out, Reloop and Key Lock. No device reprogramming is sent.',
        scope='Automatic64-input native four-bank pad performance layout. First mapped pad after a bank change retires only the reporting source. Knobs, motion and feedback remain open.', gaps=[ORBIT_REFERENCES['Numark Orbit']['review']])
    for channel, deck in enumerate('abcd'):
        for slot in range(8): add(p, f'hotcue{slot + 1}', channel, 36 + slot, deck=deck)
        for action, wire in [('play', 44), ('cuePreview', 45), ('sync', 46), ('load', 47), ('loopIn', 48), ('loopOut', 49), ('reloop', 50), ('keylock', 51)]: add(p, action, channel, wire, deck=deck)
    return [p]

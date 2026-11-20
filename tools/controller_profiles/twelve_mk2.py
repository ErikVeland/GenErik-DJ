"""Own Twelve MKII MIDI accessory facts from the archived NI-published mapping."""
from curated import add, profile

ORIGINAL_URL='https://www.native-instruments.com/fileadmin/downloads/Traktor_Pro_4_Controller_Mappings/Rane/Rane_-_Rane_Twelve_MK2.zip'
ARCHIVE_URL='https://web.archive.org/web/20260214105609id_/'+ORIGINAL_URL
TWELVE_MK2_REFERENCES={'Rane TWELVE MKII': {
    'url': ORIGINAL_URL,
    'sha256': '0be4de350509142e1703a254cba075b5a402e289d717a6f0e2ff929079ce0544',
    'archiveURL': ARCHIVE_URL,
    'archivePayloadSHA1Base32': '4QNUUXW577K76KCCPJD3SYZWY5WRCXRK',
    'files': [
        {'cachePath': 'TestBuilds/r495/upstream/Rane-Twelve-MK2-NI.zip',
         'sha256': '0be4de350509142e1703a254cba075b5a402e289d717a6f0e2ff929079ce0544'},
        {'cachePath': 'TestBuilds/r495/upstream/unpacked/Rane - Rane Twelve MK2.tsi',
         'sha256': '637741b3bf0d53c18d232bd670d178be374018a3199dd3593c44d43cc0623126'},
        {'cachePath': 'TestBuilds/r355/upstream/twelve-mk2-guide-v1.1.pdf',
         'sha256': '6ad794ab8fcc99d6ce5d7b3399a9ac4eb90b1989c11aaeac7f1a4390d7af438e'}],
    'relatedSources': [
        {'url': 'https://cdn.inmusicbrands.com/rane/twelveMKII/Twelve_MKII-UserGuide-v1.1.pdf'},
        {'url': 'https://github.com/ivanz/TraktorMappingFileFormat/wiki/File-Format-Specification'},
        {'url': 'https://github.com/ivanz/TraktorMappingFileFormat/wiki/Traktor-Commands-List'}],
    'review': 'R495 recovers the own-model NI-published ZIP from the public20260214105609 archive. Its SHA1 matches the archive index payload digest. Read-only ZIP/XML/base64 inspection finds326 mapping rows,322 assigned and four deliberately unassigned cue1 deletes. The selected68 positive rows have no modifier conditions. Raw0/1/2/3 Note2 command3076 is A/B/C/D Load. CC102 command103 is absolute Seek Position, not pitch. Raw4/5/6/7 Note20..27 command2328 selects/stores cue1..8. Note29..35 command2331 deletes cue2..8. Slot integers at CMAD offset44 agree. Own manual printed7 visually confirms strip modes, full-track Needle Drop and held Cue Mode deletion. Note28 is not inferred. All Ports does not establish a USB identity. Manual input-only accessory role preserves explicit four-target channels. No original TWELVE/MKI alias, automatic selection, Play/main Cue/Sync/pitch/range/RPM/motor/DVS/audio/display/feedback/Instant Doubles/Back/browse/lifecycle or full-mode claim. Source output colour formulas and conditional commands remain inactive. No upstream code, TSI actions, settings or hardware writes execute or ship. Separate audio, exposed MIDI, hardware Traktor DVS/strip mode, host/driver/power compatibility and physical/iPad/A10X acceptance remain open.'}}


def twelve_mk2_profiles():
    """Keep explicit deck channels and the deliberately missing cue1 clear."""
    ref=TWELVE_MK2_REFERENCES['Rane TWELVE MKII']
    p=profile('Rane TWELVE MKII',ref['url'])
    p.update(definition='reviewed:twelve-mk2-ni-midi-accessory',autoSelect=False,role='accessory',
        aliases=['Rane TWELVE MKII','TWELVE MKII','Rane Twelve MK2','Twelve MK2'],
        excludedAliases=['Performer','SYSTEM ONE','SEVENTY'],
        hardwareMode='Select this manual input-only recipe on an exposed Twelve MKII MIDI endpoint. Use the hardware Traktor DVS mode. Needle Drop controls track position. Hot Cue mode supplies eight cues and deletion for cues2..8. Configure audio separately. Motor, timecode, pitch and automatic detection remain unqualified.',
        scope='Manual Twelve MKII MIDI accessory subset: A/B/C/D Load and strip Seek, eight Hot Cues per target, and seven dedicated cue deletes per target. C/D require app opt-in. No motor, DVS, transport, pitch, feedback, hardware setup or audio-route claim.',
        gaps=[ref['review']])
    for channel,deck in enumerate('abcd'):
        add(p,'load',channel,2,deck=deck)
        add(p,'seek',channel,102,'control',deck=deck)
        for slot in range(8):
            add(p,f'hotcue{slot+1}',channel+4,20+slot,deck=deck)
            cue=p['inputs'][-1]
            cue['layerIndependent']=True
            if slot:
                suffix='A' if deck in 'ac' else 'B'
                clear={**cue,'action':f'clearHotcue{slot+1}{suffix}','number':28+slot}
                p['inputs'].extend([clear,{**cue,'number':28+slot,'releaseOnly':True},
                                    {**clear,'number':20+slot,'releaseOnly':True}])
    return [p]

"""Documented MK2 audio routing without an invented controller or DVS protocol."""

AUDIO2_OUTPUT={
    'model':'Native Instruments TRAKTOR AUDIO 2',
    'source':{
        'url':'https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_audio_2_mk2_manual_english.pdf',
        'sha256':'8454159b9bbe9e5e0488e6fc1d48f43d5a7bc73f23f1e17d1eddda93e23ba490',
        'files':[{'cachePath':'TestBuilds/r453/upstream/traktor-audio2-mk2-manual.pdf','sha256':'8454159b9bbe9e5e0488e6fc1d48f43d5a7bc73f23f1e17d1eddda93e23ba490'}],
    },
    'relatedSources':[{'url':'https://support.native-instruments.com/support/solutions/articles/69000879440-traktor-dj-ios-audio-interface-compatibility'}],
    'format':'Manufacturer MK2 manual; p25 routing and device name visually reviewed',
    'automaticSupportAdded':False,'automaticAudioOutputAdded':True,
    'audioOutput':{'recognisedName':'Traktor Audio 2 MK2','route':'masterAndHeadphones','mainChannels':[1,2],'headphoneChannels':[3,4],'variant':'MK2 only','audioInputs':0},
    'gaps':[
        'MK2 output routing is implemented only for an already available wired CoreAudio endpoint named Traktor Audio 2 MK2. Physical/iPad/A10X route, firmware, power and cable acceptance remain open.',
        'The own manual describes software-controlled headphone-volume and cue-mix encoders. Their hardware control protocol and complete lifecycle remain unqualified. No MIDI profile or control bytes are inferred.',
        'This is an output-only interface without DVS audio inputs. Legacy AUDIO 2 DJ and TRAKTOR AUDIO 2 MK1 require proprietary drivers and do not inherit direct iPad compatibility. Bare or other-generation names stay unmatched.',
    ],
}

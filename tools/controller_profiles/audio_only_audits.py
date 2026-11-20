"""Qualified external audio requirements, without invented MIDI controller rows."""
AUDIO_ONLY_AUDITS = {
    'Reloop PTB-2': {
        'source': {
            'url':'https://www.reloop.com/media/custom/upload/Reloop-244081_Reloop_IM.pdf',
            'sha256':'177b2791163f1aa0ca517bf30b59cbcfdb3ce94933720cf743083bb92e9a1dbb',
            'files':[{'cachePath':'TestBuilds/r462/upstream/ptb2-manual.pdf','sha256':'177b2791163f1aa0ca517bf30b59cbcfdb3ce94933720cf743083bb92e9a1dbb'}],

        },
        'relatedSources':[
            {'url':'https://www.reloop.com/reloop-ptb-2'},
            {'url':'https://community.algoriddim.com/t/reloop-ptb-2-mini-dvs-mixer-support/41178/11'},
        ],
        'format':'Own manufacturer manual, product specifications and official software integration support statement',
        'externalAudioMixer':True,'automaticSupportAdded':False,
        'controlProtocol':{'kind':'none','basis':'Official integration support explicitly states that the hardware controls do not send MIDI. Bluetooth is an audio input, not a MIDI control interface.'},
        'audioRequirements':{'usbInputs':4,'usbOutputs':4,'mixing':'external','dvsRequiredForCompleteSupport':True,'routingImplemented':False},
        'gaps':[
            'No MIDI controller mapping applies to PTB-2 hardware controls. They mix audio externally. A separate controller or the app touch controls must operate native transport.',
            'Implement and qualify external deck-A/deck-B audio output routing and DVS input processing. The existing master1/2-headphones3/4 route is not an external two-deck mixer route. No automatic route is enabled.',
            'Own manual requires USB/DVS source, the correct PC/Phone host-source setting, suitable USB-C power and a certified Lightning adapter where needed. These physical switch, cable and power states are not discovered or changed by the app.',
            'Complete USB channel assignment, lifecycle/recovery, input calibration, DVS behaviour, USB/Bluetooth interaction and physical/iPad/A10X acceptance remain open. A product or software-support listing does not prove native application support.',
        ],
    },
}

AUDIO_ONLY_AUDITS['Allen & Heath Xone:23C'] = {'source': {'url': 'https://www.allen-heath.com/content/uploads/2023/06/AP9433_5_X23C_UG.pdf', 'sha256': '650186fed76693c5ee8bbade2c38de8a1aab86882a337d1b8e96deb1cbb689cf', 'files': [{'cachePath': 'TestBuilds/r462/upstream/xone23c-manual.pdf', 'sha256': '650186fed76693c5ee8bbade2c38de8a1aab86882a337d1b8e96deb1cbb689cf'}]}, 'relatedSources': [{'url': 'https://www.allen-heath.com/hardware/legacy-products/xone23c/resources/'}], 'format': 'Own manufacturer user guide AP9433 issue5; explicit no-own-MIDI statement on p12', 'externalAudioMixer': True, 'automaticSupportAdded': False, 'controlProtocol': {'kind': 'none', 'basis': 'The manufacturer explicitly states that Xone:23C sends no MIDI on its own. X:Link powers and passes MIDI from a separate K1/K2; it does not expose the mixer controls.'}, 'audioRequirements': {'usbInputs': 4, 'usbOutputs': 4, 'mixing': 'external', 'dvsRequiredForCompleteSupport': True, 'routingImplemented': False}, 'gaps': ['No MIDI controller mapping applies to Xone:23C hardware controls. X:Link MIDI from separate controllers requires their own qualified profiles. No Xone:43C/96 byte map is inherited.', 'Implement and qualify external deck-A/deck-B audio output routing and DVS inputs. The default USB inputs are record1/2 and FXsend3/4. DVS input routing requires the documented internal conversion harness configuration. Native does not discover or change that physical configuration.', 'The own guide describes proprietary Mac driver modes, including a Core Audio mode. This does not establish direct iPad class compliance or current OS support. Separate USB, driver, power, adapter and audio-source qualification remains open.', 'Full channel assignment, lifecycle/recovery, DVS input calibration and physical/iPad/A10X acceptance remain open. No MIDI preset, internal harness, driver, identity query or automatic audio route is changed.']}

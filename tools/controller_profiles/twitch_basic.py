"""Published Twitch Basic MIDI pages with bounded source-local load banking."""
from curated import add, profile

TWITCH_GUIDE = 'https://fael-downloads-prod.focusrite.com/customer/dev/s3fs-public/novation/downloads/25322/twitch-programmers-reference2.pdf'
TWITCH_REFERENCES = {'Novation Twitch': {
    'url': TWITCH_GUIDE, 'cacheName': 'twitch-programmers-reference.pdf',
    'sha256': '466f07f6feb7192f2db720734397c71656a85a19da72bd0d6cfc3c4d62d26fdf',
    'relatedSources': [{'url': 'https://downloads.novationmusic.com/novation/novation-miscellaneous/twitch'},
                       {'url': 'https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg',
                        'sha256': '55aaca2c33e7f1b84b420ab20f2c261f1c98ee73b62b3c012e25616f39070030',
                        'member': 'Applications/DEX4.app/Contents/Resources/controllers/Novation__Twitch.js',
                        'memberSHA256': '0505e8b0ff0147dd75c746556086479e15a778a6e8bd5b1164079366df2b59f6',
                        'evidenceLimit': 'Independent software-selected127 scratch scale only. No script or source action is copied or executed.'}],
    'review': 'Manufacturer programmer reference pages4/5,9/10,12/13 and16 were visually checked. Basic reset B7/00/00 initialises the controller and reports visible analogue controls. Basic deck channels are wire7/8/9/10. Selector notes0 on7/8 choose A/C and B/D; shared load notes82/83 stay on7. Firmware pages the other deck inputs and all selected feedback. Positive strip-note71 velocities encode finger position, so every positive value is contact. SWIPE CC53 is signed twos complement; DROP52 is absolute. Native chooses beat jumps for Back/Fwd, eight fixed loop lengths, composed Shift and127 software scrub scaling; these are app layout/calibration choices, not manufacturer physical turn calibration. PCDJ DEX public mapping independently uses127 software scratch scaling. Automatic software banking is limited to load actions with paired bounded reset setup and no load feedback. Advanced ITCH arbitration is expressly outside this public guide. No software action/script is copied or executed. Complete arbitration, modes, audio, pitch/strip calibration and physical/iPad/A10X acceptance remain open.'}}


def twitch_basic_profiles():
    result = profile('Novation Twitch', TWITCH_GUIDE)
    result.update(definition='manufacturer:novation-twitch-basic-core',
                  aliases=['Novation Twitch', 'Twitch', 'Novation TWITCH'],
                  excludedAliases=['Novation Launchpad', 'Novation Dicer'],
                  hardwareMode='Basic MIDI, established by the documented reset through the paired output. Close other DJ software. A/C and B/D select the shared Load targets; C/D require four-deck opt-in. Hot Cues and Loop select firmware pad pages. Shift is composed across both sides. Configure audio separately.',
                  scope='Automatic139-input Basic MIDI core with four firmware deck pages, two source-local banked loads, relative tempo, contact-gated SWIPE, absolute DROP, eight Hot Cues and native fixed loops per deck, mixer and44 selected lamps.',
                  gaps=['Advanced ITCH mode/arbitration, source-specific FX/Freeze/BeatGrid/sampler, complete Shift/UI/feedback/lifecycle/audio and physical/iPad/A10X acceptance remain open. Native fixed loops use0.25/0.5/1/2/4/8/16/32 beats; Back/Fwd use native beat jumps. The selected127 software SWIPE scale and relative pitch range require physical calibration. No private arbitration, audio route, direct-monitor control, all-LED-off or advanced-mode write is sent.'])
    for channel, deck in enumerate('abcd', 7):
        add(result, 'shift', channel, 17)
        result['inputs'][-1]['shiftInput'] = (channel - 7) % 2
        for action, number, lamp in [('play',23,127), ('cuePreview',22,79), ('sync',16,16)]:
            add(result, action, channel, number, deck=deck, feedback=True)
            result['inputs'][-1]['shifted'] = False
            result['outputs'][-1]['onValue'] = lamp
        for action, number in [('jumpBack',18), ('jumpForward',19), ('tempoReset',3), ('filterToggle',10)]:
            add(result, action, channel, number, deck=deck)
            result['inputs'][-1]['shifted'] = False
        add(result, 'tempo', channel, 3, 'control', 'twosComplement', deck)
        for action, number in [('level',7), ('gain',9), ('low',70), ('mid',71), ('high',72)]:
            add(result, action, channel, number, 'control', deck=deck)
        add(result, 'jogTouch', channel, 71, deck=deck)
        add(result, 'jog', channel, 53, 'control', 'twosComplement', deck)
        result['inputs'][-1].update(argument=127, requiresTouch=True)
        add(result, 'seek', channel, 52, 'control', deck=deck)
        for slot in range(8):
            add(result, f'hotcue{slot+1}', channel, 96+slot, deck=deck, feedback=True)
            result['inputs'][-1]['shifted'] = False
            result['outputs'][-1]['onValue'] = 79
            add(result, 'loop', channel, 112+slot, deck=deck)
            result['inputs'][-1].update(argument=[.25,.5,1,2,4,8,16,32][slot], shifted=False)
    for bank, deck in enumerate('ab'):
        add(result, 'load', 7, 82+bank, deck=deck)
        result['inputs'][-1]['deckBank'] = bank
    add(result, 'crossfader', 7, 8, 'control')
    for shifted, action in [(False,'browse'), (True,'browseGroups')]:
        add(result, action, 7, 85, 'control', 'twosComplement')
        result['inputs'][-1]['shifted'] = shifted
    for number in [85,86]:
        add(result, 'openGroup', 7, number)
    result['bankChanges'] = [{'channel':7+bank, 'number':0, 'onValue':127,
                              'decks':list('ac' if bank==0 else 'bd'), 'deckBank':bank} for bank in range(2)]
    for channel, deck in enumerate('abcd',7):
        result['bankChanges'].append({'channel':channel, 'number':17, 'onValue':127, 'decks':list('abcd')})
        result['bankChanges'] += [{'channel':channel, 'number':number, 'onValue':127, 'decks':[deck]} for number in range(56,60)]
    result['startup'] = [[0xB7,0,0]]
    result['shutdown'] = [[0x90+r['channel'],r['number'],0] for r in result['outputs']] + [[0xB7,0,0]]
    return [result]

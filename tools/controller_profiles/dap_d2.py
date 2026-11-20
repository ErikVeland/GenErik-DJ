"""Own DAP D2 hexadecimal facts with distinct stopped and held Cue roles."""
from curated import add, profile

DAP_D2_REFERENCES={'DAP KONTROL D2': {'url': 'https://www.highlite.com/media/attachments/MANUAL/D1261_MANUAL_GB_V1.pdf', 'sha256': 'd4e9a9029dfd93acf5f736814b16892013d045005ef1cf446cc8b64243aa3582', 'files': [{'cachePath': 'TestBuilds/r474/upstream/dap-d2-manual.pdf', 'sha256': 'd4e9a9029dfd93acf5f736814b16892013d045005ef1cf446cc8b64243aa3582'}], 'visuallyReviewedPages': [26, 27, 28], 'review': 'Own manufacturer Highlite D1261 Core Kontrol D2 English V1 guide printed9/10/11/26/27/28, with MIDI appendix26..28 visually reviewed. All note/CC numbers are hexadecimal. The channel table puts X under Transmitted Default and1 under Recognized Default while other reception rows say X. It does not establish a transmitted factory channel. Native accepts all16 channels through the bounded manual unbanked two-deck core; stored raw0 is only a placeholder. All33 wire numbers and actions are unique, with no modes/banks/modifiers/setup/output/audio. The schema keeps mandatory A/B Play, held Cue and levels but permits an absent crossfader; no polarity is invented merely to satisfy a schema. Only native Cue Stop and Reloop roles are added to its permitted normal buttons; all previous uniqueness, kind, target and field guards remain. Own Play43/4C, SetCue3B/44, Cue33/3C, Sync40/47, Keylock38/3F, Load4B/34, PFL55/56, bends minus79/68 and plus78/67, loop-half72/61, B loop-double60 and B Reloop5F are independently transcribed. Set Cue is the held preview control. Separate Cue Stop returns to the saved Cue and pauses, including when already paused, without marking a new Cue or changing Sync. Main Cue and Set Cue are not confused with headphone PFL. Own absolute gain0D/0E, high10/11, mid12/13, low14/15, level08/09 and cueMix20 retain native pickup. The guide explicitly identifies Master as analogue/no MIDI; no master/monitor control is invented. Cross0A direction, tempo/ranges, A loop-double/reloop addresses omitted by the table, loops/SmartLoops/HotCues/delete modes, Shift-dependent FX/filter/pitch roles, relative jog/contact/needle calibration, library/kill/FX/sampler/reverse/curve/source states and complete feedback/lifecycle/recovery remain open. Recognized notes/CC are X, so no lamp packets are sent. Hardware emits NoteOn127/0; native additionally accepts NoteOff releases. Manual selection and existing MIDI input with separately configured app audio are required because analogue cue mix/hardware ownership is not automated. Exact USB names/driver/OS/power/channel polarity/audio/DVS and physical/iPad/A10X acceptance remain open. No NI Kontrol D2, DAP D4i, ABMA4 or other OEM protocol/identity is inherited. No preset, driver, firmware, source code, query, setting or audio-route write runs.'}}


def dap_d2_profiles():
    """Return a manual normal core without guessing channel or omitted addresses."""
    ref=DAP_D2_REFERENCES['DAP KONTROL D2'];p=profile('DAP KONTROL D2',ref['url'])
    p.update(autoSelect=False,definition='manufacturer:dap-d2-own-normal-core',
        aliases=['DAP KONTROL D2','DAP Audio Kontrol D2','DAP Core Kontrol D2','Core Kontrol D2'],
        excludedAliases=['Traktor Kontrol D2','Native Instruments Kontrol D2','Kontrol D4i','ABMA4','DRAGON TWO'],
        hardwareMode='Select DAP Core Kontrol D2 manually on an exposed MIDI source. The transmitted factory channel is not established; normal qualified controls accept channel changes. Cue returns and stops; Set Cue provides held preview. Configure app audio separately. Crossfader, modes, lights and motion remain unqualified.',
        scope='Manual33-input fixed A/B normal Play/held Set Cue/Cue Stop, Sync/Keylock/Load/PFL/bends, documented loop-size/B Reloop and gain/EQ/level/cue mix. No channel, crossfader, master, output or audio-route assumption.',
        gaps=[ref['review']])
    for deck,notes in [('a',[0x43,0x3B,0x33,0x40,0x38,0x4B,0x55,0x79,0x78,0x72]),('b',[0x4C,0x44,0x3C,0x47,0x3F,0x34,0x56,0x68,0x67,0x61])]:
        for action,n in zip(['play','cuePreview','cueStop','sync','keylock','load','cue','pitchBendDown','pitchBendUp','loopDown'],notes):add(p,action,0,n,deck=deck)
    add(p,'loopUp',0,0x60,deck='b');add(p,'reloop',0,0x5F,deck='b')
    for deck,nums in [('a',[0x0D,0x10,0x12,0x14,0x08]),('b',[0x0E,0x11,0x13,0x15,0x09])]:
        for action,n in zip(['gain','high','mid','low','level'],nums):add(p,action,0,n,'control',deck=deck)
    add(p,'cueMix',0,0x20,'control')
    for r in p['inputs']:r['anyChannel']=True
    return [p]

"""Own Xone:43C default-channel fader and direct Cue-state facts."""
from curated import add, profile

XONE43C_SOURCE='https://www.allen-heath.com/content/uploads/2023/07/AP9967_2_X43C_UG.pdf'
XONE43C_SHA='0e38e210810d1a50f6682ca6575ef29473eb9027f00caf2ef073ab66014b2f54'

XONE43C_REVIEW='Own manufacturer AP9967 issue2 guide pp21..23 visually reviewed. Default MIDI channel16/raw15 is explicit and saved channel changes are possible. Own faders CH1..4 send CC0..3 with00..7F; native assigns physical CH1..4 to A..D with pickup and C/D opt-in. Own Cue switch states send NOTE77/57/37/17 (hex4D/39/25/11), ON9n7F and OFF8n00. Native cueState sets headphone PFL directly, including both Note Off families; it does not toggle on every report or become main held Cue. Manual selection and separate app audio are required because these faders/switches also change analogue audio. No automatic mixer or audio ownership is claimed. The other ten documented MIDI controls remain inactive: MicCue92/MicOn93, channel-filter73/53/33/13, XFX4 and HPF/BPF/LPF1/2/3. Their analogue mic/filter/FX states have no qualified native equivalent here. Analogue EQ/gain/filter-frequency/headphone/master/crossfader controls are not invented as MIDI knobs. The numeric MIDI note conversion appendix contains errors; the explicit hex message table is authoritative. No native output packet is sent because received MIDI can change real hardware state. Alternate channel discovery, complete controls/modes/feedback/lifecycle/recovery, USB/X:Link/OS/power/audio/DVS routing and physical/iPad/A10X acceptance remain open. Mac CoreAudio/CoreMIDI class compliance does not prove current direct iPad acceptance. No setup, identity query, preset, hardware Cue/filter, firmware, driver, internal jumper or audio-route write runs. No Xone23C/24C/PX5/96 protocol is inherited.'
XONE43C_REFERENCES={'Allen & Heath XONE 43C':{'url':XONE43C_SOURCE,'sha256':XONE43C_SHA,'files':[{'cachePath':'TestBuilds/r463/upstream/xone43c-manual.pdf','sha256':XONE43C_SHA}],'relatedSources':[{'url':'https://www.allen-heath.com/hardware/legacy-products/xone43c-2/resources/'},{'url':'https://virtualdj.com/manuals/hardware/allenheath/43c/advanced.html'}],'review':XONE43C_REVIEW}}


def xone43c_profiles():
    """Keep analogue mixer ownership outside the manual eight-input MIDI subset."""
    p=profile('Allen & Heath XONE 43C',XONE43C_SOURCE)
    p.update(autoSelect=False,definition='reviewed:xone43c-own-faders-cue-states',
        aliases=['Allen & Heath XONE 43C','Allen & Heath Xone:43C','Xone:43C','Xone 43C','XONE43C'],
        excludedAliases=['Xone:23C','Xone:43','Xone:24C','Xone:96','Xone:PX5'],
        hardwareMode='Manual own MIDI channel16/raw15 only. Physical CH1..4 map A..D; C/D require app opt-in. These controls also change analogue hardware audio. Use separately configured app audio; do not duplicate external mixer attenuation. Other saved MIDI channels need separate mappings.',
        scope='Manual eight-input native subset: four channel faders with pickup and four direct headphone Cue states. No automatic analogue mixer ownership, crossfader, output-state write or audio route. Full controls and theoretical/physical acceptance remain open.',
        gaps=[XONE43C_REVIEW])
    for number,(deck,note) in enumerate(zip('abcd',[77,57,37,17])):
        add(p,'level',15,number,'control',deck=deck)
        add(p,'cueState',15,note,deck=deck)
    return [p]

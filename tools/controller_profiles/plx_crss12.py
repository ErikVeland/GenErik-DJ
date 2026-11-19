"""PLX-CRSS12 pad MIDI facts, separate from motor, DVS and audio ownership."""
from curated import add, profile

CRSS_NAME = "Pioneer PLX-CRSS12"
CRSS_SPEC = "https://downloads.support.alphatheta.com/software_info/turntables/PLX-CRSS12/PLX-CRSS12_MIDI_Message_List_E1.pdf"
CRSS_REFERENCES = {CRSS_NAME: {
    "url": CRSS_SPEC,
    "sha256": "138f464d22a24159e93482047bd4bb8ee18c9a9922e087e74b4f43a154810477",
    "pages": [1, 2, 3, 4, 5],
    "review": "Manufacturer E1 table independently specifies PAD MODE1 hot cues: pad channels8-11 map to A-D, notes0-3 for physical pads1-4 with5-8 off and4-7 with5-8 on. Shift aliases8-15 only rearm the normal cue edge. Physical Shift is note48 on deck channels1-4; use one source-local physical identity so a deck change cannot strand Shift. HOT CUE selects PAD MODE1. Other pad modes stay inactive. While-held5-8 rows contradict their decimal channel8-11 with status9n instead of9p and remain inactive on both candidate channels. MIDI output specifies colour numbers but does not independently qualify palette/off semantics, so no feedback is inferred. Start/Stop and Motor Off still own physical turntable actions, not app transport. Pitch, brake, needle/deck/application controls, DVS, motor/platter/display protocols, audio routing and full lifecycle remain open. This is an automatic MIDI hot-cue accessory core, not complete turntable support. Hardware deck selection chooses the target and C/D require app opt-in. No mode change, stored setting, reset, firmware, motor or audio command is sent. Physical/A10X acceptance remains open.",
}}


def plx_crss12_profiles():
    result = profile(CRSS_NAME, CRSS_SPEC)
    result.update(role="accessory",
                  aliases=[CRSS_NAME, "Pioneer DJ PLX-CRSS12", "PLX-CRSS12", "PLX-CRSS12 MIDI 1"],
                  excludedAliases=["PLX-1000", "PLX-500"],
                  hardwareMode="Automatic MIDI hot-cue accessory. Press HOT CUE for PAD MODE1;5-8 selects cues5-8. Hardware DECK1-4 selects A-D. C/D require app opt-in. Motor, DVS and audio stay separate.",
                  scope="Automatic eight-cue MIDI accessory with source-local Shift and alternate release aliases. This does not implement turntable transport, platter, motor, DVS, audio or full pad modes.",
                  gaps=["While-held5-8 rows have conflicting channel/status columns and stay inactive. Other pad modes, deletion, pitch/brake/needle/deck/application controls, feedback colour/off semantics, display, motor/platter/DVS/audio, full lifecycle and physical/A10X acceptance remain open. No output or mode/setting write is inferred."])
    for channel, deck in enumerate("abcd"):
        add(result, "shift", channel, 48)
        result["inputs"][-1]["shiftInput"] = 0
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", 7 + channel, slot, deck=deck)
            result["inputs"][-1]["shifted"] = False
            add(result, f"hotcue{slot + 1}", 7 + channel, 8 + slot, deck=deck)
            result["inputs"][-1].update(shifted=True, releaseOnly=True)
    return [result]

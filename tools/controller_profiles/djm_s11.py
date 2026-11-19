"""DJM-S11 manual MIDI mirror controls from its factory message table."""
from curated import profile
from pioneer_manual_mixers import add_paired_mixer_inputs

S11_SOURCE = "https://downloads.support.alphatheta.com/midi-mapping/dj-mixers/DJM-S11/DJM-S11_MIDI_Message_v100_E.pdf"
S11_SHA = "e0b2b8eefd96b71756119639e3e3a8871aff7a7e319c7de141d2ba6ca63ab8f6"
S11_REFERENCES = {"Pioneer DJM-S11": {
    "url": S11_SOURCE, "sha256": S11_SHA, "pages": [2],
    "review": "The factory MIDI table explicitly pairs A/B trimCC4/36, high7/39, mid11/43, low15/47, filter1/33 and level19/51 on channels0/1. Global channel6 provides master8/40, headphone volume13/45, cue/program mix12/44 and crossfader31/63. Native paired14Bit uses these exact MSB/LSB addresses and normal direction; hardware crossfader reversal remains in the source value. This is a manual MIDI mirror for a separate software audio path, not an external mixer audio implementation. Hardware mixing, separate deck outputs and software bypass remain unqualified; automatic selection stays off. Browser rows print channel7 with statusBn/9n and do not establish independent ownership of two physical browsers. Their overlapping touchscreen/global notes are not guessed. Shared pads, touchscreen dispatch, fader-start/Hot Cue triggers, PFL cue-fader semantics, EQ kills, hardware effects/microphone controls, full feedback/lifecycle and audio routing remain open. No light or setup packet is inferred and no S9/S7/S5/A9 alias is added. Manual input requires separate enabling; physical acceptance remains open.",
}}


def s11_profiles():
    result = profile("Pioneer DJM-S11", S11_SOURCE)
    result["autoSelect"] = False
    result["hardwareMode"] = "Manual MIDI mirror for a separate software audio path. Enable input separately; hardware mixer bypass and external deck routing remain unavailable."
    result["scope"] = "Manual A/B paired14-bit gain/EQ/filter/levels plus global master, headphones, cue mix and crossfader. Hardware audio routing, browser dispatch, shared pads/screens and physical acceptance remain open."
    result["excludedAliases"] = ["DJM-S9", "DJM-S7", "DJM-S5", "DJM-A9"]
    add_paired_mixer_inputs(result)
    result["gaps"] = ["This manual MIDI mirror does not implement external hardware mixing, separate deck outputs or software mixer bypass. Use with a separate software audio path. Automatic selection stays off. Ambiguous browser/status rows, shared pad/touchscreen modes, fader-start triggers, headphone cue-fader ownership, microphone/hardware FX, lights, complete lifecycle, audio routing and physical acceptance remain open."]
    return [result]

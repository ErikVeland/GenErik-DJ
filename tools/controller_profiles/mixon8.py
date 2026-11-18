"""Mixon 8 Pro unconditional controls from the owner's public djay map."""
from curated import add, profile

MIXON8_SOURCE = "https://community.algoriddim.com/uploads/short-url/krrbEBVJQxHWgVp40gmsnrRN0ZK.djayMidiMa"
MIXON8_DISCUSSION = "https://community.algoriddim.com/t/midi-bug-with-reloop-mixon-8/26352"
MIXON8_SHA = "514e79aaf8627ca0a1ebb98c86442fba8a3c02beb0c444bfd52bc78737d0d215"
MIXON8_REFERENCES = {"Reloop Mixon 8 Pro": {
    "url": MIXON8_SOURCE, "sha256": MIXON8_SHA,
    "relatedSources": [{"url": MIXON8_DISCUSSION}, {"url": "https://www.reloop.com/reloop-mixon-8-pro"}],
    "review": "Owner Djay_Fleg shared this898-row custom map27April2024 with a saved-loop/sampler alias report. Version4, editor djay5.1.6, declares ReloopMixon8. The affected shared modes are excluded. Only unconditional normal controls are independently normalised: channels0..3 Play0, held Cue1, Sync2, gainCC22, filterCC26; global14 Load2..5, rotary64 BrowseCC0 flipped and Back notes7/123; loop channels4..7 On50, Half52, Double53, In56 and Out57. Shifted transport Play4/Cue5/Sync3 and opposite-side deck-bank releases are release-only. Positive alternate presses cannot trigger normal transport. A release arriving on the opposite bank clears the old held Cue; bank selection itself does not release it. EQ/levels, other custom assignments, pitch, conditional jog/seek, pads/screens and all light values remain excluded. Empty/default output dictionaries and modified colour ranges do not qualify complete feedback. The absent custom class owns setup and mode translation; automatic selection and lifecycle remain off. No Mixon4 protocol, startup SysEx or calibration is inherited. Manual input requires separate enabling. No downloaded map or class runs in the app.",
}}


def mixon8_profiles():
    result = profile("Reloop Mixon 8 Pro", MIXON8_SOURCE)
    result["autoSelect"] = False
    result["excludedAliases"] = ["Reloop Mixon 4", "Mixon 4"]
    result["hardwareMode"] = "Manual unconditional-control subset. Enable input separately; missing ReloopMixon8 setup and mode translation remain unqualified."
    result["scope"] = "Manual four-target transport, held Cue, gain/filter, loop controls and flipped browsing. Jog/pitch, EQ/levels, shared pads, lights/screens, setup, audio routing and physical acceptance remain open."
    for channel, deck in enumerate("abcd"):
        normal = [("play", 0), ("cuePreview", 1), ("sync", 2)]
        shifted = [("play", 4), ("cuePreview", 5), ("sync", 3)]
        for action, number in normal:
            add(result, action, channel, number, deck=deck)
        for action, number in shifted:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        for action, number in normal + shifted:
            add(result, action, (channel + 2) % 4, number, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        add(result, "load", 14, 2 + channel, deck=deck)
        for action, number in [("gain", 22), ("filterKnob", 26)]:
            add(result, action, channel, number, "control", deck=deck)
        for action, number in [("loop", 50), ("loopDown", 52), ("loopUp", 53), ("loopIn", 56), ("loopOut", 57)]:
            add(result, action, channel + 4, number, deck=deck)
    add(result, "browse", 14, 0, "control", "binaryOffset")
    result["inputs"][-1]["inverted"] = True
    for number in [7, 123]:
        add(result, "openGroup", 14, number)
    result["gaps"] = ["Missing ReloopMixon8 class leaves setup, pitch/jog translation, EQ/level mode ownership, shared pads and screens unqualified. The source reports a saved-loop/sampler alias issue; those shared pads remain inactive. Complete feedback values, full lifecycle, audio routing and physical acceptance remain open. Automatic selection stays off. Cross-bank release clears held Cue only when a release packet arrives. No Mixon4 facts are inherited."]
    return [result]

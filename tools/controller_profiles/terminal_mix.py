"""Terminal Mix 2/4 core facts from the pinned shared mapping and common helpers."""
from curated import add, profile
from numark import UPSTREAM

TERMINAL_MIX_SOURCES = [
    ("Reloop Terminal Mix 2-4.midi.xml", "75ec007d96620b4665d7435c8c7a86bae8a4fae6146542a5c37ae3ac32b01c40"),
    ("Reloop Terminal Mix 2-4.js", "0676fdf76d5c39223e7fbb05f7fee6ca071bba5971f6908db00d1cdbe033d7de"),
    ("common-controller-scripts.js", "27bad1799146932e2184995d4ab5eb7c1c2a09e0e909284249d6030f7edccdf3"),
]


def terminal_mix_references():
    return {name: {"url": UPSTREAM + TERMINAL_MIX_SOURCES[1][0].replace(" ", "%20"), "sha256": TERMINAL_MIX_SOURCES[1][1],
                   "relatedSources": [{"url": UPSTREAM + path.replace(" ", "%20"), "sha256": digest} for path, digest in TERMINAL_MIX_SOURCES],
                   "review": "The shared XML explicitly supports four decks on either Terminal Mix 2 or 4. Native controls preserve the app four-deck opt-in. Jog/browser use value minus 64; the loop encoder accepts only 65/63. The common midiPitch helper and rate_dir -1 set the pitch direction and exact centre. Crossfader absoluteNonLin uses a raw-64 centre detent. No script execution or automatic fader-start transport is imported."}
            for name in ["Reloop Terminal Mix 2/4"]}


def terminal_mix_profiles():
    results = []
    for name, source in terminal_mix_references().items():
        result = profile(name, source["url"])
        result["aliases"].extend(["Reloop Terminal Mix 2", "Terminal Mix 2", "Reloop Terminal Mix 4", "Terminal Mix 4"])
        result["definition"] = result["definition"].replace("manufacturer:", "reviewed:")
        result["scope"] = "Automatic native core controls and eight Hot Cues per deck. Four decks retain the app opt-in. FX, fader start, shifted modes and full audio routing remain open."
        for channel, deck in enumerate("abcd"):
            for action, number in [("play", 37), ("cueReturn", 36), ("sync", 34), ("keylock", 2),
                                   ("cue", 48), ("load", 50), ("jogTouch", 40), ("loop", 11),
                                   ("reloop", 81), ("loopIn", 12), ("loopOut", 13)]:
                add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "keylock", "cue"})
            add(result, "loopSize", channel, 11, "control", "binaryStep", deck)
            for number in [39, 40]:
                add(result, "jog", channel, number, "control", "binaryOffset", deck)
            add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
            for action, number in [("gain", 43), ("high", 44), ("mid", 45), ("low", 46), ("level", 49)]:
                add(result, action, channel, number, "control", deck=deck)
            for slot, number in enumerate([16, 17, 18, 19, 24, 25, 26, 27], 1):
                add(result, f"hotcue{slot}", channel, number, deck=deck, feedback=True)
        add(result, "crossfader", 0, 58, "control", "centreDetent")
        add(result, "cueMix", 0, 51, "control")
        add(result, "browse", 0, 57, "control", "binaryOffset")
        for number in [57, 55]:
            add(result, "openGroup", 0, number)
        result["shutdown"] = [[0x90 + channel, number, 0] for channel in range(4) for number in [37, 34, 2, 48]]
        result["gaps"] = ["FX, sampler/scissor modes, cue deletion, needle navigation, loop-move/size modifiers, fader/crossfader start, assignment and curve controls, remaining shifted functions, full LED cleanup and audio routing remain unimplemented. Core setup does not copy the source 480-message LED sweep or enable four decks automatically. Jog response and source reuse/distribution review remain open. Generic family-only endpoint names cannot select a model automatically."]
        results.append(result)
    return results

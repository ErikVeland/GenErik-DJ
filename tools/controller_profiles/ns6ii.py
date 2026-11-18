"""NS6II native core facts from the pinned four-deck protocol mapping."""
from curated import add, profile
from numark import UPSTREAM

NS6II_SOURCES = [
    ("Numark NS6II.midi.xml", "c15995a8cd0781c9ef01736294188219c8ba163312fb58bbfef56e8d6acaf3a1"),
    ("Numark-NS6II-scripts.js", "1fcfe8397b711bcb9ecd9a38ff8b45039a05e82eccab78551c6e73b5efbc309f"),
]
NS6II_REFERENCES = {"Numark NS6II": {
    "url": UPSTREAM + NS6II_SOURCES[1][0], "sha256": NS6II_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in NS6II_SOURCES],
    "review": "XML dispatch establishes actual input addresses, including high/mid/low CC 23/24/25 despite the constructor's off-by-one midi property. Script facts establish 1000-count two's-complement jogs, paired CC 9/41 tempo and source inversion. Native pitch accounts for Mixxx rate_dir once. Physical Shift on channels 0/1 controls the corresponding deck side and the shared Load/browser layer. Active bank reports protect pickup and contacts. USB selector reports on channel 15 notes 60/61 reset that side on gain and release contacts and Shift on loss. Pad pages share input addresses and require explicit mode guards. Native pages provide eight cues, fixed loops 1-32 and core loop controls. Software page cycling, rolls, 64/128-beat loops, pad lights, FX, displays, full cleanup and headphone/audio routing remain open. Hardware headphone mixing is not replaced by an inferred MIDI control. No downloaded script runs in the app.",
}}


def ns6ii_profiles():
    result = profile("Numark NS6II", NS6II_REFERENCES["Numark NS6II"]["url"])
    result["definition"] = "reviewed:numark-ns6ii"
    result["scope"] = "Automatic four-target native core with 1000-count jogs, paired tempo, guarded pad pages and bank/USB handover cleanup. C/D retain the app opt-in. Software page cycling, rolls, pad lights, FX, displays, full cleanup, routing and physical calibration remain open."
    result["startup"] = [[0x90 + channel, 7, 127] for channel in range(4)] + [
        [0x94 + channel, 0, 4] for channel in range(4)] + [[0xF0, 0, 32, 127, 3, 1, 0xF7]]
    result["shutdown"] = [[0x90 + channel, 7, 1] for channel in range(4)]
    result["bankChanges"] = [{"channel": channel, "number": 8, "onValue": 127,
                              "decks": ["a", "c"] if channel % 2 == 0 else ["b", "d"]}
                             for channel in range(4)] + [
        {"channel": 15, "number": 60 + side, "onValue": 127, "releaseShiftChannels": [side],
         "decks": ["a", "c"] if side == 0 else ["b", "d"]} for side in range(2)]
    result["inputModes"] = [{"channel": 4 + channel, "initial": 0, "numbers": [0, 2, 9, 11, 14, 15, 16],
                             "onValue": 4, "offValue": 1} for channel in range(4)]
    for side in [0, 1]:
        add(result, "shift", side, 32)
        add(result, "shift", side, 32)
        result["inputs"][-1]["shiftChannel"] = side
    for channel, deck in enumerate("abcd"):
        side, pad_channel = channel % 2, channel + 4
        for action, number in [("play", 0), ("cuePreview", 1), ("sync", 2), ("jogTouch", 6)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync"})
            result["inputs"][-1].update(shifted=False, shiftChannel=side)
            if action in {"play", "cuePreview", "sync"}:
                add(result, action, channel, {"play": 4, "cuePreview": 5, "sync": 3}[action], deck=deck)
                result["inputs"][-1].update(shifted=True, shiftChannel=side, releaseOnly=True)
        add(result, "cue", channel, 27, deck=deck, feedback=True)
        add(result, "keylock", channel, 13, deck=deck)
        result["inputs"][-1].update(shifted=True, shiftChannel=side)
        add(result, "jog", channel, 6, "control", "twosComplement", deck)
        result["inputs"][-1].update(argument=1000, shifted=False, shiftChannel=side)
        add(result, "tempo", channel, 9, "control", "paired14Bit", deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=side)
        for action, number in [("gain", 22), ("high", 23), ("mid", 24), ("low", 25), ("filterKnob", 26), ("level", 28)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "load", 15, 2 + channel, deck=deck)
        result["inputs"][-1]["shifted"] = False
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", pad_channel, 20 + slot, deck=deck)
            result["inputs"][-1].update(requiredMode=0, shifted=False, shiftChannel=side)
            add(result, f"hotcue{slot + 1}", pad_channel, 28 + slot, deck=deck)
            result["inputs"][-1].update(requiredMode=0, shifted=True, shiftChannel=side, releaseOnly=True)
        for slot, beats in enumerate([1, 2, 4, 8, 16, 32]):
            for shifted in [False, True]:
                add(result, "toggleFixedLoop", pad_channel, 20 + slot + (8 if shifted else 0), deck=deck)
                result["inputs"][-1].update(argument=beats, requiredMode=16, shifted=shifted, shiftChannel=side)
                if shifted:
                    result["inputs"][-1]["releaseOnly"] = True
        for action, number in [("loopIn", 20), ("loopOut", 21), ("loopEnable", 22), ("loop", 23), ("jumpForward", 24),
                               ("jumpBack", 25), ("loopDown", 26), ("loopUp", 27)]:
            for shifted in [False, True]:
                add(result, action, pad_channel, number + (8 if shifted else 0), deck=deck)
                result["inputs"][-1].update(requiredMode=14, shifted=shifted, shiftChannel=side)
                if shifted:
                    result["inputs"][-1]["releaseOnly"] = True
    add(result, "crossfader", 15, 8, "control")
    add(result, "browse", 15, 0, "control", "signedStep")
    result["inputs"][-1]["shifted"] = False
    add(result, "openGroup", 15, 6)
    result["inputs"][-1]["shifted"] = False
    for output in result["outputs"]:
        output["offValue"] = 0 if output["action"] in {"cueA", "cueB"} else 1
    return [result]

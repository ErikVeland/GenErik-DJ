"""Beatmix 2/4 core facts from the shared factory table and pinned mapping."""
from curated import add, profile
from numark import UPSTREAM

BEATMIX_TABLE = "https://www.reloop.com/media/custom/upload/Reloop-bm2_4_midi_map.pdf"
BEATMIX_REFERENCES = {"Reloop Beatmix 2/4 MK2": {
    "url": BEATMIX_TABLE, "sha256": "a5f64d3521bcfc77f82d7bee80275b7ce42dfc7a7e6097cb00d6a4bb4f00926f",
    "pages": [1, 2, 3, 4],
    "relatedSources": [{"url": UPSTREAM + "Reloop-Beatmix-2-4-MK2-scripts.js",
                        "sha256": "d4373a391b20ffb7f944b9ceba9706df1ce7a1af9ef8568b0a005145775fe652"},
                       {"url": UPSTREAM + "Reloop-Beatmix-2-4-MK2.midi.xml",
                        "sha256": "9ad44392c28b9221126520cf1afb1fa7a379b2974a20cafcdcef5ae7a4bd6832"},
                       {"url": "https://www.reloop.com/reloop-beatmix-2-mk2"}],
    "review": "The manufacturer publishes the shared Beatmix 2/4 MIDI table on its MK2 product page. Its 1/127 jog values and 800-count resolution take precedence over the pinned script's conflicting value-minus-64 handler. Input Play/Sync addresses differ from LED addresses. Four Hot Cues and four fixed-loop pads retain the pinned mapping's native core layout. Separate sample notes remain unmapped. Shift releases rearm normal buttons without firing unsupported actions. Bank reports protect shared tempo pickup and held contacts. Pitch polarity accounts for the source's negative midiPitch assignment and Mixxx rate direction. No software FX modes, long-press eject or fader-start behaviour is copied. The source's delayed state query, complete LED cleanup, remaining modes, routing and physical calibration remain open.",
}}


def beatmix_profiles():
    result = profile("Reloop Beatmix 2/4 MK2", BEATMIX_TABLE)
    result["definition"] = "reviewed:reloop-beatmix-2-4"
    result["aliases"] = ["Reloop Beatmix 2/4 MK2", "Beatmix 2/4 MK2"] + [
        prefix + name for name in ["Beatmix 2", "Beatmix 4", "Beatmix 2 MK2", "Beatmix 4 MK2"]
        for prefix in ["", "Reloop "]]
    result["scope"] = "Automatic native core MIDI for the documented Beatmix 2/4 and MK2 family. Four deck targets retain the app opt-in. The pinned native layout has four Hot Cues and four fixed-loop pads. Bank pickup, Shift releases, 800-count jogs and separate LED addresses have fixtures. Remaining modes, delayed state query, full cleanup, routing and physical calibration stay open."
    result["bankChanges"] = [{"channel": channel, "number": 40, "onValue": 127,
                              "decks": ["a", "c"] if channel in {1, 3} else ["b", "d"]}
                             for channel in range(1, 5)]
    for side in [1, 2]:
        add(result, "shift", side, 32)
        result["inputs"][-1]["shiftChannel"] = side
    for channel, deck in enumerate("abcd", 1):
        side = 1 if channel in {1, 3} else 2
        for action, number in [("play", 36), ("cuePreview", 35), ("sync", 33), ("load", 80), ("cue", 82)]:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=side)
            shifted = {"load": 64, "cue": 66}.get(action, number + 64)
            add(result, action, channel, shifted, deck=deck)
            result["inputs"][-1].update(shifted=True, shiftChannel=side, releaseOnly=True)
        for number in [63, 127]:
            add(result, "jogTouch", channel, number, deck=deck)
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", channel, slot, deck=deck, feedback=True)
            result["inputs"][-1].update(shifted=False, shiftChannel=side)
            result["outputs"][-1]["onValue"] = 85
            add(result, f"hotcue{slot + 1}", channel, slot + 8, deck=deck)
            result["inputs"][-1].update(shifted=True, shiftChannel=side, releaseOnly=True)
        for slot, beats in enumerate([1, 2, 4, 8], 4):
            add(result, "toggleFixedLoop", channel, slot, deck=deck)
            result["inputs"][-1].update(argument=beats, shifted=False, shiftChannel=side)
            add(result, "toggleFixedLoop", channel, slot + 8, deck=deck)
            result["inputs"][-1].update(argument=beats, shifted=True, shiftChannel=side, releaseOnly=True)
        for action, number in [("gain", 16), ("high", 17), ("mid", 18), ("low", 19), ("level", 20)]:
            add(result, action, channel, number, "control", "centreDetent" if action in {"high", "mid", "low"} else "absolute", deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=side)
        add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=side)
        add(result, "jog", channel, 96, "control", "twosComplement", deck)
        result["inputs"][-1].update(argument=800, shifted=False, shiftChannel=side)
        for action, number in [("play", 35), ("sync", 32), ("cue", 82)]:
            result["outputs"].append({"action": action + ("A" if deck in "ac" else "B"),
                                      "targetDeck": deck, "kind": "note", "channel": channel, "number": number,
                                      "onValue": 127, "offValue": 0, "offUsesNoteOn": True})
    add(result, "crossfader", 5, 47, "control", "centreDetent")
    for action, number in [("master", 0), ("monitor", 1), ("cueMix", 2)]:
        add(result, action, 5, number, "control")
    add(result, "browse", 5, 96, "control", "twosComplement")
    add(result, "openGroup", 5, 9)
    return [result]

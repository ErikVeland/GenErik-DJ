"""NEON accessory facts from the manufacturer's MIDI map and guide."""
from curated import add, profile

NEON_REFERENCES = {"Reloop NEON": {
    "url": "https://www.reloop.com/media/custom/upload/Reloop-NEON_MIDI-Map.pdf",
    "sha256": "41226da60587823b7eb1ee094180d1391a07006c688423f9196a9b2e61ed4059", "pages": [4, 7, 8],
    "relatedSources": [{"url": "https://www.reloop.com/media/custom/upload/Reloop-232520_Reloop_IM.pdf",
                        "sha256": "95aeb6d508b13d051fd1df236621fe42b7f279e00069d4cf8ddcea3e73910699", "pages": [6, 7]},
                       {"url": "https://www.reloop.com/media/custom/upload/Reloop-Reloop_neon_quick_start_guide.pdf",
                        "sha256": "14f51859b621e00fcf9742fa23059fc8a92ccc1a855b007a04f288417bc74d84", "pages": [5]}],
    "review": "The factory table gives distinct channel/note ranges for each pad mode. Four targets use channels 7-10 and first-layer cue notes 16-23. R483 adds32 native clear inputs at shifted first-layer notes48-55 on the same four deck channels. The own quick-start guide printed7 explicitly qualifies Shift plus Cue as delete. Existing negative activation guards remain, and32 inverse negative aliases rearm clearing when Shift changes before release. Second-layer Hot Cue is Hot Flip and remains unmapped. Manual Loop pads use notes 120/124/125/126 for Loop on/off, In, Out and Reloop/Exit. The Serato guide confirms that the first manual pad toggles the loop. Active-loop boundary editing remains unmapped. Their shifted releases use notes 88/92/93/94. The setup packet enables the hardware's C/D buttons without changing app deck availability. Deck reports reset pad edges for the shared surface. C/D Sync entries conflict with Slip in the factory table. Common encoder and Load messages also occur in Sampler mode, so they remain unmapped until mode guards can retain their context. Stored loops, rolls, sampler, slicer, Flip, DVS switching, pressure, pad colours and full cleanup remain open.",
}}


def neon_profiles():
    result = profile("Reloop NEON", NEON_REFERENCES["Reloop NEON"]["url"])
    result["role"] = "accessory"
    result["scope"] = "Automatic native accessory core with eight Hot Cues, dedicated clears, paired negative aliases and basic Manual Loop pads on four targets. Other modes, shared encoders, Load, Sync, colours and full cleanup remain open."
    result["startup"] = [[0xF0, 10, 0, 0xF7]]
    result["bankChanges"] = [{"channel": channel, "number": 1, "onValue": 127, "decks": list("abcd")}
                             for channel in range(3, 7)]
    for index, deck in enumerate("abcd"):
        channel = index + 7
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", channel, 16 + slot, deck=deck)
            add(result, f"hotcue{slot + 1}", channel, 48 + slot, deck=deck)
            result["inputs"][-1].update(shifted=True, releaseOnly=True)
        for action, number in [("loop", 120), ("loopIn", 124), ("loopOut", 125), ("reloop", 126)]:
            add(result, action, channel, number, deck=deck)
            add(result, action, channel, number - 32, deck=deck)
            result["inputs"][-1].update(shifted=True, releaseOnly=True)
    for index, deck in enumerate("abcd"):
        for slot in range(8):
            add(result, f"clearHotcue{slot + 1}", index + 7, 48 + slot, deck=deck)
            result["inputs"].append({**result["inputs"][-1], "number": 16 + slot, "releaseOnly": True})
    return [result]

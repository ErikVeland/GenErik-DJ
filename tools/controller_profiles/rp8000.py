"""Original RP-8000 MIDI accessory facts from the factory manual and mappings."""
from curated import add, profile

RP8000_REFERENCES = {"Reloop RP-8000": {
    "url": "https://www.reloop.com/media/catalog/product/pdf/2/2/8/228337_Reloop_IM.pdf",
    "sha256": "8eb0b60ccb1c6d10ac93577b129a938bfbac889fdb461902d354afc8d19b78dd", "pages": [10, 11],
    "relatedSources": [
        {"url": "https://www.reloop.com/media/custom/upload/228337/228337%20Mapping%206%202D%20ScratchLive%202.5%2B%20FW%200.06%2B%20Uni.zip",
         "sha256": "69089f0374ff09494e1ba94a4900acfc27f51dec06cd4c58b9526b58661731d3",
         "member": "Reloop_RP8000_V6.xml", "memberSHA256": "dc882b34fcc3992704cea1595d3838374845787a1d7849334c4f493757dbc067"},
        {"url": "https://www.reloop.com/media/custom/upload/228337/228337%20Mapping%201%202S%20TraktorPro%202.6%2B%20FW%200.06%2B%20Uni.zip",
         "sha256": "f506e3a429e5e66bac7cf293974e46ee73defd049bb9b010b0edc09201feb29d",
         "member": "RP-8000_Traktor_PRO_V1.tsi", "memberSHA256": "8023682e8466d5706c4c2361c024da5890eeb4a88229b54a12e642b623aea3fe"}],
    "review": "The original factory table gives eight cue inputs, distinct Loop/Sample/User address ranges and centre-64 Trax CC64. The published Scratch Live mapping gives fixed loop sizes and 127/0 cue lights for the first five cues, including their alternate delete addresses. The Traktor mapping confirms Ch01/Ch02 MIDI bindings. Hardware CH-1 through CH-4 select A/B/C/D. TT Link assigns those channels automatically. Independently connected units on the same channel need different hardware channel selections. Native pads provide eight cues and fixed loops from 1/4 to 32 beats. Held mode-button release aliases only rearm their pads. Optional analogue/motor controls, User/Sample/Slicer pages, remaining cue lights, displays, full cleanup and DVS/audio routing remain open. MK2 and Straight variants do not inherit this protocol.",
}}


def rp8000_profiles():
    result = profile("Reloop RP-8000", RP8000_REFERENCES["Reloop RP-8000"]["url"])
    result["role"] = "accessory"
    result["scope"] = "Automatic original-model MIDI accessory core with eight cues, fixed loops and browsing. Hardware CH-1–4 or automatic TT Link selects the deck. Independent units need distinct channel selections. DVS, motor controls, displays and audio routing remain open."
    for channel, deck in enumerate("abcd"):
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", channel, slot, deck=deck, feedback=slot < 5)
            add(result, f"hotcue{slot + 1}", channel, 32 + slot, deck=deck)
            result["inputs"][-1].update(shifted=True, releaseOnly=True)
            if slot < 5:
                result["outputs"].append({"action": f"hotcue{slot + 1}" + ("A" if deck in "ac" else "B"),
                                          "kind": "note", "channel": channel, "number": 32 + slot,
                                          "onValue": 127, "offValue": 0, "offUsesNoteOn": True, "targetDeck": deck})
        for slot, beats in enumerate([0.25, 0.5, 1, 2, 4, 8, 16, 32]):
            add(result, "toggleFixedLoop", channel, 8 + slot, deck=deck)
            result["inputs"][-1]["argument"] = beats
            add(result, "toggleFixedLoop", channel, 40 + slot, deck=deck)
            result["inputs"][-1].update(argument=beats, shifted=True, releaseOnly=True)
        add(result, "load", channel, 64, deck=deck)
        add(result, "browse", channel, 64, "control", "binaryOffset")
    return [result]

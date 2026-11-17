"""Dicer accessory core facts from the pinned XML and reset command."""
from curated import add, profile
from numark import UPSTREAM

DICER_SOURCES = [
    ("Novation Dicer.midi.xml", "1ebe1d435a086e02e819b57f2ca6e61993269ed9971c5748f01726189baf5f46"),
    ("Novation-Dicer-scripts.js", "18846f299c05e02b305fce81f72cedc1deaaa245cc06d3920d96d6bbedd58aa3"),
]
DICER_REFERENCES = {"Novation Dicer": {
    "url": UPSTREAM + "Novation%20Dicer.midi.xml", "sha256": DICER_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in DICER_SOURCES],
    "review": "The native accessory recipe retains the stored ID and five Hot Cues on channels 10/13. Alternate clear-note releases rearm those pads without firing or deleting cues. Shifted green-page notes select native fixed loop lengths. Orange-page Cue uses native held preview and Load retains the XML address. The source reset packet enters startup and shutdown. No downloaded script runs. The source warns that its custom roll implementation erases loops, drifts and can pause audio. That roll code, transformer timers, forced gain changes and rewind effects are not copied. Default green-page rolls, extra effects, full lights and physical acceptance remain open.",
}}


def dicer_profiles():
    result = profile("Novation Dicer", DICER_REFERENCES["Novation Dicer"]["url"])
    result["aliases"] = ["Novation Dicer", "Dicer Novation Dicer", "Novation Dicers", "Dicer"]
    result["role"] = "accessory"
    result["definition"] = "reviewed:novation-dicer"
    result["scope"] = "Automatic native accessory core with five Hot Cues, shifted fixed-loop pads, held Cue and Load per deck. Default roll pads, extra effects, full lights and physical acceptance remain open."
    result["startup"] = [[0xBA, 0, 0]]
    result["shutdown"] = [[0xBA, 0, 0]]
    for index, deck in enumerate("ab"):
        cue_channel, loop_channel, orange_channel = 10 + 3 * index, 11 + 3 * index, 12 + 3 * index
        for slot in range(5):
            add(result, f"hotcue{slot + 1}", cue_channel, 60 + slot, deck=deck, feedback=True)
            result["outputs"][-1]["onValue"] = 14
            add(result, f"hotcue{slot + 1}", cue_channel, 65 + slot, deck=deck)
            result["inputs"][-1].update(shifted=True, releaseOnly=True)
            result["outputs"].append({"action": f"hotcue{slot + 1}" + ("A" if deck == "a" else "B"),
                                      "targetDeck": deck, "kind": "note", "channel": cue_channel, "number": 65 + slot,
                                      "onValue": 14, "offValue": 0, "offUsesNoteOn": True})
        for slot, beats in enumerate([1, 2, 4, 8, 16], 65):
            add(result, "toggleFixedLoop", loop_channel, slot, deck=deck)
            result["inputs"][-1]["argument"] = beats
        add(result, "cuePreview", orange_channel, 61, deck=deck)
        add(result, "load", orange_channel, 67, deck=deck)
        for action, number in [("browsePreviousGroup", 65), ("browsePrevious", 66), ("browseNext", 68), ("browseNextGroup", 69)]:
            add(result, action, orange_channel, number)
    return [result]

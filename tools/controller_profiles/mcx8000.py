"""MCX8000 core from the factory table and Denon-assisted PCDJ source."""
from curated import add, profile

MCX_URL = "https://cdn.inmusicbrands.com/denondj/MCX8000/Denon_DJ_MCX8000_MIDI_Command_List_v1.0.pdf"
MCX_SHA = "be117c5df66a5fcea5cc9a7cd97dc10115b8ca5feae63dcaf6f3410370248eef"
MCX_PCDJ_URL = "https://pcdj.com/downloads/djcontrollers/Denon__MCX8000.zip"
MCX_PCDJ_SOURCES = [
    ("Denon-MCX8000.zip", "5cb14e72f1abc0d3cef703e8052838e2d70e1cabd4495637fdb73d1ca2760149"),
    ("Denon__MCX8000.js", "9cdb080631fffab5b4f507b78be38a7e7302cf84dffdf47947540bd93aa23f1c"),
]
MCX_REFERENCES = {"Denon DJ MCX8000": {
    "url": MCX_URL, "sha256": MCX_SHA, "pages": [1, 2, 3],
    "relatedSources": [{"url": MCX_PCDJ_URL, "sha256": MCX_PCDJ_SOURCES[0][1]},
                       {"url": "https://pcdj.com/dj-controllers-denon-dj-mcx8000-is-dex-3-supported/"},
                       {"url": "https://support.denondj.com/en/support/solutions/articles/69000809737-denon-dj-mcx8000-frequently-asked-questions"},
                       {"url": "https://support.denondj.com/en/support/solutions/articles/69000866635-mcx8000-macos-catalina-driver"}],
    "review": "Factory channels and normal/shifted addresses retain four native targets. Independent Denon-assisted PCDJ source now establishes inverted centre64 platterCC6, touchNote6, inverted coarse pitchCC9 and both global browser encodersCC0/68 with low-half forward direction. Source64 becomes native neutral. The source readsCC9 as a coarse position despite the old factoryLSB label;CC119 and high-resolution pairing remain unmapped. Source Note8 deck banks release held Cue/contact and cached controls on the same physical side. Source button lamps use127/1, PFL127/0, and native Sync feedback is steady rather than beat flashes. Startup selects A/B, initialises the24 reviewed lamps and four fixed native Vinyl lights; shutdown restores dim button/Vinyl and off PFL states. Source software Vinyl toggle, Shift search, pads/shared modes, FX, full meters/rings/screens and complete lifecycle remain open. Shared pad setup/feedback is not copied. Normal Play/Keylock now have release-only shifted aliases, alongside Cue/bend aliases; unsupported positive shifted presses cannot trigger normal actions. Denon describes generic MIDI and current macOS driver-free access; automatic input selection applies when the port is visible in PC mode. Direct iPad attachment and audio routing remain unverified. No output audio assignment or downloaded code is executed.",
}}


def mcx_profiles():
    result = profile("Denon DJ MCX8000", MCX_URL)
    result["aliases"] = ["Denon DJ MCX8000", "Denon MCX8000", "MCX8000"]
    result["autoSelect"] = True
    result["hardwareMode"] = "PC input selector. Automatic visible MIDI-port selection with native fixed touch scratch. Direct iPad attachment and audio routing remain unqualified."
    result["scope"] = "Automatic four-target MIDI core with fixed native touch/jog, coarse pitch, both browsers, bank-release ownership, held Cue/bend, mixer/loops and source-valued steady lights. Pads, high-resolution pitch, full modes/screens, routing and physical acceptance remain open."
    result["gaps"] = ["Source-specific Shift input/search, bank/source-selector audio ownership, shared pad modes, high-resolution pitch pairing, FX, complete feedback/meters/rings/screens, full lifecycle, direct iPad attachment/audio routing and physical acceptance remain open. Native fixed touch keeps default unverified calibration; source7200 is an app-specific scale. CoarseCC9 pitch is source-backed;CC119 remains ignored."]
    result["bankChanges"] = [{"channel": channel, "number": 8, "onValue": 127, "releaseShiftChannels": [],
                              "decks": ["a", "c"] if channel % 2 == 0 else ["b", "d"]} for channel in range(4)]
    for channel, deck in enumerate("abcd"):
        for action, number in [("play", 0), ("cuePreview", 1), ("sync", 2), ("syncDisable", 3),
                               ("keylock", 13), ("cue", 27), ("pitchBendUp", 11), ("pitchBendDown", 12)]:
            add(result, action, channel, number, deck=deck,
                feedback=action in {"play", "cuePreview", "sync", "keylock", "cue"})
        for action, number in [("play", 4), ("cuePreview", 5), ("keylock", 41), ("pitchBendUp", 43), ("pitchBendDown", 44)]:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        add(result, "jogTouch", channel, 6, deck=deck)
        add(result, "jog", channel, 6, "control", "binaryOffset", deck)
        result["inputs"][-1]["inverted"] = True
        add(result, "tempo", channel, 9, "control", deck=deck)
        result["inputs"][-1]["inverted"] = True
        add(result, "load", 15, 2 + channel, deck=deck)
        for action, number in [("loop", 50), ("loopDown", 52), ("loopUp", 53),
                               ("reloop", 51), ("loopIn", 56), ("loopOut", 57)]:
            add(result, action, channel + 4, number, deck=deck, feedback=action == "loop")
        for action, number in [("gain", 22), ("high", 23), ("mid", 24), ("low", 25),
                               ("filterKnob", 26), ("level", 28)]:
            add(result, action, channel, number, "control", deck=deck)
    add(result, "crossfader", 15, 8, "control")
    for number in [7, 6]:
        add(result, "openGroup", 15, number)
    for number in [0, 68]:
        add(result, "browse", 15, number, "control", "binaryDirection")
        result["inputs"][-1]["inverted"] = True
    for output in result["outputs"]:
        output["offValue"] = 0 if output["action"] in {"cueA", "cueB"} else 1
    clear = [[0x90 + row["channel"], row["number"], row["offValue"]] for row in result["outputs"]]
    result["startup"] = [[0x90, 8, 127], [0x91, 8, 127]] + clear + [[0x90 + ch, 7, 127] for ch in range(4)]
    result["shutdown"] = clear + [[0x90 + ch, 7, 1] for ch in range(4)]
    return [result]

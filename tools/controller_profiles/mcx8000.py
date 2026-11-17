"""Manual MCX8000 controls from Denon's factory command list."""
from curated import add, profile

MCX_URL = "https://cdn.inmusicbrands.com/denondj/MCX8000/Denon_DJ_MCX8000_MIDI_Command_List_v1.0.pdf"
MCX_SHA = "be117c5df66a5fcea5cc9a7cd97dc10115b8ca5feae63dcaf6f3410370248eef"
MCX_REFERENCES = {"Denon DJ MCX8000": {
    "url": MCX_URL, "sha256": MCX_SHA, "pages": [1, 2, 3],
    "review": "Factory-addressed manual transport/mixer/loop subset only. Four explicit deck channels and separate other-function channels retain native deck targets. Shift has different command addresses, so normal Cue/bend ownership accepts only releases at the corresponding shifted address. Positive shifted reports cannot trigger normal actions. The factory calls pitch CC9 LSB and119 MSB, while related working Denon mappings reverse factory labels. No sibling encoding, pitch polarity, Shift wire, browser/jog values, pad mode, application-connect packet, display or iPad connection route is inferred. Same-pad addresses span all hardware modes, so pads stay inactive. Feedback echoes reviewed normal button addresses. Manual apply does not activate the input or run lifecycle. Automatic selection, physical acceptance and complete parity remain open.",
}}


def mcx_profiles():
    result = profile("Denon DJ MCX8000", MCX_URL)
    result["aliases"] = ["Denon DJ MCX8000", "Denon MCX8000", "MCX8000"]
    result["autoSelect"] = False
    result["hardwareMode"] = "PC input selector. Manual MIDI transport/mixer subset. Direct iPad connection remains unqualified."
    result["scope"] = "Manual four-target transport, held Cue/bend, direct Load, mixer/filter and loops. Encoders, pitch, pads, screens, connection/audio route and automatic lifecycle remain open."
    result["gaps"] = ["Jog/browser values, pitch byte order/polarity, Shift input, bank/source-selector ownership, pads and all modes, FX, meters/rings/screens, full feedback/lifecycle, direct iPad connection/audio and physical acceptance remain open. Manual apply does not activate the input or run lifecycle. No automatic support is claimed."]
    for channel, deck in enumerate("abcd"):
        for action, number in [("play", 0), ("cuePreview", 1), ("sync", 2), ("syncDisable", 3),
                               ("keylock", 13), ("cue", 27), ("pitchBendUp", 11), ("pitchBendDown", 12)]:
            add(result, action, channel, number, deck=deck,
                feedback=action in {"play", "cuePreview", "sync", "keylock", "cue"})
        for action, number in [("cuePreview", 5), ("pitchBendUp", 43), ("pitchBendDown", 44)]:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
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
    result["startup"] = [[0x90 + row["channel"], row["number"], 0] for row in result["outputs"]]
    result["shutdown"] = [row.copy() for row in result["startup"]]
    return [result]

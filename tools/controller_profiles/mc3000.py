"""MC3000 manual core corrected against the original Denon MIDI tables."""
from curated import add, profile
from mc6000 import feedback
from numark import UPSTREAM

MC3000_GUIDE = "https://cdn.inmusicbrands.com/denondj/legacy/mc3000/MC3000EM_ENG_IM_v00.pdf"
MC3000_SOURCES = [
    ("Denon MC3000.midi.xml", "0cf80d155f2573c4b01467649a7fbb1de85d2586f6aff4fb90f91f3bf75601bd"),
    ("Denon-MC3000-scripts.js", "fb06584b939abc39c46961aa0e67d1e951c0aaf82143b3bdad164627a70b0352"),
]
MC3000_REFERENCES = {"Denon MC3000": {
    "url": MC3000_GUIDE, "sha256": "8282c1eec2f4e597491f700b9163831e626e88ecfae87ab48782a478a1e38ce8", "pages": [20, 21, 22, 23, 26, 27],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in MC3000_SOURCES],
    "review": "Factory MIDI table and pinned XML establish A/C/B/D channel order and per-deck mixer addresses. Factory64-on/0-off buttons use native held Cue/bend; jog zero is outside the documented movement range and stays stationary. Native jog calibration uses the shared default, not the old script's arbitrary100-count330RPM combination. Full pitch messages retain centre pickup and inverse source rate. Physical-side Shift identity spans its two deck channels; unsupported alternate presses stay inactive while old holds release. Factory eight cue addresses, normal loop toggle/size, source compound In and Out/Exit use native contracts on each documented deck channel. Native Play/Cue/Sync/Key/loop/cue feedback uses factory74-on/75-off ID triggers; PFL uses80/81 and separate IDs. Factory states master/headphone/microphone gains are hardware controls: old script CC88..92 assignments actually target FX knobs and are removed. Software gain/balance and arbitrary startup resets are not inferred. Shared Load A/C and B/D need qualified target ownership and cold-state recovery. Automatic selection, lifecycle, bank-contact cleanup, audio routing, source modes/LED animations, Shift search, complete feedback, calibration and physical acceptance remain open.",
}}


def mc3000_profiles():
    result = profile("Denon MC3000", MC3000_GUIDE)
    result["aliases"] += ["Denon DJ MC3000", "Denon MC3000 v0.995"]
    result.update(autoSelect=False, hardwareMode="Manual profile; default MIDI channels1–4. Shared Load target and cold-state recovery remain unqualified.", scope="Manual four-channel MC3000 native mixer/transport core with held Cue/bend, full pitch, eight cues, loops and factory trigger feedback. Shared Load, lifecycle, bank-contact cleanup, full modes/routing, calibration and physical acceptance remain open.", gaps=["Qualify shared Load target ownership and cold-state recovery before automatic selection.", "Manual profile selection does not run factory lifecycle or bank-change metadata. Full cleanup, audio routing and physical acceptance remain open."])
    for channel, deck in enumerate("acbd"):
        side = channel // 2
        add(result, "shift", channel, 96 + side)
        result["inputs"][-1].update(shiftChannel=side, shiftInput=side)
        start = len(result["inputs"])
        for action, number in [("play", 67), ("cuePreview", 66), ("sync", 107), ("keylock", 6),
                               ("pitchBendDown", 13), ("pitchBendUp", 12), ("loop", 29),
                               ("loopDown", 105), ("loopUp", 106), ("loopDisable", 55), ("loopIn", 55), ("loopOutOrExit", 57)]:
            add(result, action, channel, number, deck=deck)
        add(result, "jogTouch", channel, 81, encoding="touchGate", deck=deck)
        add(result, "jog", channel, 81, "control", "denonJog", deck)
        for slot, number in enumerate([23, 24, 25, 32, 72, 73, 74, 75]):
            add(result, f"hotcue{slot + 1}", channel, number, deck=deck)
        for item in result["inputs"][start:]:
            item.update(shifted=False, shiftChannel=side)
        add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1]["inverted"] = True
        for action, numbers in {"gain": [1, 7, 12, 17], "high": [2, 8, 13, 18], "mid": [3, 9, 14, 19],
                                "low": [4, 10, 15, 20], "level": [5, 11, 16, 21]}.items():
            add(result, action, channel, numbers[channel], "control", deck=deck)
        add(result, "cue", channel, [1, 2, 5, 7][channel], deck=deck)
        for action, identifier in [("play", 39), ("cuePreview", 38), ("sync", 9), ("keylock", 8), ("loop", 43)]:
            feedback(result, action, channel, identifier, deck)
        for slot, identifier in enumerate([17, 19, 21, 23, 48, 50, 52, 54]):
            feedback(result, f"hotcue{slot + 1}", channel, identifier, deck)
        feedback(result, "cue", channel, [69, 75, 81, 87][channel], deck, regular=True)
    add(result, "crossfader", 0, 22, "control")
    add(result, "browse", 0, 84, "control", "zeroForward")
    result["inputs"][-1]["shifted"] = False
    for action, number in [("browsePreviousGroup", 48), ("browseNextGroup", 41)]:
        add(result, action, 0, number)
    return [result]

"""P32 A/B core using the pinned layout, exact encoder steps and factory audio."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

P32_GUIDE = "https://ts.hercules.com/download/sound/manuals/P32DJ/EN_HERCULES_P32_DJ_User_Manual.pdf"
P32_TABLE = "https://www.scribd.com/document/467254251/Hercules-P32-DJ-MIDI-Command-List-rev1-0"
P32_ARCHIVE = "https://ts.hercules.com/download/sound/manuals/P32DJ/Hercules_P32_DJ_MIDI_Command_List.zip"
P32_SOURCES = [
    ("Hercules P32 DJ.midi.xml", "ecb129e3912c7efc9cf3742e6e5b5ccd3756a2a63659816c5a3db1bfedfa9ac3"),
    ("Hercules-P32-scripts.js", "3067820bf96457abfbcd494b044d2b046a2d42560804f3dd824bfa89111b167b"),
]
P32_REFERENCES = {"Hercules P32 DJ": {
    "url": UPSTREAM + P32_SOURCES[0][0].replace(" ", "%20"), "sha256": P32_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name, "sha256": digest} for name, digest in P32_SOURCES[1:]] + [
        {"url": P32_GUIDE, "sha256": "fe1e525aa5d8583a34d542bfe8af99fd6cd349ce690c69dab922296379f339ff", "pages": [4, 5, 10, 11]}, {"url": P32_TABLE}, {"url": P32_ARCHIVE}],
    "review": "Pinned XML/script qualify fixed A/B channel1/2 core with Shift channels4/5, source top-first cue order, mirrored loop/tempo encoders and software assignments. Native direction-step metadata preserves source rate changes0.01 as inverse normalised0.005 steps and shifted browser cue-mix changes0.1 as native0.05 steps, independent of report magnitude. Factory signed64-negative boundary replaces source64-forward edge. Queued events accumulate and clamp through native value ownership. Native physical-side Shift retains alternate Cue/bend releases and button rearming. Only the first eight source cues per deck are implemented, preserving physical top-two-row addresses. Remaining eight slots per side stay inactive. Manual loop pads, native loop toggle/encoder, tempo reset and held bend use shared contracts. No software deck toggle is inferred from Shift+Slip: C/D remain open. Native transport, PFL, cue/bend/loop pad feedback retains source values and explicit normal/Shift outputs; PFL stays normal-only. Encoder buttons have no inferred LEDs. Startup only sends the pinned analogue query; shutdown clears owned outputs, replacing594 source note clears. Factory guide confirms class-compliant USB and default master1/2/headphones3/4. Hardware headphone gain is not duplicated. Full pads/modes, FX/samplers/Slip/record, seven-segment displays, cleanup, calibration and physical acceptance remain open. The factory MIDI archive returned403; its readable factory mirror is cross-checked against pinned sources.",
}}


def p32_profiles():
    result = profile("Hercules P32 DJ", P32_REFERENCES["Hercules P32 DJ"]["url"])
    result["aliases"] += ["Hercules P32DJ", "P32DJ"]
    result.update(audioOutput="masterAndHeadphones", scope="Automatic P32 A/B core with exact source tempo/cue-blend steps, native held Cue/bend, top eight cues per side, manual loops, mixer and normal/Shift feedback. Remaining pads, C/D switching, full modes/displays and physical acceptance remain open.")
    for side, deck in enumerate("ab"):
        channel = side + 1
        add(result, "shift", channel, 7)
        result["inputs"][-1].update(shiftChannel=side, shiftInput=side)
        def button(action, number, argument=None, both=False):
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=side)
            if argument is not None:
                result["inputs"][-1]["argument"] = argument
            alternate = deepcopy(result["inputs"][-1])
            alternate.update(channel=channel + 3, shifted=True)
            if not both:
                alternate["releaseOnly"] = True
            result["inputs"].append(alternate)
        for action, number in [("play", 10), ("cuePreview", 9), ("sync", 8), ("cue", 16), ("load", 15),
                               ("loop", 1), ("loopIn", 80), ("loopOut", 81), ("loop", 82)]:
            button(action, number)
        for action, number in [("pitchBendDown", 68), ("pitchBendUp", 69)]:
            button(action, number, both=True)
        cue_numbers = [96, 97, 98, 99, 92, 93, 94, 95]
        for slot, number in enumerate(cue_numbers):
            button(f"hotcue{slot + 1}", number)
        for wire in [channel, channel + 3]:
            for action, number in [("level", 1), ("low", 2), ("mid", 3), ("high", 4)]:
                add(result, action, wire, number, "control", deck=deck)
        add(result, "tempo", channel, 5, "control", "twosComplement", deck)
        result["inputs"][-1].update(inverted=True, directionStep=0.005, shifted=False, shiftChannel=side)
        button("tempoReset", 2)
        add(result, "loopSize", channel, 10, "control", "twosComplement", deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=side)
        feedback = [("play", 10, 127, 0), ("cuePreview", 9, 127, 0), ("sync", 8, 127, 0),
                    ("loop", 82, 125, 126), ("pitchBendDown", 68, 125, 127), ("pitchBendUp", 69, 125, 127)]
        feedback += [(f"hotcue{slot + 1}", number, 125, 0) for slot, number in enumerate(cue_numbers)]
        for action, number, on, off in feedback:
            for wire in [channel, channel + 3]:
                result["outputs"].append({"action": action + deck.upper(), "targetDeck": deck, "kind": "note",
                                          "channel": wire, "number": number, "onValue": on, "offValue": off, "offUsesNoteOn": True})
        result["outputs"].append({"action": "cue" + deck.upper(), "targetDeck": deck, "kind": "note",
                                  "channel": channel, "number": 16, "onValue": 127, "offValue": 0, "offUsesNoteOn": True})
    add(result, "crossfader", 0, 1, "control")
    add(result, "browse", 0, 2, "control", "twosComplement")
    add(result, "cueMix", 3, 2, "control", "twosComplement")
    result["inputs"][-1]["directionStep"] = 0.05
    result["startup"] = [[0xB0, 127, 127]]
    result["shutdown"] = [[0x90 + r["channel"], r["number"], 0] for r in result["outputs"]]
    return [result]

"""DJC.4 default channel bank with explicit Shift releases and native controls."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

DJC4_MANUAL = "https://manual.mixxx.org/2.5/en/hardware/controllers/stanton_djc_4"
DJC4_FACTORY = "https://manualzz.com/doc/4156007/stanton-djc.4-controller-user-manual"
DJC4_TABLE = "https://www.scribd.com/document/361336662/DJC-4ManualV1-1"
DJC4_SOURCES = [
    ("Stanton-DJC-4.midi.xml", "e7b4cca84354be02d3c627054e187d7e0b66cbfb51bbae6dced9b2b339c97f26"),
    ("Stanton-DJC-4-scripts.js", "c0615669dd9f46cf92f46066ec00142d9b7e42dccb9a249abebcbc57bccb54d4"),
]
DJC4_REFERENCES = {"Stanton DJC.4": {
    "url": UPSTREAM + DJC4_SOURCES[0][0], "sha256": DJC4_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name, "sha256": digest} for name, digest in DJC4_SOURCES[1:]] + [{"url": url} for url in [DJC4_MANUAL, DJC4_FACTORY, DJC4_TABLE]],
    "review": "Pinned working XML/script qualify four deck channels, source128-count centre64 jogs and explicit normal/Shift touch addresses. Native fixed scratch omits source playing/paused RPM changes and undefined stripSearchScaling. Physical Shift stays source-local; alternate releases retain Cue/contact/bend ownership and rearm buttons. Factory guide confirms default channels1..4/HOLD Shift and distinct shifted bend releases69/70. Deck notes17/67 release physical-side contacts and rearm pickup without dropping global Shift. Full pitch, five mixer controls, shifted filter and separate shifted Cue Set use native contracts. Loop buttons keep native current-size enable, toggle, In/Out and halve/double; source held adjustment, loop movement, roll, Cue-stop and Shift fast search remain open. Strict65/63 browsing omits source page/focus semantics. Native transport/PFL/key/loop and four cue LEDs per deck use on127/off0, with fixed Scratch indicators and48 lifecycle messages. Full factory reset exceeds the lifecycle budget and is not copied. Source master/microphone are hardware gain, not duplicated in software. The mapping author documents master1/2/headphones3/4. Source modes, alternate channel banks, EQ kill, FX/samplers, remaining feedback, calibration and physical acceptance remain open.",
}}


def djc4_profiles():
    result = profile("Stanton DJC.4", DJC4_REFERENCES["Stanton DJC.4"]["url"])
    result["aliases"] += ["DJC-4", "Stanton DJC-4"]
    result.update(audioOutput="masterAndHeadphones", hardwareMode="Factory MIDI channels1–4 and HOLD Shift. Other channel banks/custom settings require separate profiles.", scope="Automatic default-bank four-deck core with128-count fixed scratch, physical Shift/bank cleanup, native held Cue/bend, four cues, loops, full pitch, mixer/filter and native LEDs. C/D require app opt-in. Full modes/feedback, calibration and physical acceptance remain open.")
    add(result, "shift", 0, 45)
    result["bankChanges"] = [{"channel": ch, "number": number, "onValue": 127,
                              "decks": list("ac" if ch % 2 == 0 else "bd"), "releaseShiftChannels": []}
                             for ch in range(4) for number in [17, 67]]
    for channel, deck in enumerate("abcd"):
        def button(action, number, alternate, shifted=False):
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1]["shifted"] = shifted
            release = deepcopy(result["inputs"][-1])
            release.update(number=alternate, shifted=not shifted, releaseOnly=True)
            result["inputs"].append(release)
        for action, number in [("play", 24), ("cuePreview", 23), ("sync", 18), ("keylock", 16),
                               ("cue", 28), ("load", 34 if channel % 2 == 0 else 35),
                               ("pitchBendDown", 19), ("pitchBendUp", 20), ("loopIn", 4), ("loopOut", 5),
                               ("loop", 6), ("loopDown", 2), ("loopUp", 3), ("loopEnable", 1)]:
            button(action, number, number + 50)
        button("jogTouch", 38, 88)
        result["inputs"][-2]["encoding"] = result["inputs"][-1]["encoding"] = "fullVelocityGate"
        add(result, "jog", channel, 2, "control", "binaryOffset", deck)
        result["inputs"][-1].update(argument=128, shifted=False)
        for slot in range(4):
            button(f"hotcue{slot + 1}", 8 + slot, 58 + slot)
        add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1]["inverted"] = True
        for action, number in [("gain", 3), ("high", 4), ("mid", 5), ("low", 6), ("level", 7)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "filterKnob", channel, 36, "control", deck=deck)
        result["inputs"][-1]["shifted"] = True
        button("cueSet", 74, 24, shifted=True)
        feedback = [("play", 24), ("cuePreview", 23), ("sync", 18), ("keylock", 16), ("cue", 28), ("loop", 6)]
        feedback += [(f"hotcue{slot + 1}", 8 + slot) for slot in range(4)]
        for action, number in feedback:
            result["outputs"].append({"action": action + ("A" if deck in "ac" else "B"), "targetDeck": deck,
                                      "kind": "note", "channel": channel, "number": number,
                                      "onValue": 127, "offValue": 0, "offUsesNoteOn": True})
        result["startup"].append([0x90 + channel, 21, 127])
        result["shutdown"].append([0x90 + channel, 21, 0])
    for action, number in [("crossfader", 16), ("cueMix", 19), ("monitor", 20)]:
        for offset in [0, 30]:
            add(result, action, 0, number + offset, "control")
    add(result, "browse", 0, 14, "control", "binaryStep")
    result["inputs"][-1]["shifted"] = False
    add(result, "browsePreviousGroup", 0, 84)
    add(result, "browseNextGroup", 1, 85)
    result["shutdown"] += [[0x90 + r["channel"], r["number"], 0] for r in result["outputs"]]
    return [result]

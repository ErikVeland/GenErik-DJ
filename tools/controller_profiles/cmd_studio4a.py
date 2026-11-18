"""Four documented STUDIO 4a deck channels using shared native contracts."""
from curated import add, profile
from numark import UPSTREAM

STUDIO4A_MANUAL = "https://manual.mixxx.org/2.4/en_gb/hardware/controllers/behringer_cmd_studio_4a"
STUDIO4A_SOURCES = [
    ("Behringer CMDStudio4a.midi.xml", "75c69da47993bef18003ae79ccbb21cd0860dcdbbbada64571f1319c25351cf4"),
    ("Behringer-CMDStudio4a-scripts.js", "84adc04600502c0dc5691db8c4f7e95eaaac77ef991c9581a6cfe4cc7105ccd1"),
]
STUDIO4A_REFERENCES = {"Behringer CMD STUDIO 4a": {
    "url": UPSTREAM + STUDIO4A_SOURCES[0][0].replace(" ", "%20"), "sha256": STUDIO4A_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in STUDIO4A_SOURCES[1:]] + [{"url": STUDIO4A_MANUAL}],
    "review": "Pinned XML and script document four deck channels, centre64 jogs, physical touch and600-count scratch. Native fixed touch scratch replaces the software scratch toggle. Right manual loop In/Out retain the XML's reversed37/38 order. Full pitch messages apply native source-rate inversion and pickup. Native held bend replaces source permanent rate steps and optional key-shift mode. DEL is a source-local physical-side hold guard across A/C and B/D channels: unsupported alternate presses stay inactive, while old Cue/contact/bend releases remain valid. Source latched DEL mode, reverse/slip/autoloops, cue deletion, held Hot Cue previews, scratch toggle and bank-contact qualification remain open. Mixer and quick-filter controls retain source software assignments. Native six transport/PFL/loop states per deck use source on1/off0 values. Eight mode indicators initialise fixed Scratch on and DEL off; shutdown clears those and24 native outputs. Pad LEDs, live meters, EQ kill, FX, full browser/mode cleanup, calibration and physical acceptance stay open. The mapping author's manual specifies master1/2 and headphones3/4. No JS, timers or beatgrid mutation run in the app.",
}}


def studio4a_profiles():
    result = profile("Behringer CMD STUDIO 4a", STUDIO4A_REFERENCES["Behringer CMD STUDIO 4a"]["url"])
    result.update(audioOutput="masterAndHeadphones", scope="Automatic four-channel native core with600-count fixed touch scratch, held Cue/bend, pitch pickup, eight cues, manual loops, mixer/filter, Load and native transport feedback. C/D require app opt-in. Source latched modes, full feedback, bank-contact qualification and physical acceptance remain open.")
    for channel, deck in enumerate("abcd"):
        side = channel % 2
        base = 32 * side
        add(result, "shift", channel, 42 + base)
        result["inputs"][-1].update(shiftChannel=side, shiftInput=side)
        start = len(result["inputs"])
        for action, number in [("play", 44 + base), ("cuePreview", 43 + base), ("sync", 45 + base),
                               ("keylock", 27 + base), ("cue", 106 + side), ("load", 80 + side),
                               ("pitchBendDown", 32 + base), ("pitchBendUp", 33 + base),
                               ("loopIn", 23 if side == 0 else 56), ("loopOut", 24 if side == 0 else 55), ("reloop", 25 + base)]:
            add(result, action, channel, number, deck=deck)
        add(result, "jogTouch", channel, 26 + base, deck=deck)
        add(result, "jog", channel, 26 + base, "control", "binaryOffset", deck)
        result["inputs"][-1]["argument"] = 600
        add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1]["inverted"] = True
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", channel, 34 + base + slot, deck=deck)
        for item in result["inputs"][start:]:
            item.update(shifted=False, shiftChannel=side)
        for action, number in [("level", 112 + side), ("gain", 16 + base), ("filterKnob", 19 + base),
                               ("high", 96 + side * 3), ("mid", 97 + side * 3), ("low", 98 + side * 3)]:
            add(result, action, channel, number, "control", deck=deck)
        for action, number in [("play", 44 + base), ("cuePreview", 43 + base), ("sync", 45 + base),
                               ("keylock", 27 + base), ("cue", 106 + side), ("loop", 25 + base)]:
            result["outputs"].append({"action": action + ("A" if deck in "ac" else "B"), "targetDeck": deck,
                                      "kind": "note", "channel": channel, "number": number,
                                      "onValue": 1, "offValue": 0, "offUsesNoteOn": True})
        result["startup"].extend([[0x90 + channel, 42 + base, 0], [0x90 + channel, 22 + base, 1]])
        result["shutdown"].extend([[0x90 + channel, 42 + base, 0], [0x90 + channel, 22 + base, 0]])
    for action, number in [("master", 47), ("crossfader", 114), ("cueMix", 122), ("monitor", 123)]:
        add(result, action, 0, number, "control")
    add(result, "browse", 0, 1, "control", "binaryOffset")
    for action, number in [("openGroup", 1), ("browsePreviousGroup", 2), ("browseNextGroup", 3)]:
        add(result, action, 0, number)
    result["shutdown"] += [[0x90 + r["channel"], r["number"], 0] for r in result["outputs"]]
    return [result]

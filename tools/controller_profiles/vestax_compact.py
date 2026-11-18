"""Separate Spin and Typhoon native core facts from the pinned mappings."""
from curated import add, profile
from numark import UPSTREAM

COMPACT_SOURCES = {
    "Vestax Typhoon": [
        ("Vestax Typhoon.midi.xml", "2c2655736d616d78f7de16c481c137e2a93c530f25da1a8db242a015171f8950"),
        ("Vestax-Typhoon-scripts.js", "d71be6b5cecbb1c7b678b2617451801105ce64cd06ccb7b5f8cc484aaceb2d84")],
    "Vestax Spin": [
        ("Vestax Spin.midi.xml", "dcd8a576a5ddcdb29c8b8527725fa633a330b68b9bbda505a41f10f12c6c40ff"),
        ("Vestax-Spin-scripts.js", "4af354475ddd419c033a6ad4682940b364b746271658b31f3c3b66920b6077b4")],
}
COMPACT_REFERENCES = {name: {
    "url": UPSTREAM + sources[0][0].replace(" ", "%20"), "sha256": sources[0][1],
    "relatedSources": [{"url": UPSTREAM + path.replace(" ", "%20"), "sha256": digest} for path, digest in sources],
    "review": "XML dispatch retains each model's actual addresses. Both scripts use centre-64 jog counts and 300 counts per revolution. Typhoon receives both touch notes 46/47 and jog CC16/17. Spin's handler uses only touch 46 and jog CC16 despite additional XML dispatch entries. Native fixed touch scratching replaces software Scratch mode. Typhoon's held Filter button guards its jogs rather than changing audio. Typhoon loop buttons toggle a fixed four-beat loop and halve/double it. Spin uses manual In/Out and Reloop/Exit. Seven-bit tempo retains XML inversion and accounts for Mixxx rate_dir once, with exact native centre at 64. Explicit browser buttons move one track or group per press. Source timers, busy waits, alternate transport functions, full feedback, cleanup, routing and physical calibration remain open.",
} for name, sources in COMPACT_SOURCES.items()}


def compact_profiles():
    results = []
    for name, reference in COMPACT_REFERENCES.items():
        typhoon = name.endswith("Typhoon")
        result = profile(name, reference["url"])
        result["scope"] = "Automatic two-deck native core with fixed touch scratching and button-based browsing. Alternate modes, transport functions, full feedback, cleanup, routing and physical calibration remain open."
        result["startup"] = [[0x90 + channel, 36, 0 if typhoon else 127] for channel in range(2)]
        result["shutdown"] = [[0x90 + channel, 36, 0] for channel in range(2)]
        if not typhoon:
            result["startup"].append([0x92, 42, 0])
            result["shutdown"].append([0x92, 42, 0])
        for channel, deck in enumerate("ab"):
            for action, number in [("play", 50), ("cuePreview", 53), ("sync", 70), ("cue", 37)]:
                add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "cue"})
            for action, number in [("level", 12), ("gain", 20), ("low", 23), ("mid", 22), ("high", 21)]:
                add(result, action, channel, number, "control", deck=deck)
            add(result, "tempo", channel, 14, "control", "centreDetent", deck)
            add(result, "load", 2, 96 + channel, deck=deck)
            if typhoon:
                add(result, "shift", channel, 36)
                result["inputs"][-1]["shiftChannel"] = channel
            for number in [46, 47] if typhoon else [46]:
                add(result, "jogTouch", channel, number, deck=deck)
                if typhoon:
                    result["inputs"][-1].update(shifted=False, shiftChannel=channel)
            for number in [16, 17] if typhoon else [16]:
                add(result, "jog", channel, number, "control", "binaryOffset", deck)
                result["inputs"][-1]["argument"] = 300
                if typhoon:
                    result["inputs"][-1].update(shifted=False, shiftChannel=channel)
            for action, number in ([("loop", 32), ("loopDown", 33), ("loopUp", 66)] if typhoon else
                                   [("reloop", 32), ("loopIn", 33), ("loopOut", 66)]):
                add(result, action, channel, number, deck=deck)
                if action == "loop":
                    result["inputs"][-1]["argument"] = 4
            result["outputs"].append({"action": "loop" + ("A" if deck == "a" else "B"), "kind": "note",
                                      "channel": channel, "number": 32, "onValue": 127, "offValue": 0,
                                      "offUsesNoteOn": True, "targetDeck": deck})
        add(result, "crossfader", 2, 8, "control")
        for action, number in [("browsePrevious", 92), ("browseNext", 93), ("browseNextGroup", 38)]:
            add(result, action, 2, number)
        results.append(result)
    return results

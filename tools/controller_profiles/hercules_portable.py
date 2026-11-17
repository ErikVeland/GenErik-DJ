"""Separate Starlight and DJControl MIX core facts from pinned sources."""
from curated import add, profile
from numark import UPSTREAM

PORTABLE_SOURCES = {
    "Hercules DJControl Starlight": [
        ("Hercules DJControl Starlight.midi.xml", "e47b766a85f4fa234c41c4bf91ae456ca35dacc507184f69d3b2d458bf35d6c1"),
        ("Hercules-DJControl-Starlight-scripts.js", "7d88136dae1f18738d4f987bfc91a7e8ba2597e03bc7daf0887e30c36623347d")],
    "Hercules DJControl MIX": [
        ("Hercules DJControl MIX.midi.xml", "7d64670a5235dcde14373a700f1aec70124f1f3880d1efa65ee2459faa32ee18"),
        ("Hercules-DJControl-MIX-scripts.js", "fbfdce6c5be7753be5da0bd9e71ff9e1b19bb6458e71dcf3937cc9c7dffffce8")],
}
PORTABLE_REFERENCES = {name: {
    "url": UPSTREAM + sources[0][0].replace(" ", "%20"), "sha256": sources[0][1],
    "relatedSources": [{"url": UPSTREAM + path.replace(" ", "%20"), "sha256": digest} for path, digest in sources],
    "review": "XML dispatch and script handlers define two native deck channels, four Hot Cues, distinct fixed-loop pages, global Shift and 248-count jogs with 1/127 single-step reports. Right shifted jog callbacks derive deck two from MIDI channel five despite the XML's Channel1 group typo. Release-only aliases retain actual alternate channels without enabling source seek, stutter, cue-master or split functions. Native fixed touch scratching replaces the Vinyl toggle. Tempo retains the XML rate direction translated once to native normalisation. Starlight disables its base light show and restores it on shutdown. MIX has different loop/sample page addresses, adds master/headphone amounts and uses its own all-lights-off shutdown. The source defines no Load or browser inputs. Other modes, full feedback, cleanup, audio routing, Bluetooth pairing and physical calibration remain open.",
} for name, sources in PORTABLE_SOURCES.items()}


def portable_profiles():
    results = []
    for name, reference in PORTABLE_REFERENCES.items():
        mix = name.endswith("MIX")
        result = profile(name, reference["url"])
        result["scope"] = "Automatic two-deck core with 248-count fixed touch scratching, four Hot Cues and distinct fixed loops. The reviewed source defines no Load or browser inputs. Other modes, full feedback, cleanup, audio routing, Bluetooth pairing and physical calibration remain open."
        result["startup"] = ([] if mix else [[0x90, 36, 0]]) + [[0x91, 3, 127], [0xB0, 127, 127]]
        result["shutdown"] = [[0xB0, 127, 0]] if mix else [[0x90, 36, 127], [0x91, 3, 0]]
        add(result, "shift", 0, 3)
        for side, deck in enumerate("ab"):
            channel = side + 1
            for action, number in [("play", 7), ("cuePreview", 6), ("sync", 5), ("cue", 12)]:
                add(result, action, channel, number, deck=deck, feedback=action != "cuePreview")
                result["inputs"][-1]["shifted"] = False
                add(result, action, channel + 3, number, deck=deck)
                result["inputs"][-1].update(shifted=False, releaseOnly=True)
            add(result, "jogTouch", channel, 8, deck=deck)
            result["inputs"][-1]["shifted"] = False
            add(result, "jogTouch", channel + 3, 8, deck=deck)
            result["inputs"][-1].update(shifted=False, releaseOnly=True)
            for action, number in [("jog", 10), ("wheelJog", 9)]:
                add(result, action, channel, number, "control", "signedStep", deck)
                result["inputs"][-1].update(shifted=False, argument=248)
            add(result, "tempo", channel, 8, "control", "paired14Bit", deck)
            result["inputs"][-1].update(shifted=False, inverted=True)
            for action, number in [("level", 0), ("low", 2), ("filterKnob", 1)]:
                add(result, action, channel, number, "control", deck=deck)
            for slot in range(4):
                add(result, f"hotcue{slot + 1}", 6 + side, slot, deck=deck, feedback=True)
                result["inputs"][-1]["shifted"] = False
                add(result, f"hotcue{slot + 1}", 6 + side, 8 + slot, deck=deck, feedback=True)
                result["inputs"][-1].update(shifted=False, releaseOnly=True)
                add(result, "toggleFixedLoop", 6 + side, (48 if mix else 16) + slot, deck=deck)
                result["inputs"][-1].update(shifted=False, argument=2 ** slot)
        add(result, "crossfader", 0, 0, "control")
        if mix:
            for action, number in [("master", 3), ("monitor", 4)]:
                add(result, action, 0, number, "control")
        results.append(result)
    return results

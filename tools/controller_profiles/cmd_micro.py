"""CMD Micro core and held pitch buttons from pinned published sources."""
from curated import add, profile
from numark import UPSTREAM

CMD_MICRO_SOURCES = [
    ("Behringer CMD Micro.midi.xml", "e89119e414cf4aca2053e3da80b21db4d81a994af368654313b3b88614845c1c"),
    ("Behringer-CMD-Micro-scripts.js", "b86618e11ebf2666da9ccf169bfd2804325681ff0c400264c963c6912bb819b5"),
]
CMD_MICRO_REFERENCES = {"Behringer CMD Micro": {
    "url": UPSTREAM + CMD_MICRO_SOURCES[0][0].replace(" ", "%20"), "sha256": CMD_MICRO_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in CMD_MICRO_SOURCES],
    "review": "XML dispatch and script handlers give fixed two-deck addresses on channel zero, physical jog touch, 128-count centre-64 jogs, 4/8-beat toggle pads and held temporary pitch buttons. Native fixed 4-percent bend retains saved Sync and restores the rate on final release/disconnect. Later touch/rate commands supersede old holds. Tempo accounts for Mixxx rate_dir once and retains exact centre 64. The XML's inverted indicator condition resolves to native LED on 1/off 0. Only published Play and PFL lights are mapped. Source optional key-bend mode is not copied. Cue/Sync lights, remaining modes, full cleanup, audio routing, physical calibration and acceptance remain open.",
}}


def cmd_micro_profiles():
    result = profile("Behringer CMD Micro", CMD_MICRO_REFERENCES["Behringer CMD Micro"]["url"])
    result["scope"] = "Automatic two-deck native core with held pitch bend, 128-count touch jogs, 4/8-beat loop pads, browsing and Load. Optional key-bend mode, full lights/cleanup, audio routing and physical calibration remain open."
    for side, deck in enumerate("ab"):
        base = 16 + 16 * side
        for action, number in [("play", base + 7), ("cuePreview", base + 8), ("sync", base + 6),
                               ("cue", base + 9), ("load", 20 if side == 0 else 37),
                               ("pitchBendDown", base), ("pitchBendUp", base + 1)]:
            add(result, action, 0, number, deck=deck)
            if action in {"play", "cue"}:
                result["outputs"].append({"action": action + deck.upper(), "kind": "note", "channel": 0,
                                          "number": number, "onValue": 1, "offValue": 0,
                                          "offUsesNoteOn": True, "targetDeck": deck})
                result["shutdown"].append([0x90, number, 0])
        for number, beats in [(base + 2, 4), (base + (3 if side == 0 else 4), 8)]:
            add(result, "toggleFixedLoop", 0, number, deck=deck)
            result["inputs"][-1]["argument"] = beats
        add(result, "jogTouch", 0, 1 + side, deck=deck)
        add(result, "jog", 0, base + 1, "control", "binaryOffset", deck)
        result["inputs"][-1]["argument"] = 128
        add(result, "level", 0, base + 2, "control", deck=deck)
        add(result, "tempo", 0, base, "control", "centreDetent", deck)
        result["inputs"][-1]["inverted"] = True
    for action, number in [("master", 48), ("monitor", 49), ("crossfader", 64)]:
        add(result, action, 0, number, "control")
    add(result, "browse", 0, 50, "control", "binaryOffset")
    add(result, "browsePreviousGroup", 0, 48)
    add(result, "browseNextGroup", 0, 49)
    return [result]

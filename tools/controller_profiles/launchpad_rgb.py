"""Separate MK2 Session and Mini MK3 Programmer hardware contracts."""
from curated import add, profile
from numark import UPSTREAM

RGB_SOURCES = {
    "Novation Launchpad MK2": [
        ("Novation Launchpad MK2.midi.xml", "d453c050f1faa2830986f6a0a34b7168bd92122e31df2f9ad7a0bc4f290a1934"),
        ("Novation-Launchpad MK2-scripts.js", "a01853bbeef2e965ec8dd8397ed2b90906c7efb599cc6348b32dcefb1180e837"),
    ],
    "Novation Launchpad Mini MK3": [
        ("Novation Launchpad Mini MK3.midi.xml", "3defeb6d00eb7c70aebae696bcbd897f87f83a6764c269d533b90da0f467fd78"),
        ("Novation-Launchpad Mini MK3-scripts.js", "75ff90c1bb13d1c23940550e8a67af6bbe93316c3b65530fe9924a6320606d63"),
    ],
}
GUIDE_BASE = "https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/"
RGB_GUIDES = {
    "Novation Launchpad MK2": (GUIDE_BASE + "Launchpad%20MK2%20Programmers%20Reference%20Manual%20v1.03.pdf",
                               "5e38d75078b987c51427f8cb603c9e77ea782ad1eeaa8651198cfa8361885cb1", "Launchpad-MK2-Programmer.pdf"),
    "Novation Launchpad Mini MK3": (GUIDE_BASE + "Launchpad%20Mini%20-%20Programmers%20Reference%20Manual.pdf",
                                    "5db2df60c500e71a55c24ec730c5d45956d3a115db965a1d8fae3af890054cae", "Launchpad-Mini-MK3-Programmer.pdf"),
}
RGB_REFERENCES = {name: {
    "url": guide[0], "sha256": guide[1], "pages": [6, 7, 8] if name.endswith("MK2") else [6, 7, 8, 10],
    "relatedSources": [{"url": UPSTREAM + filename.replace(" ", "%20"), "sha256": digest}
                       for filename, digest in RGB_SOURCES[name]],
    "review": "Independent hardware tables qualify grid11+10*y+x, channel0. The pinned script initialSelection[0,1] places tall presets at offsets0/4. Its nameOf flips y then the device table resolves the physical address. Fixed A/B preserves this initial layout; source chord-selected decks/samplers and alternate presets remain inactive. Play11, Sync12, held Cue21, PFL31, key lock42, loop-in33/out34, reloop43, cues51/52/61/62, halve53/double54 and fixed loops63/64/73/74/83/84 carry independent native targets. Both source modifiers29/19 guard normal deck controls; halve/double and individual library actions are modifier-independent. Conditional Load-if-empty is omitted. Source colours qualify Play/key lock5/0, PFL17/0 and reloop17/19; fixed-loop-specific lamps and RGB cue colours need richer feedback state and remain inactive. " + (
        "MK2 uses Note right-column controls and a single class-compliant MIDI interface. The manufacturer Session layout command F0/00/20/29/02/18/22/00/F7 establishes the fixed channel1 address map, independent of saved User layouts. "
        if name.endswith("MK2") else
        "Mini MK3 uses CC right-column controls, a separate DAW interface and MIDI interface. Match only the documented LPMiniMK3 MIDI In/Out names. Manufacturer command0E selects Programmer1 and returns Live0 on disconnect, after bounded lamp clears. No persistent custom preset or DAW handshake is written. ") +
        "Complete alternate modes/output/lifecycle, calibration and physical/A10X acceptance remain open. No downloaded script executes in the app.",
} for name, guide in RGB_GUIDES.items()}


def rgb_profiles():
    results = []
    for name in RGB_SOURCES:
        mini = name.endswith("MK3")
        result = profile(name, RGB_GUIDES[name][0])
        result.update(definition="reviewed:launchpad-mini-mk3" if mini else "reviewed:launchpad-mk2", role="accessory",
                      excludedAliases=["Launchpad", "Launchpad Mini", "Launchpad X", "Launchpad Pro", "Launchpad MK2" if mini else "Launchpad Mini MK3"],
                      hardwareMode="Mini MK3 MIDI interface, Programmer mode selected by native setup." if mini else "MK2 Session layout and MIDI channel1 selected by native setup.",
                      scope="Automatic fixed initial two-tall A/B core with held Cue, guarded transport/cues/loops, individual library actions and bounded core lamps. Dynamic layouts, conditional Load, complete modes/output and physical acceptance remain open.")
        result["startup"] = [[240, 0, 32, 41, 2, 13, 14, 1, 247] if mini else [240, 0, 32, 41, 2, 24, 34, 0, 247]]
        if mini:
            result["portAliases"] = ["LPMiniMK3 MIDI", "LPMiniMK3 MIDI In", "LPMiniMK3 MIDI Out"]
            result["aliases"].append("LPMiniMK3 MIDI")
        kind = "control" if mini else "note"
        for number in [29, 19]:
            add(result, "shift", 0, number, kind)
        for deck, offset in [("a", 0), ("b", 4)]:
            for action, number in [("play", 11), ("sync", 12), ("cuePreview", 21), ("cue", 31),
                                   ("keylock", 42), ("loopIn", 33), ("loopOut", 34), ("reloop", 43)]:
                add(result, action, 0, number + offset, deck=deck)
                result["inputs"][-1]["shifted"] = False
            for action, number in [("loopDown", 53), ("loopUp", 54)]:
                add(result, action, 0, number + offset, deck=deck)
            for slot, number in enumerate([51, 52, 61, 62]):
                add(result, f"hotcue{slot+1}", 0, number + offset, deck=deck)
                result["inputs"][-1]["shifted"] = False
            for number, beats in zip([63, 64, 73, 74, 83, 84], [0.5, 1, 2, 4, 8, 16]):
                add(result, "toggleFixedLoop", 0, number + offset, deck=deck)
                result["inputs"][-1].update(shifted=False, argument=beats)
            for action, number, on, off in [("play", 11, 5, 0), ("cue", 31, 17, 0),
                                            ("keylock", 42, 5, 0), ("loop", 43, 17, 19)]:
                suffix = "A" if deck == "a" else "B"
                result["outputs"].append(dict(action=action+suffix, kind="note", channel=0, number=number+offset,
                                              onValue=on, offValue=off, offUsesNoteOn=True, targetDeck=deck))
        for action, number in [("browsePreviousGroup", 89), ("browseNextGroup", 79), ("openGroup", 69),
                               ("browsePrevious", 59), ("browseNext", 49)]:
            add(result, action, 0, number, kind)
        result["shutdown"] = [[0x90, row["number"], 0] for row in result["outputs"]]
        if mini:
            result["shutdown"].append([240, 0, 32, 41, 2, 13, 14, 0, 247])
        result["gaps"] = ["Fixed A/B initial tall layout only. Dynamic chord-selected channels, C/D/samplers, alternate presets, conditional Load/eject, nudge/grid/tap/quantise/slip/key/jump variants, modifier alternatives, held library scrolling, full per-size loop lamps/RGB cues/feedback/calibration and physical/A10X acceptance remain open. Mini MK3 other port-name variants and whole lifecycle need qualification. No persistent preset or audio route is inferred."]
        results.append(result)
    return results

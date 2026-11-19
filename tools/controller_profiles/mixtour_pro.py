"""Mixtour Pro manual normal controls from the author's public SJ2 mapping."""
from curated import add, profile

MIXTOUR_PRO_SOURCE = "https://community.algoriddim.com/uploads/short-url/9jBF9mCYRbHYcmKrtxDNWXrhiWf.djayMidiMa"
MIXTOUR_PRO_DISCUSSION = "https://community.algoriddim.com/t/reloop-mixtour-pro-custom-midi-mapping/42801"
MIXTOUR_PRO_SHA = "479b02dd5ae7f53c6e6ab45adc6512236ce2dd24d84fb816a2a25eeb6a43c23b"
MIXTOUR_PRO_AUDIT = {
    "source": {"url": MIXTOUR_PRO_SOURCE, "sha256": MIXTOUR_PRO_SHA},
    "discussion": MIXTOUR_PRO_DISCUSSION, "format": "Apple property list", "mappingVersion": 1,
    "inputRows": 744, "outputRows": 4, "declaredCustomClass": "ReloopMixtourPro", "automaticSupportAdded": False,
    "gaps": ["The public SJ2 mapping declares an absent ReloopMixtourPro app class. Cold-start negotiation, deck/pad mode ownership and complete lifecycle are not established. The manual recipe covers only reviewed unconditional normal controls; automatic selection remains off."],
}
MIXTOUR_PRO_REFERENCES = {"Reloop Mixtour Pro": {
    "url": MIXTOUR_PRO_SOURCE, "sha256": MIXTOUR_PRO_SHA,
    "relatedSources": [{"url": MIXTOUR_PRO_DISCUSSION}, {"url": "https://www.reloop.com/reloop-mixtour-pro"}],
    "review": "Author-owned hardware mapping SJ2, published20July2026 for djay5.6.7. File metadata version1 and customClassName ReloopMixtourPro are retained rather than interpreting SJ2 as a protocol version. All four unconditional normal records supply Play0, held native Cue1, BPM Sync2, PFL27 and six mixer CCs22..26/28 on channels0..3. Load uses separate channels4..7 Note10. Global channel15 CC8 crossfader, CC13 cue mix and flipped rotary64 CC0 browsing retain independent wire facts; original Mixtour is not an alias. Source normal Play/Cue/Sync output ranges6/2 for A/B and5/1 for C/D supply steady native feedback, not invented127/0 or a complete animation model. PFL output has no explicit maximum, so no PFL light is inferred. Conditional pads20..27 are shared by eight software modes; none maps to cues. Loop In-Out, split pads, Neural Mix, MODE/SHIFT combinations, browser source/back keys, FX/paddles, meters, cold-start query, complete lifecycle and audio routing remain open. Hardware master/headphone knobs are not mapped. Missing custom-class behaviour prevents automatic selection. Manual application does not activate the MIDI input or run automatic startup/shutdown. No vendor code runs in the app.",
}}


def mixtour_pro_profiles():
    result = profile("Reloop Mixtour Pro", MIXTOUR_PRO_SOURCE)
    result["autoSelect"] = False
    result["hardwareMode"] = "Manual reviewed normal-control subset. Enable the MIDI input separately; class-driven startup and bank/mode negotiation remain unqualified."
    result["scope"] = "Manual four-target normal transport, held Cue, mixer/filter, direct Load and inverted centre64 browse with source-valued steady feedback. Shared pad/mode/loop/FX controls, missing custom class, lifecycle and audio routing remain open."
    result["gaps"] = MIXTOUR_PRO_AUDIT["gaps"] + ["Conditional pads, split/deck mode state, loop combinations, shifted functions, Neural Mix, FX/paddles, PFL lights/meters, browser source/back keys, complete setup/reset and audio routing remain open. Source steady A/B feedback6/2 and C/D feedback5/1 do not qualify full light behaviour. C/D retain the app's four-deck opt-in. Manual feedback requires separate loading and enabling. Manual application does not activate input or automatic lifecycle; physical acceptance remains open."]
    for channel, deck in enumerate("abcd"):
        for action, number in [("play", 0), ("cuePreview", 1), ("sync", 2), ("cue", 27)]:
            add(result, action, channel, number, deck=deck, feedback=action != "cue")
            if action != "cue":
                result["outputs"][-1].update(onValue=6 if channel < 2 else 5, offValue=2 if channel < 2 else 1)
        add(result, "load", channel + 4, 10, deck=deck)
        for action, number in [("gain", 22), ("high", 23), ("mid", 24), ("low", 25), ("filterKnob", 26), ("level", 28)]:
            add(result, action, channel, number, "control", "absolute" if action == "level" else "centreDetent", deck)
    for action, number in [("crossfader", 8), ("cueMix", 13)]:
        add(result, action, 15, number, "control")
    add(result, "browse", 15, 0, "control", "binaryOffset")
    result["inputs"][-1]["inverted"] = True
    result["shutdown"] = [[0x90 + row["channel"], row["number"], row["offValue"]] for row in result["outputs"]]
    return [result]

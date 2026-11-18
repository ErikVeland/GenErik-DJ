"""U-Mix Control Pro 2 native core from pinned published dispatch."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

UMIX_PRO2_SOURCES = [
    ("MixVibes U-Mix Control Pro 2.midi.xml", "d460da29d06de95265297711fadae4d55ea77ca08821a778ba055ce0452e7840"),
    ("MixVibes-U-Mix-Control-Pro-2-scripts.js", "017a5ca80355f3a35162c101b37e4ee8b5b0de0d747a0f414622cec49f53c7ad"),
]
UMIX_PRO2_REFERENCES = {"MixVibes U-Mix Control Pro 2": {
    "url": UPSTREAM + UMIX_PRO2_SOURCES[0][0].replace(" ", "%20"), "sha256": UMIX_PRO2_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in UMIX_PRO2_SOURCES],
    "review": "XML and the short script provide two fixed targets, full-value touch on Note22, centre-64 platter CC22 and separate rim CC23 with 340-count scratch calibration. Pitch uses native centred 14-bit pitch bend and source rate inversion once. Separate Load and browse controls retain published dispatch. Four cue buttons have explicit shifted-channel delete-release aliases. Native held bend uses the shared four-percent rate and reports each held direction independently, including opposing holds; generation and later-control ownership protect feedback. Native Play feedback uses the known beat-indicator address steadily; beat pulses remain open. The source's inverted Sync condition resolves to on 100/off 0. Source EQ kill, Tap, source quarter-nudge scaling, held Hot Cue previews, jog-direction lights, clip/end lamps, full routing/calibration and physical acceptance remain open. Control 2 and original Pro are separate models.",
}}


def umix_pro2_profiles():
    result = profile("MixVibes U-Mix Control Pro 2", UMIX_PRO2_REFERENCES["MixVibes U-Mix Control Pro 2"]["url"])
    result["scope"] = "Automatic two-deck Pro 2 core with full-value touch, 340-count native scratch, separate rim, centred pitch, four cues and held pitch feedback. Play indication is steady. Other modes/feedback, routing, calibration and physical acceptance remain open."
    for channel, deck in enumerate("ab"):
        for action, number in [("play", 2), ("cuePreview", 1), ("sync", 3), ("cue", 16),
                               ("keylock", 7), ("pitchBendUp", 5), ("pitchBendDown", 4)]:
            add(result, action, channel, number, deck=deck, feedback=action != "cuePreview")
            if action == "sync":
                result["outputs"][-1]["onValue"] = 100
        add(result, "jogTouch", channel, 22, encoding="fullVelocityGate", deck=deck)
        for action, number in [("jog", 22), ("wheelJog", 23)]:
            add(result, action, channel, number, "control", "binaryOffset", deck)
            result["inputs"][-1]["argument"] = 340
        add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1]["inverted"] = True
        for action, number in [("gain", 17), ("high", 18), ("mid", 19), ("low", 20), ("level", 21)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "load", 2, 5 + channel, deck=deck)
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", channel, 9 + slot, deck=deck, feedback=True)
            release = deepcopy(result["inputs"][-1])
            release.update(channel=channel + 3, releaseOnly=True)
            result["inputs"].append(release)
        result["startup"].extend([[0x90 + channel, number, 0] for number in [1, 18, 19, 20]])
        result["startup"].extend([[0x92, 5 + channel, 0], [0x93 + channel, 3, 0]])
    for action, number in [("crossfader", 1), ("master", 3), ("cueMix", 7)]:
        add(result, action, 2, number, "control")
    add(result, "browse", 2, 4, "control", "twosComplement")
    result["shutdown"] = [[0x90 + output["channel"], output["number"], 0] for output in result["outputs"]]
    return [result]

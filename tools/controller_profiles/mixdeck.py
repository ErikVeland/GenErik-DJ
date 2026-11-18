"""Independent MixDeck Express and Quad MIDI facts with separate mixer ownership."""
from curated import add, profile
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA

MIXDECK_SCRIPTS = [
    ("Numark__MixDeck_Express.js", "f0604b632561fb3ddb24521825c392ee519c491ddfebda354406da11eab33ca9"),
    ("Numark__MixDeck_Quad.js", "404e2c813ff5d91c0ebaf8e3959c456ce279df4dfad2321dedb4c65b186dd0fc"),
]
QUAD_TSI = "https://www.numark.com/images/product_downloads/MIXDECK_QUAD_Traktor_Pro_2.zip"
EXPRESS_GUIDE = "https://www.numark.com/images/product_downloads/MixdeckExpress-UserGuide-1.1.pdf"
QUAD_GUIDE = "https://www.numark.com/images/product_downloads/mixdeck_quad_-_quickstart_guide_-_v1.5.pdf"
MIXDECK_REFERENCES = {"Numark MixDeck " + model: {
    "url": FOUR_SOURCE, "sha256": FOUR_PACKAGE_SHA,
    "archiveMember": "Applications/DEX4.app/Contents/Resources/controllers/" + filename,
    "memberSha256": digest,
    "relatedSources": ([{"url": EXPRESS_GUIDE, "sha256": "6a929b593a0a578f9459d41853416488b7780b910b5e7bfac6f1ad2aeebbafbd"}] if model == "Express" else [
        {"url": QUAD_TSI, "sha256": "7d0a1e647afe75db13a6cc8bc17a3e048f3dbdbbf4648c6d757d3c2a5827a346", "archiveMember": "MIXDECK_QUAD_Rev5.tsi", "memberSha256": "497059d84ac5a64560906ff3406f2ae0fa336d7d82f605948a2c761857f0240f"},
        {"url": QUAD_GUIDE}, {"url": "https://www.numark.com/product/mixdeckquad"}]),
    "review": "PCDJ public DEX4.0 package contains Brandon James's model-specific V1.1 DEX2.61+ script. Independent native facts replace downloaded code. Source physical transports use channels0/1. PitchBend is inverted pitch, with source MSB handling; finer resolution is not proven. CC34 follows raw64-positive signed counts, inverted only on Quad. The source600 denominator is software calibration, not measured hardware resolution. CC33 browser is value1 forward, all other seven-bit values backward, matching the existing typed NDX500 browser decoder. Native fixed touch replaces software-only Scratch/Search modes. Play output51 and Cue output49 differ from input notes. No Sync button, full displays, text SysEx, source pitch-range switching, combined-loop edit variations, reverse/slip/FX or complete lifecycle is inferred. " + (
        "Express uses Play61/Cue63/Load78, held bends58/59, contact80, loop In55/Out54/Reloop53 and browser press75. Manufacturer guide states the mixer sends no MIDI. Select MIDI-PC at each deck. Separate external deck audio routing is unavailable; automatic selection stays off. Manual input/feedback require separate enabling." if model == "Express" else
        "Quad uses Play58/Cue56/Load70, held bends61/60, contact89, loop In48/Out49/Reloop50 and browser press74. Its shared cue/sampler mode stays inactive. Numark's425-row TSI independently confirms fixed physical channels0/1, inverted jog and mixer channel0. Its mixer CC13/19/8/24 targets A/B/C/D levels, with gain/high/mid/low in the source inside-out order. Crossfader7, cue-mix18 and monitor66 share channel0. Native C/D targets remain opt-in; Traktor software deck-bank modifiers do not become extra physical MIDI channels. Use USB-MIDI deck sources, USB AUDIO PGM/CUE and MIDI USB selectors for software mixing, as the guide specifies. Automatic input core does not configure switches, audio outputs or the legacy30-pin iOS mono route. Full PFL routing, source cue/sampler modes and physical acceptance remain open."),
} for model, (filename, digest) in zip(["Express", "Quad"], MIXDECK_SCRIPTS)}


def mixdeck_profiles():
    results = []
    for model in ["Express", "Quad"]:
        quad = model == "Quad"
        result = profile("Numark MixDeck " + model, FOUR_SOURCE)
        result["definition"] = "reviewed:numark-mixdeck-" + model.lower()
        result["autoSelect"] = quad
        result["excludedAliases"] = ["Numark MixDeck " + ("Express" if quad else "Quad"), "MixDeck " + ("Express" if quad else "Quad")]
        result["hardwareMode"] = ("USB-MIDI deck sources; USB AUDIO PGM/CUE; MIDI USB selectors for software mixing. Audio routing remains separate." if quad else "Manual MIDI-PC transport only. Enable input separately; analogue mixer requires external deck audio routing.")
        result["scope"] = ("Automatic fixed A/B transport/touch core and source four-target MIDI mixer." if quad else "Manual A/B transport/touch core; no MIDI mixer.") + " Held Cue/bend, inverted pitch, normal loop boundaries and both browsers. Complete modes, calibration, screens, lifecycle, audio routing and physical acceptance remain open."
        for channel, deck in enumerate("ab"):
            notes = [("play", 58 if quad else 61), ("cuePreview", 56 if quad else 63), ("load", 70 if quad else 78),
                     ("pitchBendUp", 61 if quad else 58), ("pitchBendDown", 60 if quad else 59), ("jogTouch", 89 if quad else 80),
                     ("loopIn", 48 if quad else 55), ("loopOut", 49 if quad else 54), ("reloop", 50 if quad else 53)]
            for action, number in notes:
                add(result, action, channel, number, deck=deck, feedback=action in {"play", "cuePreview"})
                if action in {"play", "cuePreview"}:
                    result["outputs"][-1]["number"] = 51 if action == "play" else 49
            add(result, "tempo", channel, 0, "pitch", deck=deck)
            result["inputs"][-1]["inverted"] = True
            add(result, "jog", channel, 34, "control", "dj2go2Jog", deck)
            result["inputs"][-1]["inverted"] = quad
            add(result, "browse", channel, 33, "control", "ndx500Browse")
            add(result, "openGroup", channel, 74 if quad else 75)
        if quad:
            for deck, numbers in zip("abcd", [(13,17,16,15,14), (19,23,22,21,20), (8,12,11,10,9), (24,28,27,26,25)]):
                for action, number in zip(["level", "gain", "high", "mid", "low"], numbers):
                    add(result, action, 0, number, "control", deck=deck)
            for action, number in [("crossfader", 7), ("cueMix", 18), ("monitor", 66)]:
                add(result, action, 0, number, "control")
        result["shutdown"] = [[0x90 + row["channel"], row["number"], 0] for row in result["outputs"]]
        result["gaps"] = ["Native fixed touch replaces source software Scratch/Search toggles. Native calibration and finer pitch resolution remain unverified. Combined-loop/edit variations, pitch ranges, reverse/slip/FX, full displays/text, complete lifecycle and audio routing remain open. No Sync button is inferred. " + ("Shared cue/sampler mode, full PFL routing and legacy30-pin iOS mono handling remain open. Physical switch setup is required." if quad else "The analogue mixer sends no MIDI. Separate deck audio routing is unavailable, so automatic selection stays off.")]
        results.append(result)
    return results

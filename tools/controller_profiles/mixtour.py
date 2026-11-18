"""Original Mixtour factory MIDI core, separate from Mixtour Pro."""
from copy import deepcopy
from curated import add, profile

MIXTOUR_TABLE = "https://www.reloop.com/media/custom/upload/Reloop-Mixtour_MIDI-Map.pdf"
MIXTOUR_MAPPING = "https://www.reloop.com/media/custom/upload/Reloop-MIXTOUR_Traktor_Mapping.zip"
MIXTOUR_SOURCES = [
    ("mixtour-midi.pdf", "6c63ece1fdb7f76967820d4f8e39624c1a08377f03f7741544196cac49c72ceb"),
    ("mixtour-traktor.zip", "d301c68e86e0c60123ae7faf5af3c4d666150bb001001e0fb8813a7594bad8c1"),
    ("Traktor_Setup_Mixtour_V1.0.tsi", "dbd78c7e3c8fa30a36a6b819666c9aab8feeca86a3c894b3c9d4d35a649c9e32"),
]
MIXTOUR_REFERENCES = {"Reloop Mixtour": {
    "url": MIXTOUR_TABLE, "sha256": MIXTOUR_SOURCES[0][1], "pages": [1, 2],
    "relatedSources": [{"url": MIXTOUR_MAPPING, "sha256": MIXTOUR_SOURCES[1][1],
        "archiveMember": {"path": MIXTOUR_SOURCES[2][0], "sha256": MIXTOUR_SOURCES[2][1]}},
        {"url": "https://www.reloop.com/media/custom/upload/Reloop-Mixtour_Quickstart_Guide.pdf"},
        {"url": "https://raw.githubusercontent.com/ivanz/TraktorMappingFileFormat/df5f544d10e3293b72b829841e654da0db71c4b0/Tools/TSI%20Mapping%20Template.bt",
         "sha256": "2f8ae3942c26d7456e506eb445daa0b056ddbde2498ca65664eecf98d80c2386"}],
    "review": "Original Mixtour factory chart defines normal/shifted mixer, direct Load/PFL, cue page, two deck channels0/1 and global Shift. Factory TSI supplies transport page missing from the chart: Loop9, Sync10, held Cue11, Play12, shifted72..75. Cues13..16 retain distinct shifted76..79 clear addresses; unsupported clear presses cannot fire cues. TSI DCDT sets browseCC7 to7Fh/01h with no inversion. Native signed browse follows that fact, not an inferred centre64 sibling. Physical T/C mode reports release only their deck's contacts and reset pickup. Every mapped normal note has a shifted release alias to rearm debounce. Shift-Loop/Sync retain halve/double. Native Loop uses selected app length; source forced length and loop-out customisation are not copied. Factory bi-colour feedback uses orange64 for transport and green32 for cues, with ordinary PFL127. Factory outbound SysEx disables the30-second demo mode. Bounded lifecycle clears unsupported filter/FX indicators and meters plus owned outputs; other shifted lights/reset, live meters, FX, sampler, fader start, T+Trax seek and full feedback remain open. Both ordinary and FS internal routing records name Reloop ASIO and assign Master0/1, Monitor2/3; only that four-channel split is declared. Physical USB/audio acceptance remains open. No jog or tempo fader is invented. Mixtour Pro is excluded. No vendor code runs in the app.",
}}


def mixtour_profiles():
    result = profile("Reloop Mixtour", MIXTOUR_TABLE)
    result["audioOutput"] = "masterAndHeadphones"
    result["excludedAliases"] = ["Reloop Mixtour Pro", "Mixtour Pro"]
    result["scope"] = "Automatic original-Mixtour core with separate transport/cue pages, held Cue, mixer/filter, signed browse, shifted loop sizing, factory-coloured feedback and documented split output. Full modes/reset, input routing and physical acceptance remain open."
    result["gaps"] = ["Original Mixtour only. Native Loop uses the selected app length. Full FX/sampler/shift modes, fader start, T+Trax seek, live meters, remaining lights/reset, external/input audio routing and physical USB/audio/calibration acceptance remain open. No Mixtour Pro protocol or jog/tempo fader is inferred."]
    result["bankChanges"] = [{"channel": channel, "number": number, "onValue": 127, "decks": [deck]}
                             for channel, deck in enumerate("ab") for number in [4, 5]]
    add(result, "shift", 0, 6)
    for channel, deck in enumerate("ab"):
        def button(action, number, shifted_number, feedback=False, colour=127):
            add(result, action, channel, number, deck=deck, feedback=feedback)
            result["inputs"][-1]["shifted"] = False
            if feedback:
                result["outputs"][-1]["onValue"] = colour
            release = deepcopy(result["inputs"][-1])
            release.update(number=shifted_number, releaseOnly=True)
            release.pop("shifted")
            result["inputs"].append(release)

        for action, number in [("loop", 9), ("sync", 10), ("cuePreview", 11), ("play", 12)]:
            button(action, number, number + 63, feedback=True, colour=64)
        button("load", 2, 66)
        button("cue", 3, 67, feedback=True)
        for slot in range(4):
            button(f"hotcue{slot + 1}", 13 + slot, 76 + slot, feedback=True, colour=32)
        for action, number in [("loopDown", 72), ("loopUp", 73)]:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1]["shifted"] = True
        for action, number in [("gain", 0), ("high", 1), ("mid", 2), ("low", 3), ("filterKnob", 4), ("level", 5)]:
            add(result, action, channel, number, "control", "absolute" if action == "level" else "centreDetent", deck)
            result["inputs"][-1]["shifted"] = False
    for action, number in [("cueMix", 6), ("crossfader", 8)]:
        add(result, action, 0, number, "control")
        result["inputs"][-1]["shifted"] = False
    for action, number in [("master", 0), ("monitor", 1)]:
        add(result, action, 4, number, "control")
    add(result, "browse", 0, 7, "control", "twosComplement")
    result["inputs"][-1]["shifted"] = False
    add(result, "openGroup", 0, 7)
    result["inputs"][-1]["shifted"] = False
    add(result, "openGroup", 0, 70)
    result["inputs"][-1]["releaseOnly"] = True
    clear = [[0x90 + channel, number, 0] for channel in range(2) for number in [0, 1, 64, 65, 17, 18, 80, 81]]
    result["startup"] = [[0xF0, 0x26, 0x2D, 0x65, 0x22, 0xF7]] + clear
    result["shutdown"] = [[0x90 + row["channel"], row["number"], 0] for row in result["outputs"]] + clear
    return [result]

"""Original DJ2GO2 protocol facts from Numark's published Traktor mapping."""
from curated import add, profile

ORIGINAL_DJ2GO2_MAPPING = "https://www.numark.com/images/product_downloads/Numark_DJ2GO2_Performance_Map.tsi.zip"
ORIGINAL_DJ2GO2_ZIP_SHA = "06755935952d6ff6b7ce646b72b05128c92ba2368950d13a89a77d06a67cb8ae"
ORIGINAL_DJ2GO2_TSI_SHA = "3c56ed71e93de3dac1b157b40cc42137b7fb702991e04e111c5514fb354f2143"
ORIGINAL_DJ2GO2_GUIDE = "https://www.numark.com/images/product_downloads/DJ2GO2_UserGuide_v1.2.pdf"
ORIGINAL_DJ2GO2_REFERENCES = {"Numark DJ2GO2": {
    "url": ORIGINAL_DJ2GO2_MAPPING, "sha256": ORIGINAL_DJ2GO2_ZIP_SHA,
    "relatedSources": [{"url": ORIGINAL_DJ2GO2_GUIDE},
        {"url": "https://www.numark.com/product/dj2go2"},
        {"url": "https://raw.githubusercontent.com/ivanz/TraktorMappingFileFormat/df5f544d10e3293b72b829841e654da0db71c4b0/Tools/TSI%20Mapping%20Template.bt"}],
    "review": "Manufacturer product links the original DJ2GO2 Traktor archive. Its Generic MIDI device comment DJ2Go2 and ports DJ2GO2 (DJ2GO2) identify the original model; extracted TSI SHA256 is " + ORIGINAL_DJ2GO2_TSI_SHA + ". DCDT input definitions set wheel CC6 on channels1/2 and browse CC0/channel16 to encoder mode1 (7Fh/01h), as defined by the pinned TSI binary template. Native signed wheel seek/nudge has no physical touch or inferred236-count Touch calibration. The guide documents class-compliant USB, Channel Gain, Browse press and distinct cue/auto/manual/sampler pad pages. Native gain and group entry follow these labels instead of the TSI volume and latched-tree customisation. Normal transport, full-range seven-bit pitch, direct Load and output addresses retain factory wire facts. Native automatic loops restore labelled1/2/4/8 lengths instead of TSI loop-size/FX remaps. Manual pads use In/Out/On-Off; the fourth Retrigger and sampler page remain inactive. Sixteen steady Play/Cue/Sync/PFL/cue-pad outputs use source0..127 ranges; no Touch status SysEx is copied. Source modifiers, latched browse, wheel FX modes, full animations/cleanup, gain/tempo/wheel calibration, numbered audio layout and physical acceptance remain open. No EQ, level faders, Key Lock or touch sensor is inferred.",
}}


def original_dj2go2_profiles():
    result = profile("Numark DJ2GO2", ORIGINAL_DJ2GO2_MAPPING)
    result["aliases"] += ["DJ2GO2 (DJ2GO2)", "DJ2GO2 MIDI", "Numark DJ2GO2 MIDI"]
    result["excludedAliases"] = ["Numark DJ2GO2 Touch", "DJ2GO2 Touch", "DJ2GO2 Touch MIDI", "Numark DJ2GO2 Touch MIDI"]
    result["scope"] = "Automatic original non-touch two-deck core with signed native wheel seek/nudge, held Cue, pitch/gain, direct Load, browser, four cues and documented automatic/basic manual loop pages. Retrigger, sampler, latched browse/FX modes, full feedback/audio and calibration remain open."
    for channel, deck in enumerate("ab"):
        for action, number in [("play", 0), ("cuePreview", 1), ("sync", 2), ("cue", 27)]:
            add(result, action, channel, number, deck=deck, feedback=True)
        add(result, "wheelJog", channel, 6, "control", "twosComplement", deck)
        add(result, "tempo", channel, 9, "control", deck=deck)
        add(result, "gain", channel, 22, "control", deck=deck)
        add(result, "load", 15, 2 + channel, deck=deck)
        for slot in range(1, 5):
            add(result, f"hotcue{slot}", 4 + channel, slot, deck=deck, feedback=True)
            add(result, "toggleFixedLoop", 4 + channel, 16 + slot, deck=deck)
            result["inputs"][-1]["argument"] = 2 ** (slot - 1)
        for action, number in [("loopIn", 33), ("loopOut", 34), ("loop", 35)]:
            add(result, action, 4 + channel, number, deck=deck)
    for action, number in [("crossfader", 8), ("master", 10), ("monitor", 12)]:
        add(result, action, 15, number, "control")
    add(result, "browse", 15, 0, "control", "twosComplement")
    add(result, "openGroup", 15, 6)
    result["startup"] = [[0x90 + row["channel"], row["number"], 0] for row in result["outputs"]]
    result["shutdown"] = list(result["startup"])
    return [result]

"""Independent SR2 normal inputs and selector-owned logical Load contracts."""
from curated import add, profile
from ddj_family import PENDING_DDJ

SR2_GUIDE = PENDING_DDJ["Pioneer DDJ-SR2"]["source"]["url"]
SR2_SHA = PENDING_DDJ["Pioneer DDJ-SR2"]["source"]["sha256"]
SR2_REFERENCES = {"Pioneer DDJ-SR2": {
    "url": SR2_GUIDE, "sha256": SR2_SHA, "pages": [1, 2, 3, 4, 5, 6],
    "review": "Independent manufacturer table defines four deck channels0..3 and pad channels7..10. Standard Play11, held Cue12, Sync88, key lock26, loop20, halve18/double19, loop-in16/out17 and PFL84 have distinct shifted addresses. Shift63 retains physical side identity across A/C and B/D. Normal jog34 and Vinyl-Off35 use the fixed native touch/count contract; wheel33 retains separate contact suppression. Pitch0/32, trim4/36, high7/39, mid11/43, low15/47 and fader19/51 are explicit14-bit pairs per deck. Global channel6 pairs are master8/40, headphone level13/45, blend12/44 and crossfader31/63. BrowserCC64 uses signed counts and pushNote65 opens the selected group. Cue pads0..7 retain unqualified shifted-pad release aliases8..15 without activating Saved Flip/deletion. The source-local ddjSR2 adapter consumes selector Note85/86/87 on deck channels: positive A0/85, B1/85, C2/86, D3/86 establish separate left/right state. Current selector release or external/invalid selection clears that side. Shared channel6 Note70/71 converts to logical Note126 on the known target only. Logical126 cannot be injected by the raw TRANS parameter address. Selector events release source-owned A/C or B/D contacts and pickup while preserving physical Shift ownership. The table gives no cold-bank query; initial state remains unknown and automatic selection stays off. No SR/SX sibling setup, filter knob, FX bank, audio route or output is inferred. Complete Vinyl/Shift/pad/FX modes, feedback/lifecycle, jog calibration and physical/A10X acceptance remain open.",
}}


def sr2_profiles():
    result = profile("Pioneer DDJ-SR2", SR2_GUIDE)
    result.update(definition="manufacturer:ddjsr2", inputProtocol="ddjSR2", autoSelect=False,
                  excludedAliases=["DDJ-SR", "Pioneer DDJ-SR", "DDJ-SX", "DDJ-SX2", "DDJ-SX3"],
                  hardwareMode="Manual SR2 USB-MIDI core. Move each hardware input selector to identify its deck before shared Load. Initial and external-input Load ownership remains unknown. C/D require app opt-in.",
                  scope="Manual normal four-target input core with selector-owned shared Load, held Cue, fixed native touch/count jog, explicit14-bit pitch/mixer/globals and cue pads. Cold-bank query, full modes/output/lifecycle and physical acceptance remain open.")
    for channel, deck in enumerate("abcd"):
        side = channel % 2
        add(result, "shift", channel, 63)
        result["inputs"][-1].update(shiftChannel=side, shiftInput=side)
        for action, number, alternate in [("play", 11, 71), ("cuePreview", 12, 72), ("sync", 88, 92),
                                           ("keylock", 26, 96), ("loop", 20, 80), ("loopDown", 18, 97),
                                           ("loopUp", 19, 98), ("loopIn", 16, 76), ("loopOut", 17, 77),
                                           ("cue", 84, 104), ("jogTouch", 54, 103)]:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=side)
            add(result, action, channel, alternate, deck=deck)
            result["inputs"][-1].update(releaseOnly=True, shiftChannel=side)
        add(result, "load", channel, 126, deck=deck)
        add(result, "tempo", channel, 0, "control", "paired14Bit", deck)
        result["inputs"][-1].update(lowNumber=32, shifted=False, shiftChannel=side)
        for action, number in [("jog", 34), ("jog", 35), ("wheelJog", 33)]:
            add(result, action, channel, number, "control", "binaryOffset", deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=side)
        for action, number in [("gain", 4), ("high", 7), ("mid", 11), ("low", 15), ("level", 19)]:
            add(result, action, channel, number, "control", "paired14Bit", deck)
            result["inputs"][-1]["lowNumber"] = number + 32
        for slot in range(8):
            add(result, f"hotcue{slot+1}", 7+channel, slot, deck=deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=side)
            add(result, f"hotcue{slot+1}", 7+channel, 8+slot, deck=deck)
            result["inputs"][-1].update(releaseOnly=True, shiftChannel=side)
    for action, number in [("master", 8), ("monitor", 13), ("cueMix", 12), ("crossfader", 31)]:
        add(result, action, 6, number, "control", "paired14Bit")
        result["inputs"][-1]["lowNumber"] = number + 32
    add(result, "browse", 6, 64, "control", "twosComplement")
    add(result, "openGroup", 6, 65)
    result["gaps"] = ["Initial Load bank has no documented query. Move the hardware selectors before shared Load; external/current-selector release makes that side unknown again. Automatic selection remains off. Native fixed touch replaces source Vinyl mode variations. Shifted transport/grid/key/scan/fine-pitch/jog, alternate pad/Saved Flip/Roll/Slicer/Sampler/TRANS/Pitch Play, FX, booth/mic/sampler routing, full lights/lifecycle, jog calibration and physical/A10X acceptance remain open. Raw deck-channel Note126 is an unimplemented TRANS parameter; only the adapter can emit logical Load126."]
    return [result]

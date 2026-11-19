"""Reviewed TOUCH MIDI subset without its screen and driver lifecycle."""
from curated import add, profile
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA

TOUCH_SCRIPT_SHA = "e5290feb0573c0def2823acf70be6f11281ef73047c2c23cc87bfe085c06854f"
TOUCH_REFERENCES = {"Reloop TOUCH": {
    "url": FOUR_SOURCE, "sha256": FOUR_PACKAGE_SHA,
    "archiveMember": "Applications/DEX4.app/Contents/Resources/controllers/Reloop__Touch.js",
    "memberSha256": TOUCH_SCRIPT_SHA,
    "review": "The independent TOUCH script identifies USB26AD:8EB7 and input/output names TOUCH/Reloop Touch. Base channel1 gives A/B/C/D wire channels1..4. Play36, held Cue35, Sync33, contact63, bends38/39, Load57, PFL60 and shifted Keylock108 are reviewed. Normal jogCC96 is raw-minus64. Native fixed touch provides scratching from the explicit contact and movement inputs; the source uses moveDeckJogWheel with a600 software denominator, not measured physical calibration. Non-inverted pitch-bend uses native linear MIDI normalisation; source MSB-only handling does not establish finer hardware resolution. Gain/high/low/filter/levelCC16/17/18/19/20 and shifted MidCC50 remain distinct. Globals use channel5: crossfaderCC47, monitorCC1, cue-mixCC2, browseCC96 raw-minus64 and selectionNotes8/9. Explicit shifted Cue99/Play100/bends102/103 provide release-only cleanup; same-side opposite-bank releases clear only an existing owner. No shifted contact address is inferred. Source steady Play/Cue/PFL/Keylock lamps use127/0. Its startup opens an extra DisplayLink screen, enables separate UPDD touch/display drivers with SysEx and exits shop/standby mode. Native equivalents and lifecycle order remain unqualified, so this is manual MIDI only with no automatic activation or setup packet. Shared pads depend on software mode variables and remain inactive. Screen/touchscreen drivers, normal-mode setup, loop modes, full feedback/lifecycle, audio routing, native calibration and direct iPad attachment remain open. No downloaded code runs in the app.",
}}


def touch_profiles():
    result = profile("Reloop TOUCH", FOUR_SOURCE)
    result["aliases"].append("ReloopTouch")
    result["definition"] = "reviewed:reloop-touch"
    result["autoSelect"] = False
    result["hardwareMode"] = "Manual normal MIDI subset. Enable input separately. DisplayLink/UPDD and normal-mode setup remain unavailable. C/D require app opt-in."
    result["scope"] = "Manual four-target normal transport/mixer, fixed touch/jog, pitch, browsing and reviewed steady feedback. Screen/driver setup and shared-pad state remain open."
    for channel, deck in enumerate("abcd",1):
        for action, number in [("play",36),("cuePreview",35),("sync",33),("jogTouch",63),
                               ("pitchBendDown",38),("pitchBendUp",39),("load",57),("cue",60),("keylock",108)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play","cuePreview","cue","keylock"})
        shifted = [("play",100),("cuePreview",99),("pitchBendDown",102),("pitchBendUp",103)]
        for action, number in shifted:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        opposite = (channel-1+2)%4+1
        for action, number in [("play",36),("cuePreview",35),("jogTouch",63),("pitchBendDown",38),("pitchBendUp",39)]+shifted:
            add(result, action, opposite, number, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        for action, number in [("gain",16),("high",17),("low",18),("filterKnob",19),("level",20),("mid",50)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "jog", channel, 96, "control", "binaryOffset", deck)
        add(result, "tempo", channel, 0, "pitch", deck=deck)
    for action, number in [("crossfader",47),("monitor",1),("cueMix",2)]:
        add(result, action, 5, number, "control")
    add(result, "browse", 5, 96, "control", "binaryOffset")
    for number in [8,9]:
        add(result, "openGroup", 5, number)
    result["gaps"] = ["Manual subset requires an exposed normal MIDI port and separate input/feedback enabling. Automatic selection, DisplayLink/UPDD screen/touch drivers, normal-mode lifecycle, shared pads, loop modes, native jog calibration, finer pitch resolution and audio routing remain open. No shifted contact address is inferred. Direct iPad attachment and physical acceptance remain unverified."]
    return [result]

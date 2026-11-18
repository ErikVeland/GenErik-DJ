"""X-Session Pro factory preset with the pinned working software assignments."""
from curated import add, profile
from numark import UPSTREAM

XSESSION_GUIDE = "https://images.juno.co.uk/manual/334309-01U.pdf"
XSESSION_SOURCES = [("M-Audio_Xsession_pro.midi.xml", "68ee4b218f46d750423e6af0841b82f6e623bdf7a7fc8f7719acb67f6adf16ef")]
XSESSION_REFERENCES = {"M-Audio X-Session Pro": {
    "url": UPSTREAM + XSESSION_SOURCES[0][0], "sha256": XSESSION_SOURCES[0][1],
    "relatedSources": [{"url": XSESSION_GUIDE, "sha256": "152c368910314565815c603fafd3d59731812b56e5eda4deb53e8c25169b9df3", "pages": [5, 6, 7, 8, 9]}],
    "review": "Factory guide Appendix A confirms all control numbers and simultaneous normal CC17/inverted CC20 crossfader reports. Pinned working XML supplies default channel0 and the software assignments for six user knobs. Only CC17 controls native crossfader. Native held Cue remains separate from PFL. Pitch retains source rate polarity through native inversion and exact centre pickup. Unlabelled user knobs retain source gain, cue mix, headphone level and master assignments; source balance CC32 has no native equivalent and stays unmapped. The four transport search keys need a native held-search contract and stay inactive. No source script, output LED, jog, Sync, Load or audio interface is inferred. Factory preset is required; Enigma customisation and Evolution UC-17 remain separate. Full search/balance behaviour, calibration and physical acceptance remain open.",
}}


def xsession_pro_profiles():
    result = profile("M-Audio X-Session Pro", XSESSION_REFERENCES["M-Audio X-Session Pro"]["url"])
    result["aliases"].extend(["M-Audio Xsession pro", "Xsession pro"])
    result["excludedAliases"] = ["Evolution X-Session", "X-Session UC-17", "UC-17"]
    result["hardwareMode"] = "Factory preset; Enigma custom assignments require a separate user profile."
    result["scope"] = "Automatic factory-preset mixer and transport core with held Cue, PFL, source user-knob assignments and pitch pickup. Search keys, balance, custom presets, calibration and physical acceptance remain open."
    for side, deck in enumerate("ab"):
        for action, number in [("play", [70, 69][side]), ("cuePreview", 58 + side), ("cue", 44 + side)]:
            add(result, action, 0, number, deck=deck)
        for action, number in [("level", 11 + side * 3), ("tempo", 12 + side * 3), ("gain", 24 + side * 7),
                               ("high", 27 + side * 7), ("mid", 28 + side * 7), ("low", 29 + side * 7)]:
            add(result, action, 0, number, "control", "centreDetent" if action == "tempo" else "absolute", deck)
            if action == "tempo":
                result["inputs"][-1]["inverted"] = True
    for action, number in [("crossfader", 17), ("cueMix", 25), ("monitor", 26), ("master", 33)]:
        add(result, action, 0, number, "control")
    return [result]

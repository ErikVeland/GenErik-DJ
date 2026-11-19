"""Independent DJM-S3 manufacturer table facts for manual native mixing."""
from curated import add, profile

S3_TABLE = "https://dwn.alza.cz/manual/61365"
S3_MANUAL = "https://www.recordcase.de/media/1d/ba/18/1745910632/Pioneer-DJM-S3-User-Guide-EN.pdf"
S3_REFERENCES = {"Pioneer DJM-S3": {
    "url": S3_TABLE, "reviewDate": "2026-11-19", "pages": [1, 2],
    "evidenceLimit": "Manufacturer Version1.00 table text is available through the public mirror's cached PDF view. Direct PDF bytes and screenshots were unavailable. No table byte hash or visual table claim is made.",
    "relatedSources": [{"url": S3_MANUAL, "sha256": "ed03661da8c4d33f7ed9651f4055947fb297b7c08340eab23acdb992a82a0150", "pages": [21]}],
    "review": "The independent S3 Version1.00 table explicitly qualifies two gain/three-band EQ/Color/linefader strips, CC70/71 Cue states and cross/master/headphone/blend controls. All18 inputs use0-127 CC values. The manufacturer operating manual page21 was visually reviewed and confirms default MIDI channel1 and BUTTON TYPE TOGGLE. Source-selector Note51-53/55-57 reports retire only the corresponding strip's pickup. No DJM450/250/S9 sibling protocol is inferred. Hardware maintains its own processing. This is a manual app mixer without external deck audio routing, setting writes, feedback or hardware FX emulation. AUX/microphone, curve/reverse, global Filter/parameter, complete mode/lifecycle/calibration and physical/iPad/A10X acceptance remain open."
}}


def djms3_profiles():
    result = profile("Pioneer DJM-S3", S3_TABLE)
    result.update(autoSelect=False, role="accessory", definition="reviewed:djm-s3-independent-manufacturer-mixer",
                  aliases=["Pioneer DJM-S3", "Pioneer DJ DJM-S3", "DJM-S3", "DJM-S3 MIDI 1"],
                  excludedAliases=["DJM-250", "DJM-250MK2", "DJM-450", "DJM-S5", "DJM-S9", "DJM-900NXS2"],
                  hardwareMode="Manual default MIDI channel1 and BUTTON TYPE TOGGLE, confirmed in the S3 operating manual. Physical CH1/2 map to native A/B. Configure audio separately and avoid duplicate hardware/software processing.",
                  scope="Manual18-input independent S3 gain/EQ/Color/fader, direct Cue state and global mixer subset. Source reports rearm only their strip. No sibling protocol, hardware write or automatic audio ownership.",
                  gaps=["The source MIDI table was reviewed as cached text. Direct table PDF bytes/screenshots were unavailable. Hardware/software ownership, AUX/microphone, curve/reverse, global Filter/parameter, complete modes/lifecycle/calibration, external mixer outputs and physical/iPad/A10X acceptance remain open."])
    for index, (deck, numbers) in enumerate([("a", [1, 2, 3, 4, 5, 17]), ("b", [6, 7, 8, 9, 10, 18])]):
        for action, number in zip(["gain", "high", "mid", "low", "filterKnob", "level"], numbers):
            add(result, action, 0, number, "control", deck=deck)
        add(result, "cueState", 0, 70 + index, "control", deck=deck)
    for action, number in [("master", 24), ("monitor", 26), ("cueMix", 27), ("crossfader", 11)]:
        add(result, action, 0, number, "control")
    result["bankChanges"] = [{"channel": 0, "number": number, "onValue": 127, "decks": [deck]}
                             for deck, numbers in [("a", [51, 52, 53]), ("b", [55, 56, 57])] for number in numbers]
    return [result]

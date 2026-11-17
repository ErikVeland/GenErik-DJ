"""KDJ500 translated-MIDI core from the source mapping and manufacturer archive."""
from curated import add, profile
from numark import UPSTREAM

KDJ_SOURCES = [
    ("Kontrol Dj KDJ500.midi.xml", "5f24636b954fb2032cc8cbf8d246096a3d9e57447f3a6afae1e9ad334b9fe803"),
    ("Kontrol-Dj-KDJ500-scripts.js", "65f02ef8c26152c486c395498d9348efd6b8e2fd29b76eeebaaf060504b3593b"),
]
KDJ_DOWNLOADS = "https://drive.google.com/drive/folders/0B09d9nFit33wdUpIZk5OZ0wxRTA?resourcekey=0-XMiDZ5xFAkwVGGXeSgbb6w"
KDJ_REFERENCES = {"Kontrol DJ KDJ500": {
    "url": UPSTREAM + KDJ_SOURCES[0][0].replace(" ", "%20"), "sha256": KDJ_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in KDJ_SOURCES]
        + [{'url': 'https://drive.google.com/file/d/0B09d9nFit33wMDdJcU16aWdsUlE/view?resourcekey=0-25KFamm9fXsClG5Bcj7FWQ', 'sha256': 'b5fb30491bfddc8ec8a7102998d60909414665c46c8702d58b6f3a0fe548c6c9'}, {'url': 'https://drive.google.com/file/d/0B09d9nFit33wN19PQ3Zsdnc4OFU/view?resourcekey=0-DeBKMs4W-eCle4bM-O0Zcw', 'sha256': 'f8777f2dd5ba7a242ef156ce1158b6a4cbf4e14450d9d086994f7f7638bd7d22'}, {'url': 'https://drive.google.com/file/d/0B09d9nFit33wRFhKWDdmcWo2bGs/view?resourcekey=0-A2mDh8xAWOsDVfFkRZ5t0Q', 'sha256': 'ae5c003b80ae29aceb36c6afd6b7606c5b3c649581c34140efb8507ff567c1dc'}],
    "review": "Manual translated-MIDI source core. Factory manual requires USB drivers and Konverter to translate native USB reports. Manufacturer archive supplies the manual, Traktor settings and open SDK with eight-byte USB frames; a MIDI recipe alone is not direct iPad USB support. Source wheels/browser accept only127 forward and1 backward; native signedStep plus inversion preserves this strict rule. Both explicit Load targets, held Cue, PFL, normal mixer/pitch and fixed eight-beat loop toggles retain source addresses. Source init/shutdown and outputs are empty. Physical Shift, hardware banks, other controls, LEDs/full lifecycle, direct USB/bridge, calibration and physical acceptance remain open. No touch sensor, audio interface or sibling alias is inferred. Manual apply does not activate an input.",
}}


def kdj_profiles():
    result = profile("Kontrol DJ KDJ500", KDJ_REFERENCES["Kontrol DJ KDJ500"]["url"])
    result["aliases"] = ["Kontrol DJ KDJ500", "KDJ500", "KDJ-500"]
    result["autoSelect"] = False
    result["hardwareMode"] = "Published Mixxx normal-control layout over translated MIDI. Native USB needs its driver and Konverter or a qualified bridge."
    result["scope"] = "Manual translated-MIDI core: strict source wheel/browser directions, two Load targets, held Cue, normal mixer/pitch and fixed eight-beat loops. Direct USB/bridge, Shift/banks, other controls/feedback and physical acceptance remain open."
    result["gaps"] = ["USB drivers and Konverter translate native USB reports. Direct iPad USB and a qualified bridge remain unimplemented. Physical Shift/banks, other controls, LED feedback/full lifecycle and calibration remain open. No automatic selection or integrated audio is claimed. Manual apply does not activate an input."]
    for side, deck in enumerate("ab"):
        for action, numbers in [("play", [16, 38]), ("cuePreview", [14, 36]), ("cue", [44, 46]), ("load", [20, 40])]:
            add(result, action, 0, numbers[side], deck=deck)
        add(result, "toggleFixedLoop", 0, [3, 25][side], deck=deck)
        result["inputs"][-1]["argument"] = 8
        for action, number in [("wheelJog", [40, 44][side]), ("browse", [42, 46][side])]:
            add(result, action, 0, number, "control", "signedStep", deck if action == "wheelJog" else None)
            result["inputs"][-1]["inverted"] = True
        for action, numbers in [("gain", [1, 5]), ("high", [2, 6]), ("mid", [3, 7]),
                                ("low", [4, 8]), ("tempo", [9, 10]), ("level", [11, 12])]:
            add(result, action, 0, numbers[side], "control", deck=deck)
            if action == "tempo":
                result["inputs"][-1]["inverted"] = True
    add(result, "crossfader", 0, 13, "control")
    return [result]

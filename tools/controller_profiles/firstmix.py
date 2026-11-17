"""Original FirstMix core from the pinned mapping and its companion script."""
from curated import add, profile
from numark import UPSTREAM

FIRSTMIX_SOURCES = [
    ("Gemini FirstMix.midi.xml", "6c6a4f50f223a97316eb07da4f9da3ddf02464a849ae118e50d8b4b82af1c2a5"),
    ("Gemini-FirstMix-scripts.js", "ad9b01a05949ba0990dfd10510fd48ddd4030573ff1d7283b13805342007074c"),
]
FIRSTMIX_REFERENCES = {"Gemini FirstMix": {
    "url": UPSTREAM + FIRSTMIX_SOURCES[0][0].replace(" ", "%20"), "sha256": FIRSTMIX_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in FIRSTMIX_SOURCES],
    "review": "Pinned XML supplies separate Play, held Cue, Sync, Load and EFX/PFL addresses. The script supplies physical full-value wheel contact, 180-count signed wheels and LED addresses/values. Native fixed Scratch requires contact; the source's latched Scratch/Pitch mode is not copied. Signed 64 decodes negative, correcting the source scratch boundary. Source software assignments retain EFX amount as gain, physical gain as High, Treble as Mid, Bass as Low and Master as cue blend. The original has no channel faders or pitch sliders; none are invented. Source library auto-load and sampler preview have no matching native contract and remain inactive. Startup clears the published 0x33–0x60 light range and enables both fixed Scratch lights. Native transport/PFL lights are steady, not beat/end-of-track flashes. Unsupported source state queries are omitted. FirstMix I/O and Pro remain separate. Full modes, preview, effects, calibration and physical acceptance remain open.",
}}


def firstmix_profiles():
    result = profile("Gemini FirstMix", FIRSTMIX_REFERENCES["Gemini FirstMix"]["url"])
    result["excludedAliases"] = ["FirstMix I/O", "FirstMix IO", "FirstMix Pro"]
    result["scope"] = "Automatic original FirstMix core with native held Cue, fixed 180-count touch scratch, source mixer assignments, direct Load, browsing and steady lights. Scratch/Pitch mode switching, sampler preview, effects, full feedback and physical calibration remain open."
    for side, deck in enumerate("ab"):
        for action, numbers in [("play", [0x4A, 0x4C]), ("cuePreview", [0x3B, 0x42]),
                                ("sync", [0x33, 0x3C]), ("cue", [0x43, 0x45]), ("load", [0x4B, 0x34])]:
            add(result, action, 0, numbers[side], deck=deck, feedback=action != "load")
            if action != "load":
                result["outputs"][-1]["onValue"] = 100
        add(result, "jogTouch", 0, 0x4D + side, encoding="fullVelocityGate", deck=deck)
        add(result, "jog", 0, [0x19, 0x18][side], "control", "twosComplement", deck)
        result["inputs"][-1].update(argument=180, requiresTouch=True)
        for action, numbers in [("gain", [0x16, 0x1C]), ("high", [0x08, 0x09]),
                                ("mid", [0x10, 0x11]), ("low", [0x14, 0x15])]:
            add(result, action, 0, numbers[side], "control", deck=deck)
    add(result, "crossfader", 0, 0x0A, "control")
    result["inputs"][-1]["inverted"] = True
    add(result, "cueMix", 0, 0x17, "control")
    add(result, "browse", 0, 0x1A, "control", "twosComplement")
    result["startup"] = [[0x90, number, 0] for number in range(0x33, 0x61)]
    result["startup"].extend([[0x90, number, 100] for number in [0x48, 0x35]])
    result["shutdown"] = [[0x90, output["number"], 0] for output in result["outputs"]]
    result["shutdown"].extend([[0x90, number, 0] for number in [0x48, 0x35]])
    return [result]

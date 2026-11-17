"""Original U-Mix Control Pro, separate from non-Pro Control2 and later Pro2."""
from copy import deepcopy
from curated import add
from umix_control2 import umix2_profiles, UMIX2_GUIDE

ORIGINAL_UMIX_GUIDE = "https://media.djmania.net/manuales/pdf/U-MIX_CONTROL_PRO_1.5.1_user_manual_0.pdf"
ORIGINAL_UMIX_SHA = "80790ce92df968e553a4eb0a2b7865e0d4c5fa6982fcb258b7a50246097d293e"
ORIGINAL_UMIX_REFERENCES = {"MixVibes U-Mix Control Pro": {
    "url": ORIGINAL_UMIX_GUIDE, "sha256": ORIGINAL_UMIX_SHA, "pages": [11, 12, 13, 15, 16, 17, 19],
    "relatedSources": [{"url": UMIX2_GUIDE, "pages": [122, 123, 124, 125, 126]}],
    "review": "Factory original-Pro layout, not Pro2 or non-touch Control2. Cross DJ factory appendix gives exact-full-value touch Note22, top motion CC22 and rim CC23 on deck channels0/1, plus Shift channels3/4. Native fixed scratch uses default1024 calibration because no original-Pro sensor count is published; Pro2's340 count is not inferred. Common factory transport/mixer/six-cue/loop/browser addresses are reviewed in the same appendix. LoadA follows the factory CC5 row with first-positive/repeat protection; source Control2 Note5 is not copied. Other channel-shifted functions stay inactive. Hardware guide Mac installation requires no extra driver. Dual Stereo is explicitly master1/2 and cue3/4. Only that four-channel route is declared; hardware headphone level, input gain/selection, external mixer, DVS, full modes/feedback/reset and calibration remain open. Factory PitchMode8 uses native keylock instead of full three-state pitch selection. Lifecycle bounds are62. No vendor scripts or binaries run in the app.",
}}


def original_umix_profiles():
    result, = umix2_profiles()
    result = deepcopy(result)
    result.update(id="MixVibes U-Mix Control Pro", aliases=["MixVibes U-Mix Control Pro", "U-MIX CONTROL PRO"],
                  definition="manufacturer:mixvibesumixcontrolpro", source=ORIGINAL_UMIX_GUIDE,
                  excludedAliases=["MixVibes U-Mix Control Pro 2", "U-MIX CONTROL PRO 2", "U-MIX CONTROL PRO2"],
                  audioOutput="masterAndHeadphones",
                  scope="Automatic original-Pro core with fixed touch scratch, separate rim, factory CC LoadA, six cues, loops/mixer and split output. Full modes, inputs/external mixing, feedback/reset, default jog calibration and physical acceptance remain open.",
                  gaps=["Original-Pro jog sensor resolution is not published; native1024 default needs calibration. Factory CC5 LoadA differs from the Control2 source Note5. Full PitchMode/Vinyl/FX/EQ-kill modes, held cue preview, input routing/external mixing, animation, complete feedback/reset and physical USB/audio acceptance remain open."])
    for row in result["inputs"]:
        if row["action"] in {"wheelJogA", "wheelJogB"}:
            row["action"] = row["action"].replace("wheelJog", "jog")
            row["requiresTouch"] = True
        if row["action"] == "loadA":
            row["kind"] = "control"
            row["layerIndependent"] = True
            row.pop("shifted", None)
    for channel, deck in enumerate("ab"):
        add(result, "jogTouch", channel, 22, "note", "fullVelocityGate", deck)
        result["inputs"][-1]["shifted"] = False
        release = deepcopy(result["inputs"][-1])
        release.update(channel=channel + 3, releaseOnly=True)
        release.pop("shifted")
        result["inputs"].append(release)
        add(result, "wheelJog", channel, 23, "control", "binaryOffset", deck)
        result["inputs"][-1]["shifted"] = False
    add(result, "cueMix", 2, 7, "control")
    result["inputs"][-1]["shifted"] = False
    for row in result["startup"]:
        if row[0] in {0x90, 0x91} and row[1] == 7:
            row[2] = 127
    return [result]

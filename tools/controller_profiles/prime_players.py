"""Separate Prime player core contracts from model-specific factory assignments."""
from sc5000m import sc5000m_profiles

PRIME_REVISION = "dfb7c339a2f6c29909d4bd24abadf858ae7c6b9e"
PRIME_BASE = "https://raw.githubusercontent.com/ghuntley/denon-prime4/" + PRIME_REVISION + "/engineos/usr/Engine/AssignmentFiles/PresetAssignmentFiles/"
PRIME_MODELS = [
    ("Denon DJ SC6000 PRIME", "JP13", "b0582096e4b51118a831ef08fd6679c17089298d7ed4261f5c4c29f43e0c3d44"),
    ("Denon DJ SC6000M PRIME", "JP14", "8563b6734d799637efe7a6c0c9ec45c78077ff54f0bc9bf376bb6df1c5d5db49"),
    ("Denon DJ SC5000 PRIME", "JP07", "1d8d978bcc2150125ae0f89912746064e0c8c9731767c88ad6abb3cdde61b7f4"),
]
PRIME_REFERENCES = {}
for name,hardware,digest in PRIME_MODELS:
    PRIME_REFERENCES[name] = {
        "url": PRIME_BASE + hardware + "/" + hardware + "_Controller_Assignments.qml", "sha256": digest,
        "revision": PRIME_REVISION,
        "relatedSources": [{"url": "https://github.com/mixxxdj/mixxx/wiki/Reverse-Engineering#denon-engine-dj-hardware"}],
        "review": "Independently pinned model-specific factory assignment declares channel0, LAYER11, Play1/Cue2, jump3/4, loops8/9/10, Load18/browseCC6, Sync20, Keylock22, held bend24/25, Shift26, Hot Cue mode27/raw pads32..39 and loop-sizeCC3. Reuse only this common normal input contract with the captured Prime player's bounded two-deck decoder. Native LAYER selects A/B and Hot Cue1..8; other pad modes stay inactive. Track-skip5/6 is not library browsing. Parameter buttons52/53 differ from the public LC6000 table's68/69 and remain inactive. Non-motorised assignments declare JogWheel CC17/49 and sensitivity1638.7; motorised assignments declare Motorized CC54 and no touch. Pitch LED orientation also differs between motorised and non-motorised assignments. None of those model-specific controls, calibration values or output meanings is inherited. These firmware assignments corroborate normal wire addresses; they are not a complete host SDK or proof of Computer-mode setup/USB lifecycle. Manual raw Computer-mode selection, transport-only scope and separate audio remain explicit. Jog/touch, motor, pitch, screen, full output/lifecycle/audio and physical/A10X acceptance remain open. No reset, motor, setup, light or screen packet is sent.",
    }


def prime_player_profiles():
    results=[]
    for name,hardware,_ in PRIME_MODELS:
        result=sc5000m_profiles()[0]
        short=name.removeprefix("Denon DJ ")
        result.update(id=name, aliases=[name,"Denon "+short,short],
                      excludedAliases=[model for model in ["SC5000 PRIME","SC5000M PRIME","SC6000 PRIME","SC6000M PRIME","LC6000 PRIME"] if model!=short],
                      definition="reviewed:prime-player-"+hardware.lower(), source=PRIME_REFERENCES[name]["url"], inputProtocol="denonPrimePlayer",
                      hardwareMode="Manual raw "+short+" Computer-mode input. Native LAYER selects A/B, starting A. Hot Cue1–8 only; other pad modes are inactive. Model-specific jog/touch/motor/pitch/display and complete USB lifecycle remain unqualified. Separate audio required.",
                      scope="Manual independently sourced normal transport, native loop controls/browser and selected-layer Hot Cue1–8. Other modes, jog/pitch/motor/screen, full output/lifecycle/audio and physical acceptance remain open.")
        result["inputs"]=[i for i in result["inputs"] if not i["action"].startswith("toggleFixedLoop")]
        result["gaps"]=["Manual raw Computer-mode only. Independent factory assignments establish normal addresses, not a complete host SDK. Other pad modes/Shift alternatives, track-skip loading, parameter buttons, model-specific jog/touch/sensitivity, motor, pitch polarity/range, screens, dynamic lamps, complete setup/output/lifecycle/audio and physical/A10X acceptance remain open. No factory reset, motor or lifecycle packet is sent. Native LAYER selects A/B only."]
        results.append(result)
    return results

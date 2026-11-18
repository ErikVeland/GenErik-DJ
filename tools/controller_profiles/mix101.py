"""Manual MIX-101 source controls with exact fast relative encoders."""
from curated import add, profile
from numark import UPSTREAM

MIX101_XML = "DJ-Tech Mix-101.midi.xml"
MIX101_SOURCE = UPSTREAM + MIX101_XML.replace(" ", "%20")
MIX101_CODEC = "https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/src/controllers/midi/midicontroller.cpp"
MIX101_REFERENCES = {"DJ-Tech MIX-101": {
    "url": MIX101_SOURCE, "sha256": "6c1364e0ab02722419e9680a9d05caf594aa8bc45a2f3188c2098e3e464a83a4",
    "relatedSources": [{"url": MIX101_CODEC, "sha256": "e2c3509c73e5b790f84db26cb9b2ec2dd791c29f46393c463ad80ec00ce2f331"}],
    "review": "Manual pinned-source channel-one layout. Fast relative master/headphone encoders preserve (raw-64)*1.5 and accumulate from current native values with clamping. Source spread64 wheels retain raw-64, with native unheld wheel behaviour and default calibration. No touch gate, physical tempo fader, audio interface or Hot Cue pad is invented. Play A input9 differs from LED10. Normal Cue accepts both MIDI release forms. Shared first-stopped Load, deck/mode switch ownership, sampler holds, other channel settings, complete source behaviour, feedback/reset and physical acceptance remain open. The factory describes one banked wheel and mode-dependent controls. Automatic selection stays off. Manual apply does not activate input or run automatic lifecycle.",
}}


def mix101_profiles():
    result = profile("DJ-Tech MIX-101", MIX101_SOURCE)
    result["aliases"] += ["Mix-101 MIDI 1"]
    result["autoSelect"] = False
    result["hardwareMode"] = "Manual pinned Mixxx source layout on hardware MIDI channel 1. Bank/mode ownership remains unqualified."
    result["scope"] = "Manual source transport/mixer, browser, wheel nudge and exact fast relative master/headphone encoders. Shared Load, hardware modes, sampler, full feedback and physical acceptance remain open."
    result["gaps"] = ["Bank/mode ownership, first-stopped Load, sampler holds, full documented controls, other channel settings, calibration and complete feedback/reset remain open. No automatic selection or integrated audio is claimed. Manual apply does not activate input or run lifecycle."]
    for side, deck in enumerate("ab"):
        for action, numbers in [("play", [9, 7]), ("cuePreview", [3, 4]), ("cue", [1, 2])]:
            add(result, action, 0, numbers[side], deck=deck, feedback=action in {"play", "cue"})
        if side == 0:
            result["outputs"][-2]["number"] = 10
        add(result, "wheelJog", 0, [19, 21][side], "control", "binaryOffset", deck)
        for action, numbers in [("level", [33, 34]), ("gain", [36, 37]), ("high", [38, 39]),
                                ("mid", [40, 41]), ("low", [42, 43])]:
            add(result, action, 0, numbers[side], "control", deck=deck)
    add(result, "crossfader", 0, 35, "control")
    add(result, "browse", 0, 17, "control", "binaryOffset")
    add(result, "monitor", 0, 16, "control", "rot64Fast")
    add(result, "master", 0, 18, "control", "rot64Fast")
    result["startup"] = [[0x90, row["number"], 0] for row in result["outputs"]]
    result["shutdown"] = [row.copy() for row in result["startup"]]
    return [result]

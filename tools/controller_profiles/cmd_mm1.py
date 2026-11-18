"""Independent fixed CMD MM-1 mixer core from the pinned default mapping."""
from copy import deepcopy
from curated import add, profile

MM1_REVISION = "20f2c218ae1b762ac39fd76ff408c8428056f4f7"
MM1_BASE = "https://raw.githubusercontent.com/mixxxdj/mixxx/"+MM1_REVISION+"/res/controllers/"
MM1_SOURCES = [
    ("Behringer CMD MM1.midi.xml", "b32bdb57cdd2e8474f0b77e51df0122b389fe2b8a8c0c0230146e512592f6a90"),
    ("Behringer-CMD-MM1-scripts.js", "5babd6d36087846163ab27f777372d521cb70c2fef15d9777a915007873a65f1"),
]
MM1_REFERENCES = {"Behringer CMD MM-1": {
    "url": MM1_BASE+MM1_SOURCES[0][0].replace(" ","%20"), "sha256": MM1_SOURCES[0][1],
    "relatedSources": [{"url": MM1_BASE+MM1_SOURCES[1][0], "sha256": MM1_SOURCES[1][1]},
                       {"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/behringer_cmd_mm_1"}],
    "review": "Pinned XML/script and the upstream manual define a four-strip MIDI mixer. Default software order is C/A/B/D, not A/B/C/D. Each physical strip uses highCC6+i, mid10+i, low14+i, filter18+i and level48+i; Note48+i is headphone PFL. No gain pot, transport, pitch fader or main held Cue is invented. Globals are masterCC2, headphone level4, cue mix5, crossfader64 and browser3 with signed raw-minus64 counts. The upstream MIDI channel defaults to wire4, but the manual confirms a tool can change it. Native accepts every MIDI channel only on a named MM-1 endpoint. Both modifier Notes16/17 have independent guard ownership; either blocks normal deck/browse actions and releasing one cannot clear the other. The native recipe keeps fixed default strip/knob roles. It does not execute source software assignment/FX modes or conflate Ctrl with Shift-Load. Source startup has no active hardware handshake; its dump request is commented out and remains inactive. Source lamp colour values0/1 and meters are not emitted because the active outbound channel has not been qualified. No generic CMD/device alias, audio route or sibling CMD protocol is inferred. Full layers/output, endpoint-name variation, native calibration and physical/A10X acceptance remain open. No downloaded script executes in the app.",
}}


def mm1_profiles():
    result = profile("Behringer CMD MM-1", MM1_REFERENCES["Behringer CMD MM-1"]["url"])
    result["definition"] = "reviewed:cmd-mm1"
    result["excludedAliases"] = ["CMD", "Behringer CMD DC-1", "CMD DC-1", "CMD DV-1", "CMD STUDIO 4a"]
    result["hardwareMode"] = "Named CMD MM-1 MIDI endpoint, any configured MIDI channel. Fixed default C/A/B/D strip order and EQ/filter roles. C/D require app opt-in."
    result["scope"] = "Automatic named-port input core for four fixed mixer strips, headphone PFL, global level/blend/crossfader and signed browsing. Both modifiers guard normal deck/browse controls. Full layers/output and physical acceptance remain open."
    for identity, number in enumerate([16,17]):
        add(result, "shift", 0, number)
        result["inputs"][-1]["shiftInput"] = identity
    for strip, deck in enumerate("cabd"):
        for action, base in [("high",6), ("mid",10), ("low",14), ("filterKnob",18), ("level",48)]:
            add(result, action, 0, base+strip, "control", deck=deck)
            result["inputs"][-1]["shifted"] = False
        add(result, "cue", 0, 48+strip, deck=deck)
        result["inputs"][-1]["shifted"] = False
    for action, number in [("master",2), ("monitor",4), ("cueMix",5), ("crossfader",64)]:
        add(result, action, 0, number, "control")
    add(result, "browse", 0, 3, "control", "binaryOffset")
    result["inputs"][-1]["shifted"] = False
    base_inputs = result["inputs"]
    result["inputs"] = []
    for channel in range(16):
        for base in base_inputs:
            binding = deepcopy(base)
            binding["channel"] = channel
            result["inputs"].append(binding)
    result["gaps"] = ["Named MM-1 endpoint only. Fixed default C/A/B/D strips and EQ/filter roles replace the source software layers. Dynamic strip/FX/knob assignment, shifted Load, Ctrl-Sync, balance, crossfader assignment/centre buttons, browser press, lamps/meters, complete lifecycle and physical/A10X acceptance remain open. Configurable outbound channel and endpoint-name variants need qualification. No generic CMD alias or audio route is inferred."]
    return [result]

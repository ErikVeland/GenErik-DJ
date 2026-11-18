"""SC5000M manual input core from pinned author captures and working mapping."""
from copy import deepcopy
from curated import add, profile

SC5000M_NAME = "Denon DJ SC5000M PRIME"
SC5000M_REVISION = "a34fb9a4367731014e469aaf86f5fde78cc00896"
SC5000M_BASE = "https://raw.githubusercontent.com/saustin2010/denon_sc5000_algoriddim_midi_mapping/" + SC5000M_REVISION + "/"
SC5000M_SOURCES = [
    ("PRIME_MIDI_SPEC.md", "033a337fe32b5bd866d0831ce9d5ce495c6c71b4959f256b126ab03a8caa64be"),
    ("README.md", "c8d98ea69fc90ecfccb8cfbb373a3a1f7887d73474ad9087ff023b4d69f072e0"),
    ("midiproxy.swift", "803afc4aae02c059ee9f6f74f4be120571a3c0ebab175e1cc85d158bc29f7842"),
    ("build_mapping.py", "29a2b6c56954190e57d8fb59f37f7e9f33a8f5531bab83025c0823e6ee57f01e"),
    ("IOS_PORT_PLAN.md", "66fad9f1be72cf22658be196fbf902b44f00e5484f835cdf065b8aafe804a926"),
]
SC5000M_REFERENCES = {SC5000M_NAME: {
    "url": SC5000M_BASE + SC5000M_SOURCES[0][0], "sha256": SC5000M_SOURCES[0][1],
    "revision": SC5000M_REVISION,
    "relatedSources": [{"url": SC5000M_BASE + name, "sha256": digest} for name,digest in SC5000M_SOURCES],
    "review": "Author captures and working proxy/mapping independently identify SC5000M Computer-mode channel0, LAYER Note11, shared Shift26 and software-owned pad modes27..30 with raw pads32..39. Native decoder starts on A/Hot Cue, toggles A/B on fresh LAYER presses and keeps pad modes per deck. Releases retain their original deck/logical pad address across layer/mode changes. Native normal transport follows the working mapping: Play1, Cue2, jump3/4, loop8/9/10, Load18, Sync20, Keylock22, held bend24/25, relative loop CC3/browser CC6. Loop Out uses native out-or-exit. Hardware track-skip5/6 is not mislabelled library selection. Hot Cue1..8 and auto-loop1/16,1/8,1/4,1/2,1,2,4,8 retain source modes; Roll/Slicer remain inactive. Captures contradict LC6000 assumptions: no Note40 touch is emitted; CC17/49 and54/55 plus pitch bend are motor/platter reports. They never become tempo or jog input. Source discovers motor start CC65/67 and stop66/68 with value ignored,3683 ticks/revolution and motor rate near2000 ticks/second. Those facts do not establish safe native motor/hand inference, so no motor command is sent. Main screen is a separate15e4:a00a USB device, not a MIDI display. Manual raw Computer-mode selection and separate audio are required; the author reports iOS MIDI enumeration but this project has no physical proof. Pitch slider polarity/range, full modes/output/lifecycle and physical/A10X acceptance remain open. No SC5000/SC6000/SC6000M/LC6000 sibling compatibility is inferred.",
}}


def sc5000m_profiles():
    result = profile(SC5000M_NAME, SC5000M_REFERENCES[SC5000M_NAME]["url"])
    result.update(definition="reviewed:sc5000m-captured-core", role="accessory", autoSelect=False, inputProtocol="sc5000M",
                  aliases=[SC5000M_NAME,"Denon SC5000M PRIME","SC5000M PRIME","SC5000M Prime Controller Jack 1"],
                  excludedAliases=["SC5000 PRIME","SC6000 PRIME","SC6000M PRIME","LC6000 PRIME","SC5000M Proxy"],
                  hardwareMode="Manual raw SC5000M Computer-mode MIDI input. Native LAYER toggles A/B, starting A. Per-deck Hot Cue and auto-loop pad modes are software-owned. Motor/platter/display remain inactive; separate audio required.",
                  scope="Manual source-local two-deck transport, loops, held pitch bend, browser, Hot Cue1–8 and source-sized auto-loop pads. Motor/platter, pitch slider, screen, full output/lifecycle and physical acceptance remain open.")
    add(result,"shift",4,26)
    for channel,deck in enumerate("ab"):
        for action,number in [("play",1),("cuePreview",2),("sync",20),("keylock",22),
                              ("pitchBendDown",24),("pitchBendUp",25),("jumpBack",3),("jumpForward",4),
                              ("load",18),("loopIn",8),("loopOutOrExit",9),("loop",10)]:
            add(result,action,channel,number,deck=deck)
            result["inputs"][-1]["shifted"] = False
            if action not in {"cuePreview","pitchBendDown","pitchBendUp"}:
                release=deepcopy(result["inputs"][-1]);release.update(shifted=True,releaseOnly=True)
                result["inputs"].append(release)
        for slot,beats in enumerate([0.0625,0.125,0.25,0.5,1,2,4,8]):
            add(result,f"hotcue{slot+1}",channel,64+slot,deck=deck)
            result["inputs"][-1]["shifted"] = False
            release=deepcopy(result["inputs"][-1]);release.update(shifted=True,releaseOnly=True)
            result["inputs"].append(release)
            add(result,"toggleFixedLoop",channel,80+slot,deck=deck)
            result["inputs"][-1].update(argument=beats,shifted=False)
            release=deepcopy(result["inputs"][-1]);release.update(shifted=True,releaseOnly=True)
            result["inputs"].append(release)
        add(result,"loopSize",channel,3,"control","twosComplement",deck)
        result["inputs"][-1]["shifted"] = False
        add(result,"browse",channel,6,"control","twosComplement")
        result["inputs"][-1]["shifted"] = False
    result["gaps"]=["Manual raw Computer-mode only. Motor/platter hand inference, measured native gearing, pitch slider polarity/range, screen/touch bulk protocol, hardware track-skip loading, Roll/Slicer/Shift alternatives, dynamic per-deck lamp shadowing, complete setup/output/lifecycle/audio and physical/A10X acceptance remain open. No motor output, factory reset or sibling protocol is sent or inferred. Native LAYER selects A/B only."]
    return [result]

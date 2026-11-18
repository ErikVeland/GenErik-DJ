"""BCR2000 factory-preset core from independent pinned source."""
from curated import add, profile
from numark import UPSTREAM

BCR_NAME = "Behringer BCR2000"
BCR_SOURCES = [
    ("Behringer BCR2000.midi.xml", "e961989dc4bacae20715a575b259a9b869eb3b032406df12a96afe3c56e39671"),
    ("Behringer-BCR2000-scripts.js", "87ab64b1d3b61c824f3bc0bfa8075df8e06b77483eb8dbba23112cfeedf876cb"),
    ("Behringer-BCR2000-preset-scripts.js", "83ea7da36aa208082f7758751ced8bbd8eebca241ff85b75768f5587de8f1bf6"),
    ("Behringer-Extension-scripts.js", "6c175dcf576804ccb09389075550b08f483c7c1c53569bad9d8d548ee4d0da89"),
    ("midi-components-0.0.js", "f15845d0b3fa10609aedc2fb74a9067d0f1d89387f011de72c3301799003f026"),
]
BCR_REFERENCES = {BCR_NAME: {
    "url": UPSTREAM + BCR_SOURCES[1][0], "sha256": BCR_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in BCR_SOURCES] +
                      [{"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/behringer_bcr2000"}],
    "review": "Independent script selects factory preset1 with Program Change C0/00. The source sendShortMsg third argument is not a third wire byte. No preset dump, factory reset or persistent programming is sent. Factory preset1 uses wire channel0. Push-encoder group2 CC9/10/11/12 controls A filter/low/mid/high and CC13/14/15/16 controls B. Source EQ/filter parameters and feedback are absolute0..127. Keylock CC65/69 uses components.Button default push state, not a positive-edge software toggle. Native direct state preserves both default Toggle On hardware127/0 presses and optional Toggle Off press/release. Shift CC68/72 writes one shared global state; one shared input identity preserves last-message state rather than independent held-button OR. Only the normal native layer is enabled. Source default pitch/loop/reverse and effect controls remain inactive. Eight normal parameter rings and two keylock CC lamps retain independent source addresses/values. Shift-lamp feedback synchronisation, complete layers/output/lifecycle, custom presets, USB endpoint qualification and physical/A10X acceptance remain open. The BCR2000 has no audio interface. No BCF2000/DDM4000/CMD sibling protocol or audio route is inferred.",
}}


def bcr2000_profiles():
    result = profile(BCR_NAME, BCR_REFERENCES[BCR_NAME]["url"])
    result.update(definition="reviewed:bcr2000-factory-preset", role="accessory",
                  excludedAliases=["BCF2000", "Behringer BCF2000", "DDM4000", "CMD MM-1"],
                  hardwareMode="Factory preset1 selected automatically through a paired output. Push-encoder group2 provides fixed native A/B filter/EQ. Default latched buttons retain direct on/off state. Custom presets are not rewritten.",
                  scope="Automatic factory-preset normal EQ/filter and direct keylock state, with core CC feedback and shared Shift guard. Complete modes/output/lifecycle and physical acceptance remain open.")
    result["startup"] = [[0xC0, 0]]
    for number in [68, 72]:
        add(result, "shift", 0, number, "control")
        result["inputs"][-1]["shiftInput"] = 0
    for index, deck in enumerate("ab"):
        for offset, action in enumerate(["filterKnob", "low", "mid", "high"]):
            number = 9 + index*4 + offset
            add(result, action, 0, number, "control", deck=deck)
            result["inputs"][-1]["shifted"] = False
            result["outputs"].append(dict(action=("filter" if offset==0 else action)+deck.upper(), kind="control", channel=0,
                                          number=number, targetDeck=deck, onValue=127, offValue=0, offUsesNoteOn=False))
        add(result, "keylockState", 0, 65+index*4, "control", deck=deck)
        result["inputs"][-1]["shifted"] = False
        result["outputs"].append(dict(action="keylock"+deck.upper(), kind="control", channel=0,
                                      number=65+index*4, targetDeck=deck, onValue=127, offValue=0, offUsesNoteOn=False))
    result["gaps"] = ["Factory preset1 must retain its documented addresses. Custom presets are not overwritten. Fixed native normal group2 EQ/filter and keylock only. Source pitch/loop/reverse/FX, filter/kill buttons, shared Shift-lamp synchronisation, complete modes/output/lifecycle and physical/A10X acceptance remain open. No audio interface or sibling protocol is inferred."]
    return [result]

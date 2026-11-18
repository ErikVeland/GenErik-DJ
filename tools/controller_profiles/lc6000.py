"""LC6000 control-port facts from the factory table and pinned source dispatch."""
from copy import deepcopy
from curated import add, profile

LC6000_GUIDE = "https://cdn.inmusicbrands.com/denondj/lc6000/LC6000-PRIME-MIDI-Specification-v1.0.pdf"
LC6000_REVISION = "8dad996b82adac5283b0ed496e8fda58781f1892"
LC6000_BASE = "https://raw.githubusercontent.com/schmic/mixxx-denon-lc6000/" + LC6000_REVISION + "/"
LC6000_SOURCES = [
    ("Denon-LC6000-Prime.midi.xml", "38078c2e5b8d63d04d343741c8b3ce9c4bf8402c1ff063f3885c078131461954"),
    ("Denon-LC6000-Prime-scripts.js", "79349ce9ec26e9360d7404598e81631226e1fb22dcfaff4305962b21aafa4928"),
]
LC6000_REFERENCES = {"Denon LC6000 PRIME": {
    "url": LC6000_GUIDE, "sha256": "9fde4d92bc3fa604236678d9d72833dbf669383e7427f33d490c05f872962112", "pages": [2, 3, 4, 5, 6],
    "relatedSources": [{"url": LC6000_BASE + name, "sha256": digest, "revision": LC6000_REVISION} for name, digest in LC6000_SOURCES],
    "review": "Factory messages establish controls on MIDI channel zero, paired pitch 8/40, jog 55/54 and separate display SysEx. Pinned XML dispatch resolves the table's ambiguous jog wording: CC55 selects direction; CC54 carries forward value or reverse value minus 127. CC17/49 handlers are explicit no-ops and remain unmapped. Native scratch retains the source's 1024-count calibration. Explicit PR port matching isolates control from WD display, with existing player allocation for independent units. Hot Cue and fixed-loop pages retain mode guards; Roll/Slicer remain blocked. Shared pad feedback, display SysEx, strip, software vinyl/zoom/range modes, full lights/cleanup and physical qualification remain open.",
}}


def lc6000_profiles():
    result = profile("Denon LC6000 PRIME", LC6000_GUIDE)
    result["aliases"].extend(["Denon DJ LC6000 PRIME", "LC6000", "LC6000 PR", "Denon DJ LC6000 PRIME LC6000 PR"])
    result.update(role="player", portAliases=["LC6000 PR", "LC6000 PR MIDI 1", "PR", "Denon DJ LC6000 PRIME LC6000 PR"],
                  scope="Automatic PR-port player core with independent deck allocation, 1024-count native touch scratch, paired pitch, held bend, Cue, loops and browsing. WD display, strip, full modes/feedback/cleanup and physical qualification remain open.")
    result["inputModes"] = [{"channel": 0, "initial": 27, "numbers": [27, 28, 29, 30], "onValue": 127, "offValue": 0}]
    result["startup"] = [[0x90, note, 0] for note in [28, 29, 30]] + [[0x90, 27, 127], [0x90, 19, 127]]
    add(result, "shift", 0, 26)
    for action, number in [("play", 1), ("cuePreview", 2), ("sync", 20), ("keylock", 22),
                           ("pitchBendDown", 24), ("pitchBendUp", 25), ("load", 18),
                           ("jumpBack", 3), ("jumpForward", 4)]:
        add(result, action, 0, number, deck="a", feedback=action in {"play", "sync", "keylock"})
        result["inputs"][-1]["shifted"] = False
        if action not in {"cuePreview", "pitchBendDown", "pitchBendUp"}:
            release = deepcopy(result["inputs"][-1])
            release.update(shifted=True, releaseOnly=True)
            result["inputs"].append(release)
    for action, number in [("loopIn", 8), ("loopOut", 9), ("loop", 10)]:
        add(result, action, 0, number, deck="a", feedback=action == "loop")
    add(result, "loopSize", 0, 3, "control", "twosComplement", "a")
    result["inputs"][-1]["shifted"] = False
    add(result, "jogTouch", 0, 40, deck="a")
    add(result, "jog", 0, 55, "control", "lc6000Jog", "a")
    result["inputs"][-1].update(lowNumber=54, argument=1024)
    add(result, "tempo", 0, 8, "control", "paired14Bit", "a")
    result["inputs"][-1].update(lowNumber=40, inverted=True)
    add(result, "browse", 0, 6, "control", "twosComplement")
    result["inputs"][-1]["shifted"] = False
    for action, number in [("browsePrevious", 5), ("browseNext", 6)]:
        add(result, action, 0, number)
        result["inputs"][-1]["shifted"] = False
        release = deepcopy(result["inputs"][-1])
        release.update(shifted=True, releaseOnly=True)
        result["inputs"].append(release)
    for slot, beats in enumerate([0.125, 0.25, 0.5, 1, 2, 4, 8, 16]):
        add(result, f"hotcue{slot + 1}", 0, 32 + slot, deck="a")
        result["inputs"][-1].update(requiredMode=27, shifted=False)
        release = deepcopy(result["inputs"][-1])
        release.update(shifted=True, releaseOnly=True)
        result["inputs"].append(release)
        add(result, "toggleFixedLoop", 0, 32 + slot, deck="a")
        result["inputs"][-1].update(requiredMode=30, argument=beats)
    result["shutdown"] = [[0x90, note, 0] for note in [1, 10, 19, 20, 22, 27, 28, 29, 30]]
    return [result]

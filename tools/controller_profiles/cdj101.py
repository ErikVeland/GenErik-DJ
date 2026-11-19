"""Independent CDJ-101 player controls after bounded native input normalisation."""
from curated import add, profile
from numark import UPSTREAM

CDJ101_SOURCES = [
    ("DJ-Tech CDJ-101.midi.xml", "67b81fe30a79ae834367c55bfb0f8808b7efa1d2b9b13e9d9a85d01548d01648"),
    ("DJ-Tech-CDJ-101-scripts.js", "15c2091a3f39bad84bf8c7d95ae959a441cb41b755fd444a919fdc65cc13562d"),
    ("common-controller-scripts.js", "27bad1799146932e2184995d4ab5eb7c1c2a09e0e909284249d6030f7edccdf3"),
]
CDJ101_REFERENCES = {"DJ-Tech CDJ-101": {
    "url": UPSTREAM + CDJ101_SOURCES[1][0], "sha256": CDJ101_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + filename.replace(" ", "%20"), "sha256": digest}
                       for filename, digest in CDJ101_SOURCES] +
                      [{"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/dj_tech_cdj_101"}],
    "review": "Independent XML/source use wire channels0/1: Play42, held Cue43, contact32, browser push31, inner jogCC54/outer53, browserCC56 and standard14-bit pitch. Native source-local input converts browser raw65 to logical+1, every other seven-bit value to-1, and emits logical Note126 Load only on owned push release before200 ms. Repeat presses cannot shorten the interval; backwards/late/unowned releases cannot load. Callback arrival timestamps survive the inbox so main-thread delay cannot compress two separate callback times. Source script.pitch delegates to midiPitch, preserving the14-bit value; native pitch normalisation follows the reviewed source rate direction. Source143 ticks at45 RPM becomes193.05 effective native33⅓-RPM ticks, preserving60/(45*143) seconds per inner tick. Player allocation replaces hard-coded software deck ownership. Native fixed touch replaces source100 ms spinback handover. Shifted Play supplies Sync; shifted browser supplies groups. Shifted cue/grid/scan and fine outer-wheel variants remain inactive. Output channel ownership, full lights/lifecycle/calibration and physical/A10X acceptance remain open. No downloaded script executes in the app.",
}}


def cdj101_profiles():
    result = profile("DJ-Tech CDJ-101", CDJ101_REFERENCES["DJ-Tech CDJ-101"]["url"])
    result.update(definition="reviewed:cdj101", role="player", inputProtocol="cdj101",
                  excludedAliases=["DJ-Tech Kontrol One", "Kontrol One", "DJ-Tech DJM-101", "DJM-101"],
                  hardwareMode="CDJ-101 USB-MIDI channel1 or2. Native software deck allocation is independent of the wire channel. Browser push is Shift; a release before200 ms loads.",
                  scope="Automatic player input core with source-timed short-click Load, exact track/group browser direction, Play, held Cue, shifted Sync, pitch and fixed native touch/count jog. Full spinback/Shift modes/output and physical acceptance remain open.")
    for channel in [0, 1]:
        add(result, "shift", channel, 31)
        for action, number, shifted in [("play", 42, False), ("sync", 42, True), ("cuePreview", 43, False)]:
            add(result, action, channel, number, deck="a")
            result["inputs"][-1]["shifted"] = shifted
        add(result, "load", channel, 126, deck="a")
        add(result, "jogTouch", channel, 32, deck="a")
        for action, number in [("jog", 54), ("wheelJog", 53)]:
            add(result, action, channel, number, "control", "binaryOffset", "a")
            result["inputs"][-1].update(shifted=False, argument=193.05)
        add(result, "tempo", channel, 0, "pitch", deck="a")
        result["inputs"][-1]["inverted"] = True
        for action, shifted in [("browse", False), ("browseGroups", True)]:
            add(result, action, channel, 56, "control", "twosComplement")
            result["inputs"][-1]["shifted"] = shifted
    result["gaps"] = ["Fixed native touch/count response replaces source delayed100 ms outer-to-inner spinback handover. Shifted cue/grid/scan and fine outer-wheel alternatives, exact outer-wheel response and physical tick calibration remain open. Active wire-channel ownership must be qualified before lights/output. Full feedback/lifecycle and physical/A10X acceptance remain open. No audio route or other DJ-Tech player protocol is inferred."]
    return [result]

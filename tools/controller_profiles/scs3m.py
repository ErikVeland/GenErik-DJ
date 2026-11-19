"""SCS.3m fixed native mixer inputs behind paced transient mode setup."""
from curated import add, profile
from numark import UPSTREAM

SCS3M_NAME = "Stanton SCS.3m"
SCS3M_SOURCES = [
    ("Stanton SCS.3m.midi.xml", "b32516ac22c7853c31690e0e017de4aefdbf7ad34fe2a80187a2fb4e209a06a5"),
    ("Stanton-SCS3m-scripts.js", "f4f3fcc33a16a862c1ea9c5eb971f4b8ee14886b716907c536a2cd9b73dffb42"),
]
SCS3M_REFERENCES = {SCS3M_NAME: {
    "url": UPSTREAM + SCS3M_SOURCES[1][0], "sha256": SCS3M_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + filename.replace(" ", "%20"), "sha256": digest} for filename, digest in SCS3M_SOURCES] +
                       [{"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/stanton_scs3m"}],
    "review": "Independent source defines transient flat mode F0/00/01/60/15/01/F7. Slider modes use channel16 CCid/70 absolute followed immediately by CCid/7F termination, then20 ms settling. Source explicitly uses absolute mode for top0/1 and volume8/9 sliders. Native fixed A/B layout selects those four absolute modes after flat mode; EQ2..7 and crossfader10 retain the flat source's absolute interpretation. Each delay begins after actual send completion. Startup requires one paired physical output; input stays inactive until the last settling interval completes. Earlier queued frames cannot dispatch, while later valid frames retain their hardware-ready timestamp. Left/right CC0/1 controls native absolute filter instead of source relative filter; EQ low2/3,mid4/5,high6/7,volume8/9, crossfader10 and PFL Notes8/9 retain wire assignments. Soft/FX/EQ/Master/deck buttons0..7/10..16 are separate held guards in this fixed layout. Source software deck/FX/Master modes, relative alternatives, meters/lighting, delayed shutdown and full lifecycle remain open. No factory reset F0/00/01/60/40/F7, persistent preset, sibling protocol or audio route is inferred. Manual application without an established automatic paired setup session is rejected. Physical/A10X acceptance remains open.",
}}


def scs3m_profiles():
    result = profile(SCS3M_NAME, SCS3M_REFERENCES[SCS3M_NAME]["url"])
    result.update(definition="reviewed:scs3m-fixed-mixer", role="accessory",
                  excludedAliases=["Stanton SCS.3d", "SCS.3d", "Stanton SCS.1m", "SCS.1m"],
                  hardwareMode="Automatic fixed native A/B EQ mixer after paced transient flat/absolute setup through one paired MIDI output. Software deck/FX/Master alternatives remain inactive.",
                  scope="Automatic fixed native mixer input core with paced startup, EQ/level/filter/PFL/crossfader and held modifier guards. Complete software modes/output/lifecycle and physical acceptance remain open.")
    result["startup"] = [[0xF0, 0, 1, 96, 21, 1, 0xF7]]
    result["startupDelaysMilliseconds"] = [20]
    for number in [0, 1, 8, 9]:
        result["startup"] += [[0xBF, number, 112], [0xBF, number, 127]]
        result["startupDelaysMilliseconds"] += [0, 20]
    for number in list(range(8)) + list(range(10,17)):
        add(result, "shift", 0, number)
    for index, deck in enumerate("ab"):
        for action, number in [("filterKnob", index), ("low", 2+index), ("mid", 4+index), ("high", 6+index), ("level", 8+index)]:
            add(result, action, 0, number, "control", deck=deck)
            result["inputs"][-1]["shifted"] = False
        add(result, "cue", 0, 8+index, deck=deck)
        result["inputs"][-1]["shifted"] = False
    add(result, "crossfader", 0, 10, "control")
    result["inputs"][-1]["shifted"] = False
    result["gaps"] = ["Fixed native A/B EQ mixer only. Absolute top sliders deliberately replace source relative filter response. Software C/D/deck/FX/Master selection, slider resets and relative alternatives, soft-button FX assignments, coordinated SCS.3d state, meters/lighting, delayed shutdown/full lifecycle and physical/A10X acceptance remain open. Manual setup without an established automatic paired session is not implemented. No factory reset, persistent preset or audio interface is inferred."]
    return [result]

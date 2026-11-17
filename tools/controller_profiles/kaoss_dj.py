"""KAOSS DJ factory protocol with separate normal and manual audioless layouts."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

KAOSS_MIDI = "https://cdn.korg.com/us/support/download/files/9015867d23596afc1635ec139a8cdfb4.txt"
KAOSS_GUIDE = "https://cdn.korg.com/us/support/download/files/3712d559e956c0edb50a9c9e8b1e1d4e.pdf"
KAOSS_MAPPING = "https://manual.mixxx.org/2.5/en/hardware/controllers/korg_kaoss_dj"
KAOSS_SOURCES = [
    ("Korg-KAOSS-DJ.midi.xml", "85d2555f1ff54adee404f0443df3f2af4363090f1cde762371d11413c8aa6285"),
    ("Korg-KAOSS-DJ-scripts.js", "e67f4d1af9e0f73d760425d9cf207738c64d662ffeca2ca79faf3676dcf2fb00"),
]
KAOSS_REFERENCE = {
    "url": KAOSS_MIDI, "sha256": "f03b44a51510f6ec6a9788d65aa7a96ebdcebeb9b219e59c5514e98d63ff4ca7",
    "relatedSources": [{"url": KAOSS_GUIDE, "sha256": "ec8da87bf0b36037d536a572fcc6f820c501b934a6aeba7eb56a7630864e301c", "pages": [2, 5, 6, 7, 9, 10, 11]}, {"url": KAOSS_MAPPING}] +
        [{"url": UPSTREAM + name, "sha256": digest} for name, digest in KAOSS_SOURCES],
    "review": "Factory MIDI1.0 table establishes fixed channels6 global/7 A/8 B, full-value contact, separate normal14/scratch16/Shift15 jog streams, distinct three-cue/loop-page buttons, seven-bit pitch/mixer controls and separate note/CC LED commands. Pinned working source supplies signed jog magnitude,128-count scale and4x Shift scratch; native fixed scratch also handles the normal stream while contact is held. Shift scratch needs contact and uses32-count resolution. Local physical-side Shift guards performance alternatives; both physical Shift inputs also feed a source-local global layer for shared Load/browser routing. Native Shift+Play toggles Key Lock, Shift strip uses native seek, three cues retain shifted delete-release aliases and loop pads retain source manual In/Out/toggle alternatives. Native held bend retains ownership. Factory main/headphone/balance inputs exist only in Audioless mode, so the automatic normal recipe omits them. A separate manually selected Audioless recipe adds software gain/blend without claiming audio output or factory lifecycle. Normal audio uses the mapping author's master1/2/headphones3/4 layout; selecting the output wakes the hardware from standby. Native outputs use factory on127/off0. Startup enables eight deck-knob lamps and fixed Scratch indicators, clears unsupported loop-side lamps; shutdown clears these and20 owned outputs within48messages. The copied Serato proprietary status SysEx is not in the published implementation and is omitted. Identity inquiry is not an analogue query. Scratch toggle, Shift Sync cancel, complete browser/mode/FX/sampler/meter/reset behaviour, Audio Return routing, calibration and physical acceptance remain open.",
}
KAOSS_REFERENCES = {name: deepcopy(KAOSS_REFERENCE) for name in ["Korg KAOSS DJ", "Korg KAOSS DJ (Audioless)"]}


def kaoss_profiles():
    result = profile("Korg KAOSS DJ", KAOSS_MIDI)
    result.update(audioOutput="masterAndHeadphones", hardwareMode="Controller startup mode with built-in audio. Audioless mode requires its separate manual profile.", scope="Automatic two-deck KAOSS DJ core with128-count fixed scratch,4x held Shift scratch, native Cue/bend, three cues, loops, seek, Key Lock and documented split audio. Proprietary status query, full modes/FX/meters, calibration and physical acceptance remain open.")
    for side, deck in enumerate("ab"):
        channel = 7 + side
        for scope in [side, None]:
            add(result, "shift", channel, 26)
            result["inputs"][-1]["shiftInput"] = side
            if scope is not None:
                result["inputs"][-1]["shiftChannel"] = scope
        def local(action, number, shifted=False, alternate=None):
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1].update(shifted=shifted, shiftChannel=side)
            if alternate is not None:
                release = deepcopy(result["inputs"][-1])
                release.update(number=alternate, shifted=not shifted, releaseOnly=True)
                result["inputs"].append(release)
        for action, number in [("play", 27), ("cuePreview", 30), ("sync", 29), ("cue", 25)]:
            local(action, number)
        local("keylock", 27, shifted=True)
        add(result, "load", channel, 14, deck=deck)
        result["inputs"][-1]["shifted"] = False
        add(result, "browsePreviousGroup" if side == 0 else "browseNextGroup", channel, 14)
        result["inputs"][-1]["shifted"] = True
        add(result, "jogTouch", channel, 31, encoding="fullVelocityGate", deck=deck)
        for number, counts in [(14, 128), (16, 128), (15, 32)]:
            add(result, "jog", channel, number, "control", "twosComplement", deck)
            result["inputs"][-1]["argument"] = counts
            if number != 14:
                result["inputs"][-1]["requiresTouch"] = True
        add(result, "tempo", channel, 25, "control", "centreDetent", deck)
        result["inputs"][-1]["inverted"] = True
        for action, number in [("level", 24), ("gain", 26), ("high", 27), ("mid", 28), ("low", 29)]:
            add(result, action, channel, number, "control", deck=deck)
        for slot in range(3):
            local(f"hotcue{slot + 1}", 18 + slot, alternate=43 + slot)
        for action, number, alternate in [("loopDown", 15, 40), ("loop", 16, 41), ("loopUp", 17, 42)]:
            local(action, number, alternate=alternate)
        for action, number, alternate in [("loopIn", 40, 15), ("loop", 41, 16), ("loopOut", 42, 17)]:
            local(action, number, shifted=True, alternate=alternate)
        local("pitchBendDown", 21)
        local("pitchBendUp", 23)
        add(result, "seek", channel, 33, "control", deck=deck)
        result["inputs"][-1].update(shifted=True, shiftChannel=side)
        for action, number in [("play", 27), ("cuePreview", 30), ("sync", 29), ("cue", 25), ("loop", 16),
                               ("pitchBendDown", 21), ("pitchBendUp", 23)] + [(f"hotcue{slot + 1}", 18 + slot) for slot in range(3)]:
            result["outputs"].append({"action": action + deck.upper(), "targetDeck": deck, "kind": "note", "channel": channel,
                                      "number": number, "onValue": 127, "offValue": 0, "offUsesNoteOn": True})
        for number in range(26, 30):
            result["startup"].append([0xB0 + channel, number, 127])
            result["shutdown"].append([0xB0 + channel, number, 0])
        result["startup"] += [[0x90 + channel, 15, 0], [0x90 + channel, 17, 0], [0x90 + channel, 22, 127]]
        result["shutdown"] += [[0x90 + channel, number, 0] for number in [15, 17, 22]]
    add(result, "crossfader", 6, 23, "control")
    for action, shifted in [("browse", False), ("browseGroups", True)]:
        add(result, action, 6, 30, "control", "signedStep")
        result["inputs"][-1]["shifted"] = shifted
    add(result, "openGroup", 6, 11)
    result["inputs"][-1]["shifted"] = False
    result["shutdown"] += [[0x90 + r["channel"], r["number"], 0] for r in result["outputs"]]
    audioless = deepcopy(result)
    audioless.update(id="Korg KAOSS DJ (Audioless)", catalogueName="Korg KAOSS DJ", definition="manufacturer:korgkaossdjaudioless",
                     aliases=["Korg KAOSS DJ Audioless", "KAOSS DJ Audioless"], autoSelect=False, startup=[], shutdown=[],
                     hardwareMode="Manual profile for Audioless startup mode; external audio interface required.",
                     scope="Manual Audioless variant adds software master/headphone gain and cue blend to the reviewed KAOSS core. No built-in audio route or factory lifecycle is claimed. Other modes, calibration and physical acceptance remain open.")
    del audioless["audioOutput"]
    for action, number in [("monitor", 20), ("cueMix", 21), ("master", 22)]:
        add(audioless, action, 6, number, "control")
    return [audioless, result]

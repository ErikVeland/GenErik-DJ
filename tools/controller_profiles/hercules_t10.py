"""T10 supplemental controls from its independent manufacturer factory document."""
from curated import add, profile
from inpulse200mk3 import MK3_FACTORY

T10_NAME = "Hercules DJControl T10"
T10_MANUAL = "https://ts.hercules.com/download/sound/manuals/DJC_T10/HERCULES_DJC_T10_USER_MANUAL_-_EN_FR_DE_NL_IT_ES_PT_PL_JP_CNM_KO.pdf"
T10_REFERENCES = {T10_NAME: {
    "url": MK3_FACTORY, "sha256": "a76200de7cc2fced9b765d83edd02c8a07aa302d77c87c81ddf2f4c91330e2a2",
    "member": "djuced_6.8.1.pkg/djuced.pkg/Payload/Applications/DJUCED/DJUCED.app/Contents/Resources/midi/DJControl T10.djm",
    "memberSHA256": "a934c2747ae15b614133313aca2f40c199a883b913e733a129c05c7326ffe10d",
    "relatedSources": [{"url": T10_MANUAL, "sha256": "3a81264c2b9fe97f2d89f3761664cd3417b325aceefc5075e1c1473512d70012"}],
    "review": "Separate user-visible factory XML has439 device controls and454 action rows. Native85-input manual supplemental layout retains deck channels2/3, shifted5/6 and pad7/8. Qualified physical Shift Note4 uses independent sides and both transitions retire side holds/pickup. Normal volume/filter/three-band EQ/gain, shifted filter/EQ/gain, PFL/Load/Sync, loop In/Out/current-size toggle/size, Shift-loop half/double/keylock, eight Hot Cues per deck and normal/shifted library controls use their own wires. Shifted line volume targets sampler decks and is inactive. Native loop press uses current size rather than source fixed4. Manufacturer manual PDF26 explicitly says motorisation cannot be disabled. The generic mapping does not qualify the complete motor/platter packet, calibration and coupled lifecycle contract. Play, main Cue, tempo, platter/wheel packets, RPM/motor modes, startup F000014E2202077F000000000000F7, onexit B07F7E, output, settings and automatic audio remain inactive. No stationary-platter mode or T7/MK3 sibling protocol is invented. Manual selection and separate app audio are required. Native touch transport remains necessary. Full control support and physical/iPad acceptance remain open."
}}


def t10_profiles():
    result = profile(T10_NAME, MK3_FACTORY)
    result.update(autoSelect=False, definition="reviewed:hercules-t10-supplemental-factory",
                  aliases=[T10_NAME, "DJControl T10"],
                  excludedAliases=["DJControl Inpulse T7", "DJControl Inpulse 200 MK3"],
                  hardwareMode="Manual supplemental mixer, pads, loops and library controls only. Use app touch transport and separate app audio. T10 motor/platter integration is unavailable. Its motors cannot be disabled in a stationary-platter mode.",
                  scope="Manual85-input supplemental layout from the distinct T10 factory mapping. No Play, main Cue, tempo, platter, motor, output, startup or automatic audio command.",
                  gaps=["Manufacturer states that platter motorisation cannot be disabled. The complete motor/platter and coupled transport lifecycle contract remains unqualified. No stationary mode is invented. Manual supplemental controls do not establish a complete T10 controller. Use app touch transport and separate audio. Source fixed4 loop press uses native current-size toggle. Shifted sampler volume, FX/stem/roll/slicer/pitch-play modes, complete feedback, USB ownership, calibration and physical/iPad/A10X acceptance remain open."])
    result["bankChanges"] = []
    for channel, deck in enumerate("ab", 1):
        shifted = channel + 3
        pads = channel + 5
        result["bankChanges"].append(dict(channel=channel, number=4, onValue=127, decks=[deck], releaseShiftChannels=[]))
        add(result, "shift", channel, 4)
        result["inputs"][-1]["shiftChannel"] = channel
        for action, number in [("cue", 12), ("load", 13), ("sync", 5), ("loopIn", 9), ("loopOut", 10), ("loop", 44)]:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=channel)
        for action, number in [("keylock", 82), ("loopDown", 9), ("loopUp", 10)]:
            add(result, action, shifted, number, deck=deck)
            result["inputs"][-1].update(shifted=True, shiftChannel=channel)
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", pads, slot, deck=deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=channel)
            add(result, f"hotcue{slot + 1}", pads, slot + 8, deck=deck)
            result["inputs"][-1].update(shifted=True, shiftChannel=channel, releaseOnly=True)
        for action, number in [("level", 0), ("filterKnob", 1), ("low", 2), ("mid", 3), ("high", 4), ("gain", 5)]:
            add(result, action, channel, number, "control", deck=deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=channel)
        for action, number in [("filterKnob", 1), ("low", 2), ("mid", 3), ("high", 4), ("gain", 5)]:
            add(result, action, shifted, number, "control", deck=deck)
            result["inputs"][-1].update(shifted=True, shiftChannel=channel)
        add(result, "loopSize", channel, 14, "control", "twosComplement", deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=channel)
        for wire, active in [(channel, False), (shifted, True)]:
            add(result, "browse", wire, 15, "control", "twosComplement")
            result["inputs"][-1].update(shifted=active, shiftChannel=channel)
            add(result, "browsePreviousGroup" if active else "openGroup", wire, 81)
            result["inputs"][-1].update(shifted=active, shiftChannel=channel)
    add(result, "crossfader", 0, 0, "control")
    return [result]

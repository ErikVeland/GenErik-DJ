"""Independent Kontrol One wire facts with a fixed native base layout."""
from curated import add, profile
from numark import UPSTREAM

KONTROL_ONE_NAME = "DJ-Tech Kontrol One"
KONTROL_ONE_SOURCES = [
    ("DJ-Tech Kontrol One.midi.xml", "c867803184375965b65e1d49ee5a35e13bff1ba7549e65f7e72d980c814e3989"),
    ("DJ-Tech-Kontrol-One-scripts.js", "4ce919cd968d2e4e8bdcda6db5f1209389ab1efb35c6c89599d5e15fc0855266"),
]
KONTROL_ONE_REFERENCES = {KONTROL_ONE_NAME: {
    "url": UPSTREAM + KONTROL_ONE_SOURCES[0][0].replace(" ", "%20"), "sha256": KONTROL_ONE_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + filename.replace(" ", "%20"), "sha256": digest} for filename, digest in KONTROL_ONE_SOURCES[1:]] +
                       [{"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/dj_tech_kontrol_one"}],
    "review": "Independent XML qualifies four hardware channels0..3 and exact notes/CCs. The selector sends no dedicated MIDI packet; each known input reveals its channel. Source-local decoder marks changes before dispatch, releases owned contacts and resets affected pickup/debounce. Seven physical modifiers keep independent identity across wire channels. Native fixed base layout does not emulate software-only bank/Shift latches. Labelled Sync Note29 controls native Sync rather than source custom resume; Cue28 retains native held-preview release. Raw jogCC32 values>1 are forward,0/1 backward. KnobCC52..55 value127 is forward; other seven-bit values backward. These are normalised separately before native decoding. Native gain/EQ uses bounded0.02 normalised steps rather than the source logarithmic0..4 curve. PitchCC33 retains inverted centred source polarity. Actual scratch defaults use wheelResArray[4]=150 and scratchRevArray[7]=45 RPM, not the unused header scratchRev160. Native33⅓-RPM resolution is202.5 ticks. Source default row2 pads are cues5..8 at14/13/12/11; they are not renumbered1..4. Native fixed-loop toggles1/2/4 and direct loop In/Out/size replace source timed/held editing in the base layout. No input handshake is required by source init. Output depends on the active wire channel, so no unqualified global lighting is sent. Complete banks/Shift latches, kills, custom resume/loops, exact knob response, output/lifecycle/calibration and physical/A10X acceptance remain open.",
}}


def kontrol_one_profiles():
    result = profile(KONTROL_ONE_NAME, KONTROL_ONE_REFERENCES[KONTROL_ONE_NAME]["url"])
    result.update(definition="reviewed:kontrol-one", role="accessory", inputProtocol="kontrolOne",
                  excludedAliases=["DJ-Tech CDJ-101", "CDJ-101", "DJ-Tech DJM-101", "DJM-101"],
                  hardwareMode="Original Kontrol One USB-MIDI channels1..4 select A/B/C/D. Fixed native base layout; software-only alternate banks remain inactive. C/D requires app opt-in.",
                  scope="Automatic fixed native input core: four hardware channels, guarded transport/Cue/Sync, tempo, gain/EQ, fixed touch/count jog, cues5..8 and base loops. Full source modes/output and physical acceptance remain open.")
    for channel, deck in enumerate("abcd"):
        for identity, number in enumerate([25, 30, 1, 2, 3, 4, 26]):
            add(result, "shift", channel, number)
            result["inputs"][-1]["shiftInput"] = identity
        for action, number in [("play", 27), ("cuePreview", 28), ("sync", 29), ("jogTouch", 31),
                               ("reloop", 16), ("loopIn", 24), ("loopOut", 23), ("loopDown", 22), ("loopUp", 21)]:
            add(result, action, channel, number, deck=deck)
        for slot, number in zip(range(5, 9), [14, 13, 12, 11]):
            add(result, f"hotcue{slot}", channel, number, deck=deck)
        for number, beats in [(19, 1), (18, 2), (17, 4)]:
            add(result, "toggleFixedLoop", channel, number, deck=deck)
            result["inputs"][-1]["argument"] = beats
        for action, number in [("gain", 55), ("high", 54), ("mid", 53), ("low", 52)]:
            add(result, action, channel, number, "control", "twosComplement", deck)
            result["inputs"][-1]["directionStep"] = 0.02
        add(result, "tempo", channel, 33, "control", "centreDetent", deck)
        result["inputs"][-1]["inverted"] = True
        add(result, "jog", channel, 32, "control", "twosComplement", deck)
        result["inputs"][-1]["argument"] = 202.5
    for row in result["inputs"]:
        if row["action"] != "shift": row["shifted"] = False
    result["gaps"] = ["Fixed native base only. Software-only bank/Shift latches, kills, source custom resume/slip, cue-loop/move/edit gestures, exact logarithmic knob response, source scratch tuning, dynamic active-channel output ownership, complete feedback/lifecycle/calibration and physical/A10X acceptance remain open. Native Sync, fixed-loop toggles and direct loop controls deliberately replace source custom/timed behaviour. No audio interface is inferred."]
    return [result]

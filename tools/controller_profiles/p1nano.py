"""P1-Nano MIDI1 input facts without inferred motor or display output."""
from curated import add, profile
from numark import UPSTREAM

P1_NAME = "Icon P1-Nano MIDI 1"
P1_SOURCES = [
    ("Icon-P1Nano.midi.xml", "ecbfe0e4fa6086b541de170efff0e9ddb6497a98f4a82e251a8d4a317d9005d0"),
    ("Icon-P1Nano-scripts.js", "d4ef3188fbd5f057b08d91aaf668864a345802fe0fd44bb38958e9e0cd12e4c6"),
]
P1_REFERENCES = {P1_NAME: {
    "url": UPSTREAM + P1_SOURCES[0][0], "sha256": P1_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + filename, "sha256": digest} for filename, digest in P1_SOURCES[1:]] +
                       [{"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/icon_p1_nano"}],
    "review": "Pinned XML/script input dispatch uses selected transport on wire0 Notes94 Play,93 held Cue,91/92 jumps and86 loop; positive Notes24..27 select executable Channel1..4 ownership. XML descriptions/manual tables label some lanes C/A/B/D, unlike actual XML groups and script arrays; native core follows executable A/B/C/D groups explicitly. Default DAW1 Bitwig configuration needs no proprietary remap according to upstream manual. Flip Note50 latches software mode; repeated positive packets cannot toggle twice without release. Normal raw pitch channels0..3 provide full14-bit volume, flipped logical channels4..7 provide centred inverted tempo. Four CC16..19 encoders retain independent gain/high/mid/low/filter assignments. In Flip, raw<64 selects next parameter and other values previous; this includes source zero-value selector behaviour. Otherwise raw<64 adds raw/100 normalised units; raw>=64 subtracts(raw-64)/100. A separate bounded counted codec preserves acceleration and neutral0/64. Knob resets, master-fader midpoint, navigation/focus modes, recording, custom touchscreen notes, motor/display/MCU output and full lifecycle remain inactive. MIDI1 selection stays manual until endpoint, motor/display and USB behaviour are qualified. No P1-M/P1-X or generic MCU alias is inferred. Physical/A10X acceptance remains open.",
}}


def p1nano_profiles():
    result = profile(P1_NAME, P1_REFERENCES[P1_NAME]["url"])
    result.update(definition="reviewed:p1-nano-midi1", role="accessory", autoSelect=False, inputProtocol="p1Nano",
                  excludedAliases=["P1-Nano MIDI 2", "P1-Nano MIDI 3", "P1-M", "P1-X"],
                  hardwareMode="Manual P1-Nano MIDI1 input with default DAW1 Bitwig configuration. Native lanes follow executable A/B/C/D source groups. C/D requires app opt-in. Motor/display output remains inactive.",
                  scope="Manual source-local selected transport, latched Flip, full14-bit volume/tempo faders and four independently selected gain/EQ/filter encoders. Motor/display/navigation/reset/lifecycle and physical acceptance remain open.")
    for channel, deck in enumerate("abcd"):
        for action, number in [("play", 94), ("cuePreview", 93), ("jumpBack", 91), ("jumpForward", 92), ("loop", 86)]:
            add(result, action, channel, number, deck=deck)
        add(result, "level", channel, 0, "pitch", deck=deck)
        add(result, "tempo", channel+4, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1]["inverted"] = True
        for parameter, action in enumerate(["gain", "high", "mid", "low", "filterKnob"]):
            add(result, action, channel, 16+parameter, "control", "p1NanoEncoder", deck)
    result["gaps"] = ["Manual MIDI1/default DAW1 input only. Source descriptions differ from executable lane groups; native A/B/C/D contract needs physical confirmation. Motor/position feedback, display/ring/meters, master-fader midpoint, knob resets, custom touchscreen controls, recording/navigation/keyboard modes, endpoint/USB qualification, complete lifecycle/calibration and physical/A10X acceptance remain open. No generic MCU or P1-M/P1-X compatibility is inferred."]
    return [result]

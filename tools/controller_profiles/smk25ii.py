"""SMK-25 II logical native controls after its bounded vendor input decoder."""
from curated import add, profile
from numark import UPSTREAM

SMK25_SOURCES = [
    ("MVave-SMK-25-II.midi.xml", "d5e0f9762e78ca33c654cd889595cc4a5ab0268c42b43c13cbdff1dd2c07c0f5"),
    ("MVave-SMK-25-II-scripts.js", "17a9805035cc7e92321a9c386d000329401a66eecab6ab74a32d1bd79f9f4d13"),
]
SMK25_REFERENCES = {"M-Vave SMK-25 II": {
    "url": UPSTREAM+SMK25_SOURCES[0][0], "sha256": SMK25_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM+SMK25_SOURCES[1][0], "sha256": SMK25_SOURCES[1][1]},
                       {"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/mvave_smk-25-ii"}],
    "review": "Pinned source sends deck controls inside F0 35 59 command data value F7, not ordinary Note messages. Native inputProtocol smk25II consumes exactly7 bytes, rejects invalid headers/commands/status bytes, retains fragments per source and preserves mixed strip/SysEx order. Command10 contains Note0..7 Hot Cues, Play94, main Cue93, backward91, forward92, Reloop76 and unimplemented Record95. Released selectors46/47 choose fixed A/B software targets; selection releases source-owned contacts and resets only deck pickup. Commands60..67 map gain30, high31, mid32, low33, filter34, crossfader35, monitor36 and master37. The source's unused data byte remains seven-bit validated. Ordinary channel0 PitchBend and CC1 supply tempo and level; CC30..37 follow the same routing. Channel9 sampler notes and unrelated standard MIDI notes are not converted. Listed profile inputs are logical messages after this adapter, not claimed wire Note addresses. Factory inputs already use the MIDI1 byte port. Initial software deck is A as in the source. The script reports immediate firmware releases for some pads; native code cannot infer physical hold duration. Source pitch direction follows existing Mixxx normalisation. No downloaded code runs. Samplers, recording, Bluetooth pairing, duplicate routes, hardware lamps/colours, full lifecycle, calibration and physical/A10X acceptance remain open. Original SMK-25 is not an alias.",
}}


def smk25_profiles():
    result = profile("M-Vave SMK-25 II", SMK25_REFERENCES["M-Vave SMK-25 II"]["url"])
    result["definition"] = "reviewed:smk25-ii"
    result["inputProtocol"] = "smk25II"
    result["excludedAliases"] = ["SMK-25", "M-Vave SMK-25", "SMC-Mixer", "SMK-25 Mini"]
    result["hardwareMode"] = "Named SMK-25 II USB-MIDI endpoint. Native adapter decodes deck-layer SysEx and ordinary strips. Initial software target A; released deck selectors choose A/B. Bluetooth pairing remains unqualified."
    result["scope"] = "Automatic source-local SysEx A/B transport, eight cues, explicit Reloop/jumps, mixer/filter, tempo/level strips and global controls. Samplers, recording, output/lifecycle and physical acceptance remain open."
    for channel,deck in enumerate("ab"):
        for action,number in [("play",94),("cuePreview",93),("jumpBack",91),("jumpForward",92),("reloop",76)]:
            add(result,action,channel,number,deck=deck)
        for slot in range(8):
            add(result,f"hotcue{slot+1}",channel,slot,deck=deck)
        for action,number in [("gain",30),("high",31),("mid",32),("low",33),("filterKnob",34),("level",1)]:
            add(result,action,channel,number,"control",deck=deck)
        add(result,"tempo",channel,0,"pitch",deck=deck)
        result["inputs"][-1]["inverted"] = True
    for action,number in [("crossfader",35),("monitor",36),("master",37)]:
        add(result,action,0,number,"control")
    result["gaps"] = ["Logical bindings follow the SMK-25 II vendor decoder. Channel9 sampler input, recording, Bluetooth pairing/duplicate routes, hardware pad colours, output/reset and full lifecycle remain unimplemented. Firmware-immediate pad releases cannot establish physical hold duration. MIDI pitch/knob calibration and physical USB/A10X acceptance remain open. Original SMK-25 requires independent qualification."]
    return [result]

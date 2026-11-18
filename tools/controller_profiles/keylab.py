"""Original 88-key KeyLab input facts from independent pinned XML and scripts."""
from curated import add, profile
from numark import UPSTREAM

KEYLAB_NAME = "Arturia KeyLab 88 Mk 1"
KEYLAB_SOURCES = [
    ("ArturiaKeyLab.midi.xml", "dfa94f00c4ac092534502445c7879c03f1a73dd66331788ce4b01a951cb33f79"),
    ("Arturia-KeyLab-Mk1-scripts.js", "b67ec8f8ccc9481125d6087d58378acbc4bd6cd812f67f38daa9ce6c469f2ae2"),
    ("midi-components-0.0.js", "f15845d0b3fa10609aedc2fb74a9067d0f1d89387f011de72c3301799003f026"),
]
KEYLAB_REFERENCES = {KEYLAB_NAME: {
    "url": UPSTREAM + KEYLAB_SOURCES[0][0], "sha256": KEYLAB_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + filename, "sha256": digest} for filename, digest in KEYLAB_SOURCES[1:]] +
                       [{"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/arturia_keylab_mk1"}],
    "review": "Upstream manual qualifies only the original KeyLab88. Explicit XML input dispatch uses wire channel0 for fixed faders/knobs; component MIDI fields differ and are not copied as output facts. Fixed C/A/B/D volumes73/75/79/72, rates80/81/82/83, crossfader85, master7 and headphone gain0 retain source assignments. Native centred pitch preserves the source rate polarity. Selected-deck trim74/high71/mid76/low77/filter93 follow software deck selection. Sound/Multi CC118/119 select A/B on first press and C/D on release after the pinned component's275 ms power-window interval; repeats cannot retime the hold. Released snapshot CC22/23/24 chooses intro/outro+12-cue,16-cue or sampler layout. Native eight-cue capacity retains the first8 in each cue layout and blocks sampler pads. Raw pads are channel9 notes36..51 with top-to-bottom rows48/44/40/36. MMC requires F0/7F/7F/06/command/F7; only Stop1, Play2, forward4, backward5 and reloop55 become bounded native pulses. MMC supplies no physical release duration. Ordinary mod-wheel CC1 and alternate CC transport assignments remain inactive, preventing keyboard modulation from becoming transport. Logical MMC/pads use selected channels0..3; fixed controls use logical channel4. No logical message can be injected by raw keyboard traffic. Input startup needs no hardware handshake in the reviewed script. No persistent preset, display/LED packet or smaller/Essential/later KeyLab protocol is inferred. Full menus, cues9..16, recording, samplers, delayed display/lights/lifecycle, calibration and physical/A10X acceptance remain open.",
}}


def keylab_profiles():
    result = profile(KEYLAB_NAME, KEYLAB_REFERENCES[KEYLAB_NAME]["url"])
    result.update(catalogueName="Arturia KeyLab Mk 1", definition="reviewed:keylab-mk1-88", role="accessory",
                  inputProtocol="keyLabMKI",
                  hardwareMode="Original KeyLab88 factory first control bank. Initial selected deck A. Sound/Multi selects A/B; release after275 ms selects C/D, with app opt-in. Smaller and later variants remain unqualified.",
                  scope="Automatic original88-key normal input core: bounded MMC, source deck/cue-layout selection, fixed C/A/B/D faders/pitch, selected gain/EQ/filter and eight cues. Full menu/sampler/recording/display/output and physical acceptance remain open.")
    result["aliases"] += ["KeyLab 88", "Arturia KeyLab 88"]
    variants = ["KeyLab 25", "KeyLab 49", "KeyLab 61", "KeyLab Essential", "KeyLab 88 mkII", "KeyLab mkII", "KeyLab 88 Mk3", "KeyLab Mk3"]
    result["excludedAliases"] = variants + ["Arturia " + name for name in variants]
    for channel, deck in enumerate("abcd"):
        for action, number in [("cuePreview", 1), ("play", 2), ("jumpForward", 4), ("jumpBack", 5), ("reloop", 55)]:
            add(result, action, channel, number, deck=deck)
        for action, number in [("gain", 74), ("high", 71), ("mid", 76), ("low", 77), ("filterKnob", 93)]:
            add(result, action, channel, number, "control", deck=deck)
        for slot in range(8):
            add(result, f"hotcue{slot+1}", channel, 64+slot, deck=deck)
    for deck, level, tempo in [("c", 73, 80), ("a", 75, 81), ("b", 79, 82), ("d", 72, 83)]:
        add(result, "level", 4, level, "control", deck=deck)
        add(result, "tempo", 4, tempo, "control", "centreDetent", deck)
        result["inputs"][-1]["inverted"] = True
    for action, number in [("crossfader", 85), ("master", 7), ("monitor", 0)]:
        add(result, action, 4, number, "control")
    result["gaps"] = ["Original88-key model only;25/49/61-key, Essential and MkII/Mk3 variants need independent qualification. MMC supplies pulses, not physical hold duration. Ordinary CC transport/mod-wheel, intro/outro, cues9..16, sampler/recording, menu/library/skin/FX actions, delayed display/LED output, whole lifecycle/calibration and physical/A10X acceptance remain open. No persistent preset or audio interface is inferred."]
    return [result]

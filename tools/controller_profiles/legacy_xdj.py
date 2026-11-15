"""Original XDJ-RX facts, kept separate from its later relative-jog models."""
from curated import BASE, add, profile

LEGACY_XDJ_REFERENCES = {
    "Pioneer XDJ-RX": {
        "url": BASE + "all-in-one-dj-systems/XDJ-RX/XDJ-RX_List_of_MIDI_Message_E.pdf",
        "sha256": "c997e8a1e293c0d7eb6c03d6332bf8aa61f88c0fdba0fd11f7b3a5d2afccdf1c", "pages": [1, 2, 3, 4, 5, 6]},
}


def legacy_xdj_profiles():
    result = profile("Pioneer XDJ-RX", LEGACY_XDJ_REFERENCES["Pioneer XDJ-RX"]["url"])
    result.update(autoSelect=False, hardwareMode="PC / MIDI control",
                  scope="Partial original RX controls. The factory table has no Load message or MIDI output.",
                  gaps=["Load buttons have no published MIDI message. Complete a documented loading route before automatic selection.",
                        "The factory table specifies no MIDI output. Screens and feedback need another documented protocol."])
    for channel, deck in enumerate("abcd"):
        for action, number in [("play", 0), ("cueReturn", 1), ("sync", 31), ("keylock", 17),
                               ("jogTouch", 32), ("jogTouch", 72), ("loopIn", 6), ("loopOut", 7), ("reloop", 8)]:
            add(result, action, channel, number, deck=deck)
        add(result, "tempo", channel, 29, "control", "cdjTempo", deck)
        add(result, "jog", channel, 16, "control", "cdjPlatterSpeed", deck)
        add(result, "wheelJog", channel, 48, "control", "cdjPlatterSpeed", deck)
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", channel, 24 + slot, deck=deck)
        for action, numbers in {"level": [17, 18, 19, 20], "gain": [1, 6, 12, 80],
                                "high": [2, 7, 14, 81], "mid": [3, 8, 15, 92],
                                "low": [4, 9, 21, 82], "filterKnob": [5, 10, 22, 83]}.items():
            add(result, action, 4, numbers[channel], "control", deck=deck)
        add(result, "cue", 4, 70 + channel, "control", deck=deck)
    for action, number in [("crossfader", 11), ("master", 24), ("monitor", 26), ("cueMix", 27)]:
        add(result, action, 4, number, "control")
    add(result, "browse", 0, 79, "control", "twosComplement")
    for number in [50, 51]:
        add(result, "openGroup", 0, number)
    return [result]

"""Mixstream Pro core MIDI facts from the pinned controller mapping."""
from curated import add, profile
from numark import UPSTREAM

MIXSTREAM_SOURCES = [
    ("Numark-Mixstream-Pro.midi.xml", "34140ee6b96defaa382cd6e8523da0ebd9279d2c802d879c1c3c96974dce3054"),
    ("Numark-Mixstream-Pro.scripts.js", "02da45d00c1b18f1ebbb0e30350add0f771dec74cafd51faa2251a0995255a72"),
    ("midi-components-0.0.js", "f15845d0b3fa10609aedc2fb74a9067d0f1d89387f011de72c3301799003f026"),
]
MIXSTREAM_GUIDE = "https://cdn.inmusicbrands.com/Software/ENDJ5/Mixstream%20Pro%2C%20Mixstream%20Pro%2B%2C%20Mixstream%20Pro%20Go%20-%20User%20Guide%20-%20v5.0.0.pdf"
MIXSTREAM_REFERENCES = {"Numark Mixstream Pro": {
    "url": UPSTREAM + MIXSTREAM_SOURCES[1][0], "sha256": MIXSTREAM_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + path, "sha256": digest} for path, digest in MIXSTREAM_SOURCES] +
        [{"url": MIXSTREAM_GUIDE, "sha256": "2f0b1c9c20a53bb0444d2c3cd0f87de636274fcf358cbce73d3930ac0cdded61", "pages": [28]}],
    "review": "Computer Mode is required. The original Pro alone has reviewed MIDI addresses; the family user guide does not prove byte compatibility for Pro+ or Go. Mixer channels 0/1 differ from transport channels 2/3. Jog CC 55/77 is an absolute counter: the source adjusts its low byte at high-byte boundaries, ignores jumps over 45, then uses interval/dt*10 with milliseconds. This implies 10 ms per count, represented as 180 counts per 1.8-second revolution in the native movement contract; physical calibration remains open. Tempo is CC 31/75 with normal source rate scaling and native inversion. The LED animation is not a required handshake. Pads, scratch modes, backspin, full feedback, screens, auxiliary inputs and audio routing remain open.",
}}


def mixstream_profiles():
    result = profile("Numark Mixstream Pro", MIXSTREAM_REFERENCES["Numark Mixstream Pro"]["url"])
    result["definition"] = "reviewed:numark-mixstream-pro"
    result["excludedAliases"] = ["Mixstream Pro+", "Numark Mixstream Pro+", "Mixstream Pro Go", "Numark Mixstream Pro Go"]
    result["hardwareMode"] = "Select Computer Mode on the controller."
    result["scope"] = "Automatic native core MIDI after Computer Mode selection. Counter jogs retain the published movement scale. Pads, scratch modes, shifted alternatives, full feedback, screen, auxiliary inputs and audio routing remain open. Pro+ and Go do not inherit this recipe."
    for side, deck in enumerate("ab"):
        transport = side + 2
        for action, number in [("play", 10), ("cuePreview", 9), ("sync", 8), ("jogTouch", 33)]:
            add(result, action, transport, number, deck=deck, feedback=action in {"play", "sync"})
            if action in {"play", "cuePreview"}:
                result["inputs"][-1].update(shifted=False, shiftChannel=side)
        add(result, "cue", side, 13, deck=deck, feedback=True)
        add(result, "jog", transport, 55, "control", "mixstreamJog", deck)
        result["inputs"][-1].update(lowNumber=77, argument=180)
        add(result, "tempo", transport, 31, "control", "paired14Bit", deck)
        result["inputs"][-1].update(lowNumber=75, inverted=True)
        for action, number in [("gain", 3), ("high", 4), ("mid", 6), ("low", 8), ("filterKnob", 11), ("level", 14)]:
            add(result, action, side, number, "control", deck=deck)
        add(result, "load", 15, 1 + side, deck=deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=side)
        add(result, "shift", transport, 28)
        result["inputs"][-1]["shiftChannel"] = side
    for action, number in [("crossfader", 14), ("master", 15), ("cueMix", 9), ("monitor", 10)]:
        add(result, action, 15, number, "control")
    add(result, "browse", 15, 5, "control", "twosComplement")
    add(result, "openGroup", 15, 6)
    for output in result["outputs"]:
        output["offValue"] = 1
    result["shutdown"] = [[0x90 + output["channel"], output["number"], 0] for output in result["outputs"]]
    return [result]

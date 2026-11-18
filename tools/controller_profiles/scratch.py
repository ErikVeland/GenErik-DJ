"""Numark Scratch native mixer and accessory facts from the pinned mapping."""
from curated import add, profile
from numark import UPSTREAM

SCRATCH_SOURCES = [
    ("Numark-Scratch.midi.xml", "faeb3d79ff98c46ce6ae2a3a5f00f2af74692bcd141d38d5d427b6459f4efd35"),
    ("Numark-Scratch-scripts.js", "e00bf9d265bee9131cad79ce4ab52fb8b736cbced8f2783cbae2921f4034d3a1"),
    ("midi-components-0.0.js", "f15845d0b3fa10609aedc2fb74a9067d0f1d89387f011de72c3301799003f026"),
]
SCRATCH_REFERENCES = {"Numark Scratch": {
    "url": UPSTREAM + SCRATCH_SOURCES[0][0], "sha256": SCRATCH_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name, "sha256": digest} for name, digest in SCRATCH_SOURCES] + [
        {"url": "https://www.numark.com/images/product_downloads/Scratch_-_User_Guide_-_v1.2.pdf",
         "sha256": "5b491b405ad730643d40927275415cbb57f6e5c6475555c13bfc2589cbb40f81", "pages": [5, 6]},
        {"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/numark_scratch", "reviewed": "2026-11-17",
         "audioOutput": "Master channels 1/2 and headphone channels 3/4. MASTER/BOOTH/CUE GAIN use hardware controls. Cue Mix reports MIDI to the software mixer."}],
    "review": "XML dispatch establishes mixer channels 0/1 and pad/loop channels 4/5. The shared push handler applies received PFL on/off state directly. Native cue-state actions preserve it. Constructor PFL output channels differ, so headphone lights remain unmapped. The factory guide confirms that the Loop knob toggles on/off. That factory behaviour replaces the community script's enable-only key. Loop direction notes 52/53 have Note On dispatch only and represent encoder pulses. Every positive pulse applies once, without a release edge. Physical Shift on channel 15 note 50 selects one-step browsing and Load; unshifted controls resize or toggle the native loop. The shared four-pad addresses require explicit Cue/Sampler/Roll mode state. Alternate delete releases only rearm cues. Pad lights remain unmapped pending output mode guards. Selector reports 0/2 reset only that side's pickup. The published status/unlock and shutdown packets remain bounded. The source comment ties its ten-second delay to Mixxx initialisation. Native startup connects input before sending the request. Physical cold-start timing remains unverified. The cited audio setup gives master channels 1/2 and headphone channels 3/4. DVS, passthrough and physical output acceptance remain open.",
}}


def scratch_profiles():
    result = profile("Numark Scratch", SCRATCH_REFERENCES["Numark Scratch"]["url"])
    result["role"] = "accessory"
    result["audioOutput"] = "masterAndHeadphones"
    result["scope"] = "Automatic native mixer/accessory controls, four guarded cue pads per deck and pulse-based loop/browse controls. Documented USB master/headphone outputs select automatically. FX, rolls, sampler, full lights, cleanup, DVS and passthrough remain open."
    result["startup"] = [[0x9F, 50, 1], [0xF0, 0, 32, 127, 0, 0xF7]]
    result["shutdown"] = [[0xF0, 0, 32, 127, 4, 0xF7]]
    result["inputModes"] = [{"channel": channel, "initial": 0, "numbers": [0, 7, 11], "onValue": 127, "offValue": 1}
                             for channel in [4, 5]]
    result["bankChanges"] = [{"channel": 15, "number": number, "onValue": 2, "decks": [deck], "releaseShiftChannels": []}
                              for number, deck in [(87, "a"), (96, "b")]]
    add(result, "shift", 15, 50)
    for channel, deck in enumerate("ab"):
        pad_channel = channel + 4
        for action, number in [("gain", 22), ("high", 23), ("mid", 24), ("low", 25), ("filterKnob", 26), ("level", 28)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "cueState", channel, 27, deck=deck)
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", pad_channel, 20 + slot, deck=deck)
            result["inputs"][-1].update(requiredMode=0, shifted=False)
            add(result, f"hotcue{slot + 1}", pad_channel, 28 + slot, deck=deck)
            result["inputs"][-1].update(requiredMode=0, shifted=True, releaseOnly=True)
        for action, number, browser in [("loopDown", 52, "browsePrevious"), ("loopUp", 53, "browseNext")]:
            add(result, action, pad_channel, number, deck=deck)
            result["inputs"][-1].update(shifted=False, pulse=True)
            add(result, browser, pad_channel, number)
            result["inputs"][-1].update(shifted=True, pulse=True)
        add(result, "loop", pad_channel, 63, deck=deck)
        result["inputs"][-1]["shifted"] = False
        add(result, "load", pad_channel, 63, deck=deck)
        result["inputs"][-1]["shifted"] = True
    add(result, "crossfader", 15, 8, "control")
    add(result, "cueMix", 15, 13, "control")
    return [result]

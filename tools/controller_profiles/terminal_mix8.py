"""Terminal Mix 8 native core from the manufacturer's MIDI table and Traktor file."""
from copy import deepcopy
from curated import add, profile

TM8_BASE = "https://www.reloop.com/media/custom/upload/"
TM8_SOURCES = [
    ("Reloop-TM8_MIDI-Map.pdf", "a4b829f627a8f861fbbc9849b13d7adcd4af8218f83d0fdd378e2b6b2a236c77"),
    ("Reloop-TM8_HowtoTraktor_web.pdf", "5e180c7c8fc5fa8476a69a028ca97e3986b483a65fdb99de2ceff58e6a809c50"),
    ("228148/228148%20Mapping%201%204D%20TraktorPro%202.6%2B%20FW%200.19%2B%20Uni.zip", "e134f74b65b1adf4498796900107f1db9d05ab1a163fdb27397c87a46e6fb8cc"),
]
TM8_REFERENCES = {"Reloop Terminal Mix 8": {
    "url": TM8_BASE + TM8_SOURCES[0][0], "sha256": TM8_SOURCES[0][1], "pages": [1, 2, 3],
    "relatedSources": [{"url": TM8_BASE + name, "sha256": digest} for name, digest in TM8_SOURCES[1:]],
    "review": "Factory table assigns four deck channels0..3 and pad channels4..7. Published firmware0.19+ Traktor mapping confirms dedicated Load on each deck channel, wheel-on contact/jog7, wheel-off nudge6, full pitch and signed centre64 encoders. Native default wheel calibration is retained; the related Terminal Mix2/4 800-count scale is not inferred. Shift sources31 share physical side identity across A/C and B/D; normal mixer/pad inputs are side guarded and pickup resets on layer changes. Factory +64 addresses release old contacts/buttons and rearm cues, while positive clear/seek/other shifted actions stay inactive. Key Lock follows the factory Traktor shifted89 assignment. Four Loop-page pads12..15 follow the published Traktor In/Out/Halve/Double layout; other stored-loop/roll/move pages remain inactive. Native fixed touch scratch replaces source browse-wheel and Vinyl/mode scripts; Hold stream8 and all shifted jog motion remain inactive, with release aliases for contact exits. Bank note32 clears owned contacts/pickup only on its physical side and preserves physical Shift. Factory RGB palette gives white19/off0; mono states retain source127/off0. Published pickup SysEx plus52 native lights, four meter clears and four listed FX clears fit61 lifecycle messages. Factory table explicitly aliases fader-start Cue/Play to normal4/5, so those packets cannot be distinguished; fader-start use is not qualified. Mac guide assigns monitor FRONT/master BACK, unlike Windows numbered routing, so no automatic iPad channel layout is inferred. Four-deck opt-in, full pad/FX/feedback/reset, audio, physical gain/pitch/jog calibration and acceptance remain open.",
}}


def terminal_mix8_profiles():
    result = profile("Reloop Terminal Mix 8", TM8_REFERENCES["Reloop Terminal Mix 8"]["url"])
    result["hardwareMode"] = "Firmware0.19+; native normal-wheel and eight-cue page. Fader-start use is unqualified. Four decks retain app opt-in."
    result["scope"] = "Automatic four-target core with native held Cue, side Shift/bank cleanup, touch jog/rim, full pitch, mixer/filter, direct Load, eight cues, four manual-loop pads and source-coloured lights. Full modes, fader start, audio and calibration remain open."
    result["gaps"] = ["Fader-start Cue/Play shares the transport wire addresses and cannot be distinguished. Full stored-loop/roll/slicer/sampler/dual modes, FX, VU, feedback/reset, hold/shift jog streams, gain/pitch/jog calibration and physical acceptance remain open. Mac FRONT monitor/BACK master numbering needs qualification before automatic audio routing."]
    result["bankChanges"] = [{"channel": channel, "number": 32, "onValue": 127,
                               "decks": ["a", "c"] if channel % 2 == 0 else ["b", "d"]} for channel in range(4)]
    for channel, deck in enumerate("abcd"):
        side = channel % 2
        add(result, "shift", channel, 31)
        result["inputs"][-1].update(shiftChannel=side, shiftInput=side)

        def control(action, number, kind="note", encoding="absolute", pad=False, shifted=False, feedback=False, **extra):
            add(result, action, channel + 4 if pad else channel, number, kind, encoding, deck, feedback)
            result["inputs"][-1].update(shiftChannel=side, shifted=shifted, **extra)

        def button(action, number, pad=False, feedback=False):
            control(action, number, pad=pad, feedback=feedback)
            release = deepcopy(result["inputs"][-1])
            release.update(number=number + 64, shifted=True, releaseOnly=True)
            result["inputs"].append(release)

        for action, number in [("play", 5), ("cuePreview", 4), ("sync", 2), ("cue", 14), ("load", 16)]:
            button(action, number, feedback=action != "load")
        control("keylock", 89, shifted=True, feedback=True)
        button("jogTouch", 7)
        for number in [6, 8, 70, 72]:
            control("jogTouch", number, shifted=number >= 64, releaseOnly=True)
        control("jog", 7, "control", "binaryOffset")
        control("wheelJog", 6, "control", "binaryOffset")
        add(result, "tempo", channel, 0, "pitch", deck=deck)
        for action, number in [("gain", 9), ("high", 10), ("mid", 11), ("low", 12), ("filterKnob", 13), ("level", 15)]:
            control(action, number, "control")
        for slot in range(8):
            button(f"hotcue{slot + 1}", slot, pad=True, feedback=True)
            result["outputs"][-1]["onValue"] = 19
        for action, number in [("loopIn", 12), ("loopOut", 13), ("loopDown", 14), ("loopUp", 15)]:
            button(action, number, pad=True)
    add(result, "crossfader", 0, 43, "control")
    add(result, "cueMix", 0, 41, "control")
    add(result, "browse", 0, 40, "control", "binaryOffset")
    add(result, "openGroup", 0, 40)
    result["startup"] = [[0xF0, 0x7E, 0x7F, 0x56, 0x44, 0x4A, 0x20, 0x69, 0x6E, 0x69, 0x74, 0xF7]]
    result["shutdown"] = [[0x90 + row["channel"], row["number"], 0] for row in result["outputs"]]
    result["shutdown"] += [[0xB0 + channel, 1, 0] for channel in range(4)]
    result["shutdown"] += [[0x90 + channel, number, 0] for channel in range(2) for number in [27, 28]]
    return [result]

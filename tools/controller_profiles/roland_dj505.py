"""Independent DJ-505 normal controls without a partial software-mode lifecycle."""
from curated import add, profile

DJ505_REVISION = "20f2c218ae1b762ac39fd76ff408c8428056f4f7"
DJ505_BASE = "https://raw.githubusercontent.com/mixxxdj/mixxx/"+DJ505_REVISION+"/res/controllers/"
DJ505_SOURCES = [
    ("Roland_DJ-505.midi.xml", "7484f8d2e0c524f779d6c842892e219679deccc501d8cd183eea5a4b3132e688"),
    ("Roland_DJ-505-scripts.js", "6e996b5a17d1fa97bfd20be69e4b76ad1996967bb91cbcb36e3855819bb02522"),
]
DJ505_REFERENCES = {"Roland DJ-505": {
    "url": DJ505_BASE+DJ505_SOURCES[0][0], "sha256": DJ505_SOURCES[0][1],
    "relatedSources": [{"url": DJ505_BASE+DJ505_SOURCES[1][0], "sha256": DJ505_SOURCES[1][1]},
                       {"url": "https://raw.githubusercontent.com/mixxxdj/mixxx/"+DJ505_REVISION+"/src/engine/controls/ratecontrol.cpp",
                        "sha256": "e15d822d3f2a9ff5307257a20b20db063b3ca75798e1cca1be5ae36886bbc0c0"}],
    "review": "Pinned upstream XML and script independently define deck channels0..3. Normal Play0, held Cue1, Sync2 and Keylock13 have shifted addresses4/5/3/14. Global Shift is channel15 Note0. Native positive shifted transport remains inactive; shifted and opposite-bank release aliases preserve owned releases and debounce. Six explicit14-bit pairs per deck are tempo9/59, gain22/52, high23/53, mid24/54, low25/55 and level28/58. These low bytes are not guessed from a plus32 rule. Source sets rate_dir=-1; the pinned rate-control formula is rate_ratio=1+rate_dir*range*rate. Native tempo therefore reverses the source raw parameter. Physical range calibration remains unverified. Tempo changes to key pitch under source Shift, so native normal tempo is guarded. FilterCC26 and PFLNote27 remain separate. Loop channels4..7 have Reloop/Exit51, Half52, Double53, In56 and Out57. Native loop semantics replace the source software handlers. The source switches to Serato mode with two SysEx messages and repeats BF6400 every500ms. No partial setup or keepalive is emitted. Shared Load handler ownership depends on deck-button software state. The crossfader has a source-specific maximum16368 instead of16383. Load, crossfader, jog/contact, pads, FX, TR-S and other mode/lifecycle functions remain inactive. No downloaded code runs in the app. This manual subset does not qualify automatic selection, DJ-202/DJ-808 byte compatibility, routing or physical acceptance.",
}}


def dj505_profiles():
    result = profile("Roland DJ-505", DJ505_BASE+DJ505_SOURCES[0][0])
    result["definition"] = "reviewed:roland-dj505"
    result["autoSelect"] = False
    result["excludedAliases"] = ["Roland DJ-202", "DJ-202", "Roland DJ-808", "DJ-808"]
    result["hardwareMode"] = "Manual normal MIDI subset. Enable input separately. Software-mode startup/keepalive and full bank ownership remain open. C/D require app opt-in."
    result["scope"] = "Manual four-target transport, paired tempo/gain/EQ/level, filter/PFL and explicit loop buttons. No shared Load, crossfader, jog, pad, TR-S, lifecycle or audio route is inferred."
    add(result, "shift", 15, 0)
    buttons = [("play",0,4), ("cuePreview",1,5), ("sync",2,3), ("keylock",13,14)]
    for channel, deck in enumerate("abcd"):
        for action, number, shifted in buttons:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1]["shifted"] = False
            add(result, action, channel, shifted, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
            for release in [number, shifted]:
                add(result, action, (channel+2)%4, release, deck=deck)
                result["inputs"][-1]["releaseOnly"] = True
        for action, number, low in [("tempo",9,59), ("gain",22,52), ("high",23,53),
                                    ("mid",24,54), ("low",25,55), ("level",28,58)]:
            add(result, action, channel, number, "control", "paired14Bit", deck)
            result["inputs"][-1]["lowNumber"] = low
            if action == "tempo":
                result["inputs"][-1].update(inverted=True, shifted=False)
        add(result, "filterKnob", channel, 26, "control", deck=deck)
        add(result, "cue", channel, 27, deck=deck)
        for action, number in [("reloop",51), ("loopDown",52), ("loopUp",53), ("loopIn",56), ("loopOut",57)]:
            add(result, action, channel+4, number, deck=deck)
    result["gaps"] = ["Manual normal subset only. Shared Load/bank ownership, crossfader maximum calibration, jog/contact, pads/FX/TR-S and full Shift modes remain inactive. Software-mode SysEx, periodic keepalive, complete output/shutdown and audio routing remain unimplemented. Native pitch polarity/range and physical/A10X acceptance remain open. DJ-202/DJ-808 require independent qualification."]
    return [result]

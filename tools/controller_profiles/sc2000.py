"""SC2000 factory channels with native touch, bank cleanup and trigger LEDs."""
from curated import add, profile
from numark import UPSTREAM

SC2000_GUIDE = "https://cdn.inmusicbrands.com/denondj/legacy/dnsc2000/DN-SC2000_ownersmanual.pdf"
SC2000_SOURCES = [
    ("Denon DN SC2000.midi.xml", "7d531793ad47bbe219aa761a8f39e2ee22dd853c977f94b69426e19ffe86da8e"),
    ("Denon-DN-SC2000.midi.js", "72f5e8a46afa7a2ad69f7fe1c926de8322d5d9d71e8bf5125dc71d2e201c9999"),
]
SC2000_REFERENCES = {"Denon DN SC2000": {
    "url": SC2000_GUIDE, "sha256": "a0f5659f1cafe48cda952740b478d69663a6015f416bfd072cb7ae4607ef90e9", "pages": [1, 2],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in SC2000_SOURCES],
    "review": "Factory MIDI table establishes Note On64/Note Off0 buttons, centre64 relative 2048-count jog, full pitch-bend messages and separate CC74-on/75-off LED triggers carrying LED IDs. Reviewed default CH1/2 targets A/B; CH3/4 targets C/D under existing app availability. Other channel pairs need explicit assignment and do not gain inferred targets. Physical Shift uses one source-local input across all eight wire channels, preserving release through deck/channel changes. Note3 bank reports release contacts and rearm all deck pickup without dropping held Shift. Shift blocks unsupported new presses/movement while old Cue/contact/bend releases remain valid. Native layout keeps eight cues, manual loop In/Out, Auto Loop, beat-size buttons, filter encoder and direct Load. The filter encoder follows its factory label rather than the source's loop-size customisation. Native feedback covers Play, held Cue, Sync, Key Lock, loop and eight cues per deck. Initial native feedback owns its lights; shutdown clears only these52LED states within the existing budget. Hardware dimmer LEDs, FX, full resets, Shift alternatives, source held cue/loop customisations, calibration and physical acceptance stay open. No audio interface, generic USB Audio Device alias, source num_decks mutation or JS timers are invented.",
}}


def sc2000_profiles():
    result = profile("Denon DN SC2000", SC2000_GUIDE)
    result["aliases"] += ["Denon DN-SC2000", "DN-SC2000", "Denon DJ DN-SC2000"]
    result.update(role="accessory", hardwareMode="CH1/2 control A/B. CH3/4 control C/D with app opt-in. CH5–8 require separate assignment.", scope="Automatic SC2000 CH1–4 native core with2048-count fixed touch scratch, paired-deck bank cleanup, physical Shift continuity, eight cues, loops, pitch and trigger LEDs. Other channel pairs, dimmers, FX, full cleanup, calibration and physical acceptance remain open.")
    result["bankChanges"] = [{"channel": ch, "number": 3, "onValue": 64, "decks": list("abcd"), "releaseShiftChannels": []} for ch in range(8)]
    for channel in range(8):
        add(result, "shift", channel, 96)
        result["inputs"][-1]["shiftInput"] = 0
    for channel, deck in enumerate("abcd"):
        start = len(result["inputs"])
        for action, number in [("play", 67), ("cuePreview", 66), ("sync", 107), ("keylock", 6), ("load", 40),
                               ("pitchBendDown", 13), ("pitchBendUp", 12)]:
            add(result, action, channel, number, deck=deck)
        add(result, "jogTouch", channel, 81, encoding="touchGate", deck=deck)
        add(result, "jog", channel, 81, "control", "denonJog", deck)
        result["inputs"][-1]["argument"] = 2048
        add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1]["inverted"] = True
        cue_notes = [23, 24, 25, 32, 33, 34, 35, 36]
        cue_leds = [17, 19, 21, 23, 25, 27, 29, 32]
        for slot, number in enumerate(cue_notes):
            add(result, f"hotcue{slot + 1}", channel, number, deck=deck)
        for action, number in [("loopIn", 55), ("loopOut", 57), ("loop", 29), ("loopDown", 105), ("loopUp", 106)]:
            add(result, action, channel, number, deck=deck)
        add(result, "filterKnob", channel, 93, "control", "zeroForward", deck)
        add(result, "browse", channel, 84, "control", "zeroForward")
        for action, number in [("openGroup", 100), ("browsePreviousGroup", 48), ("browseNextGroup", 41)]:
            add(result, action, channel, number)
        for item in result["inputs"][start:]:
            item["shifted"] = False
        feedback = [("play", 39), ("cuePreview", 38), ("sync", 9), ("keylock", 8), ("loop", 43)]
        feedback += [(f"hotcue{slot + 1}", number) for slot, number in enumerate(cue_leds)]
        for action, identifier in feedback:
            result["outputs"].append({"action": action + ("A" if deck in "ac" else "B"), "targetDeck": deck,
                                      "kind": "control", "channel": channel, "number": 74, "offNumber": 75,
                                      "onValue": identifier, "offValue": identifier, "offUsesNoteOn": True})
            result["shutdown"].append([0xB0 + channel, 75, identifier])
    return [result]

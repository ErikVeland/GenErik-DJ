"""Independent RANE FOUR transport facts from the public PCDJ controller script."""
from curated import add, profile

FOUR_SOURCE = "https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg"
FOUR_PACKAGE_SHA = "55aaca2c33e7f1b84b420ab20f2c261f1c98ee73b62b3c012e25616f39070030"
FOUR_SCRIPT_SHA = "197dc774bd2cef75f2e12aa3683d79d108a60090e9c5e3c5f199cb9c6984aa85"
FOUR_REFERENCES = {"Rane FOUR": {
    "url": FOUR_SOURCE, "sha256": FOUR_PACKAGE_SHA,
    "archiveMember": "Applications/DEX4.app/Contents/Resources/controllers/Rane_Four.js",
    "memberSha256": FOUR_SCRIPT_SHA,
    "relatedSources": [{"url": "https://pcdj.com/dj-software/free-trials/dex-4-free-trial/"}],
    "review": "Public DEX4.0 Mac package dated27March2025. Its Rane_Four.js revision1April2024 targets firmware1.6.0.2 and USB1CC5:0024. Main and separate LCD Left/Right MIDI devices share this identity. Independently normalised transport facts only; downloaded code never executes in the app. Channels0..3 target A/B/C/D. Normal Play0/Cue1/Sync2, Load6, bend11/12, keylock13, CC9/41 inverted14-bit pitch, CC0 rotary64 browse and loop-channel4..7 notes52/53/54/55/63/65 are reviewed. Alternate shifted transport addresses and opposite-bank releases cannot create positive presses. Only transport light values127/on and1/dim-off are included. Hardware mixing requires separate seven-stereo-output routing and software mixer bypass, which native routing does not provide. Platter CC6 is a wrapping absolute counter; PitchBend messages are timestamps at2822400Hz, not pitch. Shared pads, LCD text/graphics, full bank state and loop edit variations remain open. Source software-mode setup contains an unterminated SysEx and needs a periodic keepalive; no partial setup, guessed terminator or lifecycle packet is emitted. Manual input and feedback require separate enabling. No automatic audio route or automatic selection is claimed.",
}}


def rane_four_profiles():
    result = profile("Rane FOUR", FOUR_SOURCE)
    result["aliases"].append("RANE FOUR Control")
    result["excludedAliases"] = ["RANE FOUR LCD Left", "RANE FOUR LCD Right", "LCD Left", "LCD Right"]
    result["autoSelect"] = False
    result["hardwareMode"] = "Manual main-port transport only. Enable input separately; software-mode setup, keepalive and external deck routing remain open."
    result["scope"] = "Manual transport, held Cue and bend, paired pitch, browsing and loop boundaries for four opt-in deck targets. Reviewed transport lamps require separate feedback enabling."
    result["gaps"] = ["Hardware mixer bypass and separate deck/sampler/FX audio buses are unavailable. Automatic selection remains off.",
                      "Cold-start software-mode SysEx, periodic keepalive, shutdown, platter counter/timestamps, shared pads, display ports, complete bank state, loop edit variations and physical acceptance remain open. Cross-bank release aliases clear a held control when its release arrives; bank selection itself does not release it."]
    for channel, deck in enumerate("abcd"):
        normal = [("play", 0), ("cuePreview", 1), ("sync", 2), ("keylock", 13),
                  ("load", 6), ("pitchBendUp", 11), ("pitchBendDown", 12)]
        for action, number in normal:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "cuePreview", "sync", "keylock"})
        shifted = [("play", 4), ("cuePreview", 5), ("sync", 3)]
        for action, number in shifted:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        for action, number in normal + shifted:
            if action == "load":
                continue
            add(result, action, (channel + 2) % 4, number, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        add(result, "tempo", channel, 9, "control", "paired14Bit", deck)
        result["inputs"][-1].update(lowNumber=41, inverted=True)
        add(result, "browse", channel, 0, "control", "binaryOffset")
        for action, number in [("loopDown", 52), ("loopUp", 53), ("loopIn", 54), ("loopOut", 55), ("loop", 63), ("reloop", 65)]:
            add(result, action, channel + 4, number, deck=deck)
    for output in result["outputs"]:
        output["offValue"] = 1
    result["shutdown"] = [[0x90 + row["channel"], row["number"], 1] for row in result["outputs"]]
    return [result]

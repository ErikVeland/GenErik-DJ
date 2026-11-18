"""Original Instinct factory MIDI and audio layout with reviewed pressure jogs."""
from curated import add, profile
from numark import UPSTREAM

INSTINCT_GUIDE = "https://ts.hercules.com/download/sound/manuals/DJ_Instinct/QSG/DJCInstinct_Technical_specifications.pdf"
INSTINCT_SOURCES = [
    ("Hercules DJ Control Instinct.midi.xml", "f9ea6b7e8bbb33b19695b1f2c830c4dff256e76424820cd21f1f8dce117a398f"),
    ("Hercules-DJ-Control-Instinct-scripts.js", "18b48894cada26b755cbb5fe7057a4dfe0e1cdf9a93f20dc350580bb83acea2f"),
]
INSTINCT_REFERENCES = {"Hercules DJ Control Instinct": {
    "url": INSTINCT_GUIDE, "sha256": "5189c7611d57b0a0aeba13ee4377456740f82689a8ccd8b3a9e3c61af5678a81", "pages": [1, 2, 3, 4, 5, 6, 7],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in INSTINCT_SOURCES],
    "review": "Factory table establishes normal jog CC48/49, pitch-lever 1/127 steps, four physical cue inputs per deck, same-address active-low LEDs and master1/2/headphones3/4 audio. Pinned script/XML add pressure jog CC50/51 and 128-count scratch scale. Pressure movement requires the factory contact notes26/52 and stays separate from normal-wheel reports. Native signed decoding keeps 64 negative on both streams; the pressure-stream format is inferred from the factory normal-wheel contract and needs capture, rather than copying the script's inconsistent 64-forward boundary. Native held bend is the shared four-percent rate without source fast/slow or opposing-button saved-tempo reset. Native four-cue layout uses all factory Cue keys instead of copying the source's two-cue/delete choice. Factory LED addresses/polarity replace conflicting community rows. Full factory LED clear plus native shutdown fits 51 messages in a new 64-message lifecycle bound. EQ polarity retains the source convention pending physical calibration. HP volume buttons, cue-held previews, loop/pad feedback, FX/samples, source speed modes, remaining cleanup and physical qualification stay open. P8 and iPad-specific variants are not aliases.",
}}


def instinct_profiles():
    result = profile("Hercules DJ Control Instinct", INSTINCT_GUIDE)
    result.update(audioOutput="masterAndHeadphones", scope="Automatic original Instinct core with factory normal jogs, 128-count pressure scratch, stepped pitch, held bend, four cues, loops, active-low transport feedback and documented master/headphone channels. P8/iPad variants, full modes/feedback, calibration and physical acceptance remain open.")
    result["excludedAliases"] = ["DJControl Instinct P8", "Hercules DJControl Instinct P8", "DJControl Instinct iPad Edition", "Hercules DJ Control Instinct for iPad"]
    for side, deck in enumerate("ab"):
        base = 26 * side
        for action, number in [("play", 22), ("cuePreview", 21), ("sync", 23), ("cue", 24), ("load", 25),
                               ("pitchBendDown", 17), ("pitchBendUp", 18)]:
            add(result, action, 0, base + number, deck=deck, feedback=action in {"play", "sync", "cue"})
        add(result, "jogTouch", 0, 26 + base, encoding="fullVelocityGate", deck=deck)
        add(result, "jog", 0, 50 + side, "control", "twosComplement", deck)
        result["inputs"][-1].update(argument=128, requiresTouch=True)
        add(result, "wheelJog", 0, 48 + side, "control", "twosComplement", deck)
        result["inputs"][-1]["argument"] = 128
        add(result, "tempo", 0, 52 + side, "control", "signedStep", deck)
        for action, number in [("level", 54), ("high", 55), ("mid", 56), ("low", 57)]:
            add(result, action, 0, number + 5 * side, "control", deck=deck)
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", 0, base + 13 + slot, deck=deck)
        for action, number in [("loopIn", 9), ("loopOut", 10), ("reloop", 11), ("loopDown", 12)]:
            add(result, action, 0, base + number, deck=deck)
    add(result, "crossfader", 0, 58, "control")
    for action, number in [("browsePrevious", 54), ("browseNext", 55), ("browseNextGroup", 56), ("browsePreviousGroup", 57)]:
        add(result, action, 0, number)
    for output in result["outputs"]:
        output.update(onValue=0, offValue=127)
    led_notes = list(range(1, 17)) + list(range(21, 25)) + list(range(27, 43)) + list(range(47, 51)) + [53, 56, 57]
    result["startup"] = [[0x90, number, 127] for number in led_notes] + [[0x90, 53, 0]]
    result["shutdown"] = [[0x90, output["number"], 127] for output in result["outputs"]] + [[0x90, 53, 127]]
    return [result]

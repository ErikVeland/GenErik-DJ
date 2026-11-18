"""Original DJ2GO factory MIDI core, separate from DJ2GO2 variants."""
from curated import add, profile
from numark import UPSTREAM

DJ2GO_GUIDE = "https://www.numark.com/images/product_downloads/dj2go___software_definition_and_midi_spec_v1.0.pdf"
ORIGINAL_DJ2GO_SOURCES = [
    ("Numark DJ2Go.midi.xml", "33d00ae474510745778cbba79a0b9848409f40b38c9fd97393241eddf802e964"),
    ("Numark-DJ2Go-scripts.js", "1769f3eca226df4f80077d47e62d18586302215e0a2ae7552fe9b0da0ca2a63f"),
]
ORIGINAL_DJ2GO_REFERENCES = {"Numark DJ2Go": {
    "url": DJ2GO_GUIDE, "sha256": "3525dd8cb424ac82dd00b77c233d48801feb2a78423e7a71980400abe346a132", "pages": [2, 5, 6, 7],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in ORIGINAL_DJ2GO_SOURCES],
    "review": "Factory Rev B protocol supplies every button, pot/fader, LED and signed relative address. Native jog/browse keeps full two's-complement magnitude and stationary zero, replacing the old script's direction-only treatment. Source 60 physical counts supports native wheel nudge/paused seek; its 85RPM synthetic scratch timers are not copied. Direct Load acts on press and does not restart/toggle scratch on a playing deck. Physical pitch-bend buttons use native owned holds rather than the script's custom loop layer. Native held Cue feedback follows the current generation-owned preview contact, independently of headphone PFL. Play/Sync/PFL/Cue use all eight documented LED addresses. No extra setup or audio interface is invented. Back moves to the previous native library group; Enter uses existing Open Group. Full hierarchical browser semantics, source exclusive-PFL/alternate layers/flashes, calibration and physical acceptance remain open. DJ2GO2 and Touch are separate protocols.",
}}


def original_dj2go_profiles():
    result = profile("Numark DJ2Go", DJ2GO_GUIDE)
    result["scope"] = "Automatic original DJ2GO factory core with full signed wheel/browser movement, direct Load, held Cue/bend, pitch, all physical gain/level controls and eight native LED outputs. Browser hierarchy, extra source modes/flashes, calibration and physical acceptance remain open."
    result["excludedAliases"] = ["DJ2GO2", "Numark DJ2GO2", "DJ2GO2 Touch", "Numark DJ2GO2 Touch"]
    buttons = [[("play", 0x3B), ("cuePreview", 0x33), ("sync", 0x40), ("cue", 0x65), ("load", 0x4B), ("pitchBendUp", 0x43), ("pitchBendDown", 0x44)],
               [("play", 0x42), ("cuePreview", 0x3C), ("sync", 0x47), ("cue", 0x66), ("load", 0x34), ("pitchBendUp", 0x45), ("pitchBendDown", 0x46)]]
    for side, deck in enumerate("ab"):
        for action, number in buttons[side]:
            add(result, action, 0, number, deck=deck, feedback=action in {"play", "cuePreview", "sync", "cue"})
        add(result, "level", 0, 8 + side, "control", deck=deck)
        add(result, "tempo", 0, 13 + side, "control", "centreDetent", deck)
        result["inputs"][-1]["inverted"] = True
        add(result, "wheelJog", 0, 25 - side, "control", "twosComplement", deck)
        result["inputs"][-1]["argument"] = 60
    for action, number in [("crossfader", 10), ("master", 23), ("monitor", 11)]:
        add(result, action, 0, number, "control")
    add(result, "browse", 0, 26, "control", "twosComplement")
    add(result, "browsePreviousGroup", 0, 89)
    add(result, "openGroup", 0, 90)
    result["startup"] = [[0x90, r["number"], 0] for r in result["outputs"]]
    result["shutdown"] = list(result["startup"])
    return [result]

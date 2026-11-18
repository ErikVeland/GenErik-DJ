"""Independent VMS5 facts with explicit software deck banks and manual ownership."""
from curated import add, profile

TSI = "https://www.adj.eu/mwdownloads/download/link/id/786"
MANUAL = "https://www.adj.eu/mwdownloads/download/link/id/787"
VMS5_REFERENCES = {"American Audio VMS5": {
    "url": TSI, "sha256": "cc50266fdaa55be9e45294a80af59d374aa7670a90a63e25efa8815a9e3a0c9a",
    "member": "VMS5 Traktor mapping V1.0.tsi",
    "memberSHA256": "bf27354a27324bc1ab213d6d940b3f8b2c90c3cc402906b3426a7e89beececc5",
    "relatedSources": [{"url": MANUAL, "sha256": "62d4e41dacab2ed2ed81d08d4d78e52adda7ff8ff385b8e2eace557f37804295", "pages": [11, 12, 18]},
                       {"url": "https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg",
                        "sha256": "55aaca2c33e7f1b84b420ab20f2c261f1c98ee73b62b3c012e25616f39070030",
                        "member": "AmericanAudio__VMS50.js",
                        "memberSHA256": "cceee68749e8485b5d4c33011c89365ca984973437b38078573ba24760cb79c2"}],
    "review": "The manufacturer's public factory TSI contains302 used bindings. It independently confirms shared A/C and B/D transport, pitch bend, tempo and jog wires. Native software banks use Note14/48, one transition per press. Fixed mixer strips keep C/A/B/D targets. The independent DEX document qualifies explicit cyclic jog assembly, contact wires and source2730-count scaling. Manufacturer marketing says2000 points, so physical calibration remains unresolved. TSI independently corrects the DEX left pitch-bend-up target. Shift assignments, PFL button addresses and software Vinyl/keylock semantics conflict or are incomplete and stay inactive. No TSI, DEX code, MIDI query, source LED, firmware or installer runs. Manufacturer page18 explicitly warns against duplicate software/hardware EQ in default Pre EQ. This manual subset requires deliberate Post EQ ownership and separate audio. Initial/reconnected banks are A/B. Full lifecycle, exact modes, library encoder format, audio routing and iPad/A10X acceptance remain open."
}}


def vms5_profiles():
    result = profile("American Audio VMS5", TSI)
    result.update(autoSelect=False, definition="reviewed:vms5-independent-manual-banks",
                  aliases=["American Audio VMS5", "American Audio VMS5.0", "VMS5", "VMS5.0", "VMS5.0 AUDIO MIDI Device"],
                  excludedAliases=["VMS2", "VMS4", "VMS4.1", "VMS4.1 Traktor"],
                  hardwareMode="Manual native layout. Start on A/B after applying or reconnecting. Deck buttons select A/C and B/D. Use Post EQ for software EQ. Configure audio separately and avoid duplicate analogue/software mixer control.",
                  scope="Manual banked transport, pitch bend, tempo, contact/jog and fixed mixer controls. Source2730-count jog scale is provisional. No automatic ownership, feedback, hardware write or audio assignment.",
                  gaps=["Manufacturer2000-point claim conflicts with the DEX2730-count scale. Calibration, Shift/Vinyl/keylock modes, PFL, FX/sampler pads, complete library control, initial bank synchronisation, lifecycle, external mixer audio routing and physical/iPad/A10X acceptance remain open."])
    result["bankChanges"] = [{"channel": 0, "number": number, "onValue": 127, "decks": decks, "deckBank": bank}
                             for bank, number, decks in [(0, 14, ["a", "c"]), (1, 48, ["b", "d"])]]
    for bank, deck, offset in [(0, "a", 0), (1, "b", 34)]:
        for action, number in [("play", 12 + offset), ("cuePreview", 13 + offset),
                               ("sync", 17 + offset), ("pitchBendDown", 15 + offset),
                               ("pitchBendUp", 16 + offset), ("load", 103 + bank)]:
            add(result, action, 0, number, deck=deck)
            result["inputs"][-1]["deckBank"] = bank
        add(result, "tempo", bank, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1].update(deckBank=bank, inverted=True)
        add(result, "jogTouch", 0, 79 + bank, deck=deck)
        result["inputs"][-1]["deckBank"] = bank
        add(result, "jog", 0, 49 + 2 * bank, "control", "cyclic14BitJog", deck)
        result["inputs"][-1].update(deckBank=bank, lowNumber=48 + 2 * bank, argument=2730)
    for deck, base in [("c", 0), ("a", 5), ("b", 10), ("d", 15)]:
        for action, delta in [("gain", 0), ("high", 1), ("mid", 2), ("low", 3), ("level", 4)]:
            add(result, action, 0, base + delta, "control", deck=deck)
    add(result, "crossfader", 0, 31, "control")
    result["inputs"][-1]["inverted"] = True
    add(result, "cueMix", 0, 34, "control")
    return [result]

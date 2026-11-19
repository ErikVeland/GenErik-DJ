"""Independent manual VMS4.1 Traktor mixer facts without sibling transport."""
from curated import add, profile

TABLE = "https://www.adj.com/cdn/shop/files/3f2ef6d86a8275636284f11557be4fdcf27bff1a_vms4_1_traktor_midi_table.pdf?v=5359426295610137759"
MANUAL = "https://akeneo-asset-proxy.adj-group.workers.dev/dl/files/VMS599__DL__001.pdf"
VMS41_TRAKTOR_REFERENCES = {"American Audio VMS4.1 Traktor": {
    "url": TABLE, "sha256": "dc207f113d1735899a769ba18536994a98f6578eeaa1af189358d817c1f8703c",
    "pages": [2, 6, 7, 8, 9],
    "relatedSources": [{"url": "https://www.adj.com/collections/vms4-1-traktor-parts"},
                       {"url": MANUAL, "sha256": "9f55cc053272c38369833b18a53d20bc0385ad4fecc12807f212d1d3d656833e"}],
    "review": "The manufacturer lists this specific MIDI table and Traktor manual on its VMS4.1 Traktor service page. The table fixes all MIDI to channel1 and qualifies four independent five-CC mixer strips, normal crossfaderCC31, masterCC28, Cue mixCC34 and Cue gainCC35. Pages6-8 were visually reviewed. Native deliberately assigns physical CH1-4 to A-D. This is a manual mixer subset. The generic table's CUE/PLAY/PAUSE/HOT START labels do not reconcile fully with the Traktor manual's PLAY/CUE/A-C/SHIFT faceplate. No transport, bank, Shift, jog, encoder, LED, setup or source packet is inferred from the ordinary VMS4 or VMS5. The manual warns against duplicate hardware/software EQ in default Pre EQ. Use Post EQ for software EQ and deliberate ownership of analogue mixer controls. External deck audio routing, full mode/lifecycle contracts and physical/iPad/A10X acceptance remain open."
}}


def vms41_traktor_profiles():
    result = profile("American Audio VMS4.1 Traktor", TABLE)
    result.update(autoSelect=False, definition="reviewed:vms41-traktor-independent-mixer",
                  aliases=["American Audio VMS4.1 Traktor", "VMS4.1 Traktor", "VMS4.1 TRAKTOR", "VMS4.1 Traktor Edition"],
                  excludedAliases=["VMS2", "VMS4", "VMS4.1", "VMS5", "VMS5.0 AUDIO MIDI Device"],
                  hardwareMode="Manual mixer subset on MIDI channel1. Physical MIDILOG1-4 map A-D. Use Post EQ for software EQ. Configure audio separately and avoid duplicate analogue/software mixer control.",
                  scope="Manual24-input mixer subset from the manufacturer's separately listed Traktor-edition table. No sibling transport, software bank, jog, Shift, LED, setup or automatic audio ownership.",
                  gaps=["The table's generic transport labels conflict with the Traktor faceplate. Full transport/banks, Shift, jog format/calibration, touch strips, library encoders, mode/source handling, lifecycle, external deck audio routing and physical/iPad/A10X acceptance remain open. Default Pre EQ duplicates software EQ."])
    for index, deck in enumerate("abcd"):
        for action, delta in [("gain", 0), ("high", 1), ("mid", 2), ("low", 3), ("level", 4)]:
            add(result, action, 0, 5 * index + delta, "control", deck=deck)
    for action, number in [("master", 28), ("crossfader", 31), ("cueMix", 34), ("monitor", 35)]:
        add(result, action, 0, number, "control")
    return [result]

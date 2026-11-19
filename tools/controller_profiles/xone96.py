"""Xone:96 manual MIDI subset from the current manufacturer implementation table."""
from curated import add, profile

XONE96_NAME = "Allen & Heath Xone:96"
XONE96_SPEC = "https://support.allen-heath.com/hc/en-gb/articles/43084536824849-Xone-96-MIDI-Implementation"
XONE96_GUIDE = "https://support.allen-heath.com/hc/en-gb/articles/43053562464017-Xone-96-User-Guide"
XONE96_REFERENCES = {XONE96_NAME: {
    "url": XONE96_SPEC, "reviewDate": "2026-11-19",
    "relatedSources": [{"url": XONE96_GUIDE}, {"url": "https://www.allen-heath.com/hardware/xone-series/xone96/resources/"}],
    "review": "Current manufacturer HTML MIDI implementation and user guide reviewed. Default channel16 sends CH1-4 faders as CC0-3, crossfaderCC5 and CH1-4 Cue states as Notes0-3. Manufacturer specifies NoteOff00/NoteOn7F and CC00-7F. Native9-input manual layout assigns CH1-4 to A-D with existing four-deck opt-in. Cue uses direct state, not a toggle on every report. Source-selector notes19-34 retire the respective deck pickup on new127 reports. Alternate configured MIDI channels require a separate mapping. Auxiliary Cue channels, PHONES2, VCF/MUTE/source-state actions, analogue gain/four-band EQ/filter/headphone controls remain outside this subset. MIDI input to Cue/filter controls changes actual hardware state, so no native lamp/setting packet is sent. Manufacturer confirms class-compliant macOS/iPadOS/iOS USB, but external mixer deck routing and actual iPad acceptance remain open. Manual selection and separate app audio avoid automatic ownership of the analogue mixer. No Xone92/PX5/23C/24C protocol is inherited."
}}


def xone96_profiles():
    result = profile(XONE96_NAME, XONE96_SPEC)
    result.update(autoSelect=False, definition="reviewed:xone96-manufacturer-midi",
                  aliases=[XONE96_NAME, "Xone:96", "Xone 96", "Allen & Heath Xone 96"],
                  excludedAliases=["Xone:92", "Xone:PX5", "Xone:23C", "Xone:24C"],
                  hardwareMode="Manual MIDI layout on default channel16. Enable MIDI for the connected USB host. Physical CH1-4 map A-D. C/D require the app's four-deck option. Use separately configured app audio.",
                  scope="Manual9-input native CH1-4 fader/Cue-state and crossfader subset. Analogue mixer ownership, external deck routing and full control support remain open.",
                  gaps=["The hardware faders and Cue switches also affect analogue audio. Select this MIDI subset deliberately and configure app audio separately. Native does not set hardware Cue/filter states. Auxiliary channels/PHONES2, source-state actions, VCF/MUTE, complete lifecycle, external mixer deck outputs and physical/iPad/A10X acceptance remain open. Analogue gain/four-band EQ/filter/headphone controls are not MIDI knobs and are not duplicated. Alternate saved MIDI channels need separate mappings."])
    result["bankChanges"] = []
    for number, deck in enumerate("abcd"):
        add(result, "level", 15, number, "control", deck=deck)
        add(result, "cueState", 15, number, deck=deck)
        result["bankChanges"] += [dict(channel=15, number=source, onValue=127, decks=[deck])
                                  for source in range(19 + 4 * number, 23 + 4 * number)]
    add(result, "crossfader", 15, 5, "control")
    return [result]

"""Independent PX5 and 24C fader facts without analogue mixer ownership."""
from curated import add, profile

PX5_SOURCE = "https://virtualdj.com/forums/264850/VirtualDJ_Plugins/Mapping_the_XONE:PX5_Mixer.html"
XONE24C_SOURCE = "https://support.allen-heath.com/hc/en-gb/articles/39821017822865-Xone-24C-User-Guide"
XONE_FADER_REFERENCES = {
    "Allen & Heath Xone:PX5": {
        "url": PX5_SOURCE, "reviewDate": "2026-11-19",
        "relatedSources": [{"url": "https://cardinia.net/products/pro/", "sha256": "d8e08cc67c0305a63fb6d65eee0c1e79f1e5b11921520a9cbfddff233de4b998"},
                           {"url": "https://support.allen-heath.com/hc/en-gb/articles/43208403578641-Xone-PX5-User-Guide"}],
        "review": "The definition author's public XML qualifies physical fader CC0-3 and crossfaderCC4. Cardinia's own working hardware table independently qualifies channel16/faderCC0-3. Native explicitly assigns physical CH1-4 to A-D. The author's software C/A/B/D deck order is not a hardware address fact. Cue press-versus-state semantics, filter/FX assignment switches, selector values and encoder formats are not established sufficiently for native actions and remain inactive. Five manual faders only. No downloaded definition, VDJ command, X:Link sibling mapping, hardware write or audio command runs. Analogue mixer duplication, external audio routing and physical/iPad acceptance remain open."
    },
    "Allen & Heath Xone:24C": {
        "url": XONE24C_SOURCE, "reviewDate": "2026-11-19",
        "review": "Current manufacturer MIDI table explicitly fixes channel16 and faders crossCC4/CH1CC5/CH2CC6 with0-127 ranges. Native uses only these three manual faders. VCF FREQCC7 has126-0 mild-to-wild semantics and unqualified shared hardware assignment, so it is not treated as a bipolar deck filter. Prose mentions Cue/filter/insert buttons, but the shown table does not qualify their note addresses. Those remain inactive. No Xone96/PX5/23C protocol is inherited. Manufacturer qualifies class-compliant macOS/iOS USB and separate host/hub endpoints. It does not establish native external mixer routing, automatic audio ownership or physical/A10X acceptance."
    },
}


def xone_fader_profiles():
    results = []
    for name, numbers in [("Allen & Heath Xone:PX5", [0, 1, 2, 3]), ("Allen & Heath Xone:24C", [5, 6])]:
        result = profile(name, XONE_FADER_REFERENCES[name]["url"])
        model = name.split(":")[-1]
        result.update(autoSelect=False, definition="reviewed:xone-" + model.lower() + "-independent-faders",
                      aliases=[name, "Xone:" + model, "Xone " + model, "Allen & Heath Xone " + model],
                      excludedAliases=["Xone:" + other for other in ["96", "PX5", "24C", "23C"] if other != model],
                      hardwareMode="Manual fader subset on MIDI channel16 through the mixer's own USB host connection. Physical CH1 onward map A onward. Configure app audio separately. These controls also affect analogue audio.",
                      scope=f"Manual{len(numbers) + 1}-input linefader/crossfader subset from independent {model} facts. No automatic mixer/audio ownership or unqualified button controls.",
                      gaps=["Analogue audio and MIDI faders require deliberate ownership. Native does not send hardware commands or select an audio route. Cue/filter/FX/insert controls, source/mode handling, X:Link or USB-hub accessory protocols, complete lifecycle, external mixer outputs and physical/iPad/A10X acceptance remain open. No analogue EQ/gain/headphone knob or sibling protocol is invented."])
        for number, deck in zip(numbers, "abcd"):
            add(result, "level", 15, number, "control", deck=deck)
        add(result, "crossfader", 15, 4, "control")
        results.append(result)
    return results

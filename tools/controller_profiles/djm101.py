"""DJM-101 MIDI mixer core from the factory guide and pinned mapping."""
from curated import add, profile
from numark import UPSTREAM

DJM101_GUIDE = "https://asset.conrad.com/media10/add/160267/c1/-/gl/000090874ML01/mode-demploi-090874-table-de-mixage-dj-tech-djm101-1-pcs.pdf"
VTT101_GUIDE = "https://asset.conrad.com/media10/add/160267/c1/-/gl/000092385ML01/mode-demploi-092385-mini-controleur-usb-dj-tech-vtt101.pdf"
DJM101_SOURCES = [
    ("DJ-Tech DJM-101.midi.xml", "e6fd3dafde0b0044841208ce92021190e4f02caab4c042766122b5f97e99587c"),
    ("DJ-Tech-DJM-101-scripts.js", "fc98d0142c7265e67f7da8bcf0655811e19a25af8dfe40bba2688e03baeb1745"),
]
DJM101_REFERENCES = {"DJ-Tech DJM-101": {
    "url": UPSTREAM + DJM101_SOURCES[0][0].replace(" ", "%20"), "sha256": DJM101_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in DJM101_SOURCES]
        + [{"url": DJM101_GUIDE, "sha256": "5c3159ccccd5fb41a2c9f7ee6f5c3f936d1b339646ed7ac959e089f055c09485", "pages": [4, 5]}],
    "review": "Factory guide documents a driver-free USB MIDI mixer, eleven pots, three faders, two PFL keys and a meter-source switch. Its channel-one A/B configuration matches pinned wire channel zero. XML supplies all sixteen native mixer inputs, including asymmetric Gain/High/Mid/Low addresses. Companion script supplies PFL note-on127/off0 feedback and four distinct master/deck meter CC addresses. Native lifecycle clears those meters and PFL lights with twelve total messages. The script's potential 0xF7 meter data exceeds seven-bit MIDI; no such live meter output is copied. Meter switch, live levels, hardware crossfader curve, other channel selections and physical acceptance remain open. Fader position is not a live level measurement. This is a MIDI accessory, not an integrated audio interface or a DJ-Tech MIX-101/Mixer One alias.",
}}


def djm101_profiles():
    result = profile("DJ-Tech DJM-101", DJM101_REFERENCES["DJ-Tech DJM-101"]["url"])
    result["role"] = "accessory"
    result["hardwareMode"] = "Hardware MIDI channel 1 for the published A/B mixer mapping."
    result["scope"] = "Automatic channel-one MIDI mixer core with physical gain/EQ/volume, PFL and global mixer controls. Live meters and source switch, curve behaviour, other channel selections and physical acceptance remain open."
    for side, deck in enumerate("ab"):
        for action, numbers in [("gain", [0x48, 0x4F]), ("high", [0x4A, 0x4D]),
                                ("mid", [0x4E, 0x4B]), ("low", [0x4C, 0x49]), ("level", [0x41, 0x42])]:
            add(result, action, 0, numbers[side], "control", deck=deck)
        add(result, "cue", 0, 0x21 + side, deck=deck, feedback=True)
    for action, number in [("crossfader", 0x40), ("master", 0x43), ("cueMix", 0x44), ("monitor", 0x45)]:
        add(result, action, 0, number, "control")
    result["startup"] = [[0xB0, number, 0] for number in range(0x50, 0x54)]
    result["startup"].extend([[0x90, 0x21, 0], [0x90, 0x22, 0]])
    result["shutdown"] = list(result["startup"])
    return [result]

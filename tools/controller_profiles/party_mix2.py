"""Party Mix II native core facts from pinned community protocol references."""
from curated import add
from party_mix import party_mix_profiles

PARTY2_BASE = "https://github.com/JakeDucati/mixxx_numark-party-mix-ii-mappings/blob/f020c34fa1b682ac4a862d0daa9621b958465525/"
PARTY2_SECONDARY = "https://github.com/cokeramirez/Party-Mix-MK2-MIXXX-advanced-mapping/blob/c06e36112728592bad996c51ed416f4af6d053eb/"
PARTY2_SOURCES = [
    ("Numark Party Mix ii.midi.xml", PARTY2_BASE + "Numark%20Party%20Mix%20ii.midi.xml", "38615ae6f30cb2159856b4926fbc1734781a1a9e9c0b6f2ce19880528bd71e84"),
    ("Numark-Party-Mix-ii.scripts.js", PARTY2_BASE + "Numark-Party-Mix-ii.scripts.js", "ed38574f615320c1d6457d1a94dd81a1d69bc73541e54e8f7a2b5eaa3ed82a41"),
    ("README.md", PARTY2_BASE + "README.md", "0c80ef20b0dd0640005e8ca5cb916364e4b12c7df54f9a843189ffa394227d73"),
    ("cokeramirez-Numark Party Mix MK2 new jog.midi.xml", PARTY2_SECONDARY + "Numark%20Party%20Mix%20MK2%20new%20jog.midi.xml", "917f09196f60b0b7abc610c145f026f3c116b1f871053e0bd37f755ee27f0e62"),
    ("cokeramirez-Numark-Party-Mix-MK2-newjog.js", PARTY2_SECONDARY + "Numark-Party-Mix-MK2-newjog.js", "e31613074c4aaa7c24faa124b0c4a713a27039036d684be795b9635a2c5811f4"),
    ("cokeramirez-README.md", PARTY2_SECONDARY + "README.md", "4ea82ffdf81b2bf185e068f941398ce99aad77839598529f7146373465c646d2"),
]
PARTY2_REFERENCES = {"Numark Party Mix II": {
    "url": PARTY2_SOURCES[1][1], "sha256": PARTY2_SOURCES[1][2],
    "relatedSources": [{"url": url, "sha256": digest} for _, url, digest in PARTY2_SOURCES],
    "review": "Native actions replace the scripts. Both revisions identify the model as Party Mix II/MK2 and agree on core controller facts. The newer XML explicitly handles touch release and Browse note 7; the older XML retains obsolete Browse/Scratch entries. The secondary mapping declares AI-assisted development. Its advanced lamp, jog-setup and heartbeat commands are not used. Pad Mode hold note 50 comes from that secondary mapping and remains physically unverified. Original Party Mix facts remain separate; Live/III/Pro do not inherit this recipe."}}


def party_mix2_profiles():
    result = party_mix_profiles()[0]
    result.update(id="Numark Party Mix II", aliases=["Numark Party Mix II", "Party Mix II", "Numark Party Mix MK2", "Party Mix MK2"],
                  definition="reviewed:numark-party-mix-ii", source=PARTY2_REFERENCES["Numark Party Mix II"]["url"],
                  scope="Automatic native core controls, touch jogs and mode-gated Hot Cues/loops. Pad Mode hold blocks unsupported delete actions. Other pad modes, lights, advanced lifecycle and audio routing remain open.")
    result["inputs"] = [binding for binding in result["inputs"] if not binding["action"].startswith("toggleFixedLoop")]
    for binding in result["inputs"]:
        if binding["action"] in {"wheelJogA", "wheelJogB"}:
            binding["action"] = binding["action"].replace("wheelJog", "jog")
        elif binding["action"] == "openGroup":
            binding["number"] = 7
        elif binding["action"].startswith("hotcue"):
            binding["shifted"] = False
    for channel, deck in enumerate("ab"):
        add(result, "jogTouch", channel, 6, deck=deck)
        for slot, beats in enumerate([2, 4, 8, 16]):
            add(result, "toggleFixedLoop", 4 + channel, 20 + slot, deck=deck)
            result["inputs"][-1].update(argument=beats, requiredMode=14, shifted=False)
    add(result, "shift", 15, 50)
    for mode in result["inputModes"]:
        mode["numbers"] = [0, 11, 14, 15]
    result["startup"] = [[0xF0, 0, 1, 63, 56, 72, 0xF7]]
    for channel in range(2):
        result["startup"].extend([[0x94 + channel, number, 127 if number == 0 else 1] for number in [0, 11, 14, 15]])
    result["shutdown"] = [[0x80 + channel, number, 0] for channel in range(2) for number in [0, 2, 27]]
    result["gaps"] = ["Sampler/FX pad actions, cue deletion and pad lights, browser hold gestures, rear-lamp control, advanced lamp/jog setup, heartbeat handling and full audio routing remain unimplemented. Core setup uses only the older published status request and mode indicators. The secondary source declares AI-assisted development; its Pad Mode hold address and all physical behaviour remain unverified. Source reuse/distribution review remains open. Live, III and Pro require separate source review."]
    return [result]

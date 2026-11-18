"""DDM4000 manual MIDI-enabled mixer inputs from independent pinned source."""
from curated import add, profile
from numark import UPSTREAM

DDM_NAME = "Behringer DDM4000"
DDM_SOURCES = [
    ("Behringer DDM4000.midi.xml", "74724faeac70e591badee6dbe7478171294239e4c2eb310cf05bde480fcb20a0"),
    ("Behringer-DDM4000-scripts.js", "ead855d1801c8aed74c97a61e46944da81e2d1a29db4d009c26d010a4b51bcc4"),
    ("Behringer-Extension-scripts.js", "6c175dcf576804ccb09389075550b08f483c7c1c53569bad9d8d548ee4d0da89"),
    ("midi-components-0.0.js", "f15845d0b3fa10609aedc2fb74a9067d0f1d89387f011de72c3301799003f026"),
]
DDM_REFERENCES = {DDM_NAME: {
    "url": UPSTREAM + DDM_SOURCES[1][0], "sha256": DDM_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + filename.replace(" ", "%20"), "sha256": digest} for filename, digest in DDM_SOURCES] +
                       [{"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/behringer_ddm4000"}],
    "review": "Independent script uses wire channel0. Four A/B/C/D strips use high/mid/low/level CC4/5/6/7,8/9/10/11,12/13/14/15,16/17/18/19. Equalizer parameter3 is high and parameter1 low; physical strip order is not inferred from another CMD controller. PFL input Notes63/73/83/93 are separate from their same-number CC light output. Native fixed crossfader uses CC21. Source init changes output message type only and requires no input handshake. The helper staggers controller component initialisation at40 ms; it does not impose a40 ms interval on each live lamp message. Four independently addressed PFL CC lamps retain the component on127/off0 values. Full source light initialisation remains unqualified. Hardware gain/trim, microphone, kills, sampler, crossfader assignments/enable/curve/reverse and other modes remain unmapped. Hardware sections must be explicitly configured for MIDI and the MIDI channel set to1. The mixer has DIN MIDI ports, no USB MIDI or digital audio interface; a separate host-visible MIDI interface and separate audio routing are required. Manual selection prevents arbitrary DIN bridge identity from claiming automatic device recognition. No persistent setup, sibling protocol or audio route is inferred. Full output/lifecycle and physical/A10X acceptance remain open.",
}}


def ddm4000_profiles():
    result = profile(DDM_NAME, DDM_REFERENCES[DDM_NAME]["url"])
    result.update(definition="reviewed:ddm4000", role="accessory", autoSelect=False,
                  excludedAliases=["BCR2000", "BCF2000", "CMD MM-1"],
                  hardwareMode="Manual DIN MIDI accessory through a separate host-visible interface. MIDI channel1 and required hardware sections in MIDI mode. Native fixed A/B/C/D strips; C/D requires app opt-in. Audio stays separate.",
                  scope="Manual four-strip EQ/level/PFL and fixed native crossfader input. DIN/section setup, assignment/reverse/curve/kill/sampler/FX modes, complete output/lifecycle and physical acceptance remain open.")
    for index, deck in enumerate("abcd"):
        for offset, action in enumerate(["high", "mid", "low", "level"]):
            add(result, action, 0, 4 + index*4 + offset, "control", deck=deck)
        add(result, "cue", 0, 63 + index*10, deck=deck)
        result["outputs"].append(dict(action="cue"+("A" if deck in "ac" else "B"), kind="control", channel=0,
                                      number=63+index*10, targetDeck=deck, onValue=127, offValue=0, offUsesNoteOn=False))
    add(result, "crossfader", 0, 21, "control")
    result["gaps"] = ["Manual DIN MIDI through a separate interface, with hardware section/channel setup. The mixer has no USB MIDI or digital audio interface. Fixed native crossfader omits source assignment/enable/curve/reverse semantics. Hardware trim, kills, microphone/sampler/FX, staggered full light initialisation and complete output/lifecycle and physical/A10X acceptance remain open. PFL outputs are CC63/73/83/93, not their input Notes."]
    return [result]

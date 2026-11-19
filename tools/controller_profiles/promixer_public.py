"""Independent MIDI facts from visible public ProMixer XML documents."""
from curated import add, profile

INSTALLER = "https://dmsdown.com/descargas/DMS_DJPROMIXER/DJProMixer_3.0_Setup.exe"
INSTALLER_SHA = "0557173bb5cb8bce866bbd439bd10140d8c281fd550486541dc4ddfff46edbec"
AFX_PAGE = "https://djpromixerblog.com/2015/06/13/akai-afx/"
EDGE_PAGE = "https://djpromixerblog.com/2015/06/10/numark-mixtrack-edge-2/"
PROMIXER_REFERENCES = {
    "Akai Pro AFX": {"url": INSTALLER, "sha256": INSTALLER_SHA,
                     "members": [{"path": "Devices/AKAI AFX Mode 1.xml", "sha256": "1e99bbd92f883ab727986aab19902298e1ecdcbf2b79c26d4296bd5d46f247ca"},
                                 {"path": "Devices/AKAI AFX Mode 2.xml", "sha256": "5d2e6e53fa046801a37708b8cd60087dbf83f02997eda8e3e8b045b50bb0ccd2"}],
                     "relatedSources": [{"url": AFX_PAGE}, {"url": "https://djpromixerblog.com/midi-learn/"}],
                     "review": "Two visible factory XML documents independently retain the same A/B pad, transport and library wires. The developer's own guide describes six Cue pads plus store/delete, eight fixed loops from1/4 to32 beats, transport/loop pads and browse/load. Native uses44 manual inputs. Source software-generated EQ/level commands101-108 and unqualified tactile/FX/Shift/deck modes are not treated as hardware proof. No ProMixer executable, installer, mapping action, activation, account or network-sharing service runs. Only independent MIDI address facts are transcribed. Complete C/D modes, touch-strip calibration, FX, feedback/lifecycle and physical/iPad/A10X acceptance remain open."},
    "Numark Mixtrack Edge": {"url": INSTALLER, "sha256": INSTALLER_SHA,
                             "members": [{"path": "Devices/NUMARK MIXTRACK-EDGE.xml", "sha256": "8384c6959823ec9572cc36fe1a8db31aac98892a6de6a4549c7dba475ead411e"}],
                             "relatedSources": [{"url": EDGE_PAGE}, {"url": "https://www.numark.com/product/mixtrack-edge"}],
                             "review": "The visible120-row factory XML and developer guide qualify normal A/B transport, three Cue pads, manual loops, PFL, two-band mixer and library wires. Global Shift Note38 is declared twice and becomes one native held input. Normal button releases rearm on Shift without firing the unsupported alternate action. Overflow commands137/142-144/164 do not become raw MIDI notes. The strict browse contract accepts1/127 only. The hardware is class-compliant on desktop, but jog/touch/tempo modes, calibration, complete lifecycle, feedback, split audio assignment and physical/iPad/A10X acceptance are not established. Native uses51 manual inputs without hardware writes. No source XML, program or installer is bundled or executed."},
}


def promixer_public_profiles():
    afx = profile("Akai Pro AFX", INSTALLER)
    afx.update(autoSelect=False, role="accessory", definition="reviewed:afx-public-pad-transport-facts",
               aliases=["Akai Pro AFX", "Akai AFX", "AFX", "Akai Pro AFX 0", "Akai Pro AFX 1"],
               excludedAliases=["Akai AMX", "AMX", "APC mini", "AFX clone"],
               hardwareMode="Manual A/B pad accessory subset. Use normal Cue, Auto Loop and Transport pad modes. Native keeps six Cue pads and eight fixed loops per side. Configure app audio separately.",
               scope="Manual44-input A/B pad, transport and library subset cross-checked in two visible factory documents. No source software modes, FX, hardware write or audio route is inherited.",
               gaps=["C/D selection, Shift/FX modes, tactile search/pitch/scratch calibration, remaining pads, source state, full feedback/lifecycle and physical/iPad/A10X acceptance remain open. Generated EQ/volume commands101-108 are not physical wire proof."])
    for channel, deck in [(1, "a"), (2, "b")]:
        afx.setdefault("bankChanges", []).extend(
            {"channel": channel, "number": number, "onValue": 127, "decks": [deck]}
            for number in [23, 24, 25, 27])
        for action, number in [("play", 49), ("cuePreview", 50), ("sync", 51),
                               ("loopIn", 45), ("loopOut", 46), ("reloop", 47), ("load", 28)]:
            add(afx, action, channel, number, deck=deck)
        for slot in range(6):
            add(afx, f"hotcue{slot + 1}", channel, 29 + slot, deck=deck)
        for slot, beats in enumerate([0.25, 0.5, 1, 2, 4, 8, 16, 32]):
            add(afx, "toggleFixedLoop", channel, 37 + slot, deck=deck)
            afx["inputs"][-1]["argument"] = beats
        add(afx, "browse", channel, 9, "control", "signedStep")

    edge = profile("Numark Mixtrack Edge", INSTALLER)
    edge.update(autoSelect=False, definition="reviewed:mixtrack-edge-public-normal-facts",
                aliases=["Numark Mixtrack Edge", "Mixtrack Edge", "MixTrack-Edge"],
                excludedAliases=["Mixtrack", "Mixtrack Pro", "Mixtrack Pro II", "Mixtrack Pro III", "Mixtrack Edge clone"],
                hardwareMode="Manual normal-layer subset. Shared Shift retires holds and suppresses unsupported alternate buttons. Use app touch jog/tempo and configure audio separately.",
                scope="Manual51-input normal/Shift-release transport, three cues, manual loops, mixer and strict library encoder subset. No overflow command, unqualified jog, hardware write or automatic audio assignment.",
                gaps=["Software overflow commands do not identify raw MIDI. Shift/FX alternatives, multifunction jog/touch/tempo modes and calibration, full feedback/lifecycle, USB audio pair order and physical/iPad/A10X acceptance remain open."])
    add(edge, "shift", 0, 38)
    edge["bankChanges"] = [{"channel": 0, "number": 38, "onValue": 127,
                            "decks": ["a", "b"], "releaseShiftChannels": []}]
    for channel, deck in [(1, "a"), (2, "b")]:
        for action, number in [("play", 59), ("cuePreview", 51), ("sync", 64), ("cue", 37),
                               ("loopIn", 44), ("loopOut", 43), ("reloop", 42),
                               ("hotcue1", 47), ("hotcue2", 46), ("hotcue3", 45)]:
            add(edge, action, channel, number, deck=deck)
            edge["inputs"][-1]["shifted"] = False
            edge["inputs"].append(dict(edge["inputs"][-1], shifted=True, releaseOnly=True))
        for action, number in [("level", 8), ("high", 10), ("low", 11)]:
            add(edge, action, channel, number, "control", deck=deck)
        add(edge, "browse", channel, 38, "control", "signedStep")
    add(edge, "crossfader", 0, 1, "control")
    add(edge, "cueMix", 0, 9, "control")
    return [afx, edge]

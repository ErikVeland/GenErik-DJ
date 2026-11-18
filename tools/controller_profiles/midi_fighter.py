"""Separate Classic default pads and Twister fixed normal mixer contracts."""
from curated import add, profile
from numark import UPSTREAM

CLASSIC_MAP = "https://djtechtools.com/mf_documentation/Midi%20Fighter%20Classic%20MIDI%20Map.pdf"
CLASSIC_MAP_SHA = "fcc7c09264936aca8f276505ea6cf4110cb8fced17a0c3773f145d30ad2c3bc7"
FIGHTER_SOURCES = {
    "DJ TechTools MIDI Fighter": [
        ("DJTechTools MIDI Fighter.midi.xml", "2f92f9c317337ef0866da8323e42a3be878fdb0847ecdeebe06ccae7ab8d6120"),
        ("DJTechTools-MIDIFighter-scripts.js", "38836ff9410778a216efe63fd05240e534782f39ed94df7d9214b2ea5ccd3748"),
    ],
    "DJ TechTools MIDI Fighter Twister": [
        ("DJ TechTools MIDI Fighter Twister.midi.xml", "fb875ed8e2518d3ae773c1e4a20a471190fa461c33a40a0364cd8c51ff904ca7"),
        ("DJ TechTools-MIDI Fighter Twister-scripts.js", "4bfb41f2ea7380a8f6eaf7ca894578df7c301081f500fd07961ae9d620e92336"),
    ],
}
FIGHTER_REFERENCES = {name: {
    "url": UPSTREAM+sources[0][0].replace(" ","%20"), "sha256": sources[0][1],
    "relatedSources": [{"url": UPSTREAM+sources[1][0].replace(" ","%20"), "sha256": sources[1][1]}] + (
        [{"url": CLASSIC_MAP,"sha256": CLASSIC_MAP_SHA,"pages":[1,2,3]}] if not name.endswith("Twister") else
        [{"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/dj_techtools_midi_fighter_twister"}]),
    "review": (
        "Classic factory PDF confirms Default, Four Banks Internal and Four Banks External are distinct maps. Default ships with16 notes. The pinned XML supplies wire channel2 and Note36..51. The actual script initialiser, not its older two-deck header/manual, maps top-to-bottom rows C/A/B/D with four cues each:48..51,44..47,40..43,36..39. Native C/D retain app opt-in. Both release forms rearm notes without starting a cue. No extra transport, sampler, LED or preset operation is invented. Four-bank modes, configurable MIDI channels and complete light/lifecycle behaviour remain unqualified."
        if not name.endswith("Twister") else
        "Twister has a separate normal mixer contract. Left A controls are gain0/high1/mid5/low9/level8/filter13/tempo4; right B controls3/2/6/10/11/14/7, all channel0 CC. Source components use normal0..127 parameters. Native pitch reverses Mixxx rate normalisation. Channel1 CC4/7 reset tempo,8/11 toggle PFL,13/14 toggle filter. These source actions do not change under Shift and remain independent. Channel3 CC10/13/16/19/22/25 are six separately owned Shift buttons. Global CC12 crossfader and15 master are normal-only; shifted15 controls headphone level. Normal fixed A/B targets replace source software C/D toggles. FX/stem bank addresses remain inactive. No Classic pad addresses, LED values, persistent preset or firmware command is inherited.") +
        " Input initialisation has no required hardware handshake in the reviewed source. Named ports only. Full modes/output/lifecycle, calibration and physical/A10X acceptance remain open. No downloaded script executes in the app.",
} for name,sources in FIGHTER_SOURCES.items()}


def fighter_profiles():
    classic = profile("DJ TechTools MIDI Fighter",FIGHTER_REFERENCES["DJ TechTools MIDI Fighter"]["url"])
    classic["definition"] = "reviewed:midifighter-classic"
    classic["role"] = "accessory"
    classic["aliases"] += ["Midi Fighter Classic","DJ TechTools MIDI Fighter Classic","DJTechTools MIDIFighter"]
    classic["excludedAliases"] = ["Midi Fighter Spectra","Midi Fighter Twister","Midi Fighter 3D","Midi Fighter 64"]
    classic["hardwareMode"] = "Classic factory Default mode, MIDI channel3. Four-bank modes and configurable channels remain unqualified. Fixed C/A/B/D rows; C/D require app opt-in."
    classic["scope"] = "Automatic Classic Default input core: four cues per C/A/B/D row. Four-bank modes, complete LED/lifecycle and physical acceptance remain open."
    for deck,base in zip("cabd",[48,44,40,36]):
        for slot in range(4):
            add(classic,f"hotcue{slot+1}",2,base+slot,deck=deck)
    classic["gaps"] = ["Classic factory Default/channel3 only. Four Banks Internal/External, expansion switches, configurable channels, menu/preset programming, full LED output/lifecycle and physical/A10X acceptance remain open. No modern MIDI Fighter protocol or audio route is inferred."]

    twister = profile("DJ TechTools MIDI Fighter Twister",FIGHTER_REFERENCES["DJ TechTools MIDI Fighter Twister"]["url"])
    twister["definition"] = "reviewed:midifighter-twister"
    twister["role"] = "accessory"
    twister["aliases"].append("Midi Fighter Twister")
    twister["excludedAliases"] = ["Midi Fighter Classic","Midi Fighter Spectra","Midi Fighter 3D","Midi Fighter 64"]
    twister["hardwareMode"] = "Twister normal first mixer layer and source absolute CC configuration. Fixed native A/B mixer targets. Other hardware/preset configurations remain unqualified."
    twister["scope"] = "Automatic fixed A/B normal mixer input core, PFL/filter switches, tempo reset and independent Shift-owned global headphone level. Software bank toggles, resets/FX/stems/output and physical acceptance remain open."
    for number in [10,13,16,19,22,25]:
        add(twister,"shift",3,number,"control")
    for deck,numbers in [("a",[0,1,5,9,8,13,4]),("b",[3,2,6,10,11,14,7])]:
        for action,number in zip(["gain","high","mid","low","level","filterKnob","tempo"],numbers):
            add(twister,action,0,number,"control",deck=deck)
            if action == "tempo": twister["inputs"][-1]["inverted"] = True
        for action,number in [("tempoReset",4 if deck == "a" else 7),("cue",8 if deck == "a" else 11),
                              ("filterToggle",13 if deck == "a" else 14)]:
            add(twister,action,1,number,"control",deck=deck)
    for action,number in [("crossfader",12),("master",15),("monitor",15)]:
        add(twister,action,0,number,"control")
        twister["inputs"][-1]["shifted"] = action == "monitor"
    twister["gaps"] = ["Fixed normal A/B mixer only. Source software C/D toggles, EQ gain/reset/kill variants, balance, FX/stem/sequencer banks, full encoder rings/colours/meters, feedback/lifecycle and persistent preset/firmware configuration remain unimplemented. Native range calibration and physical/A10X acceptance remain open. No Classic/Spectra/3D/64 protocol or audio route is inferred."]
    return [classic,twister]

"""Independent Spectra default-bank input facts and transient bank selection."""
from curated import add, profile
from numark import UPSTREAM

SPECTRA_NAME = "DJ TechTools MIDI Fighter Spectra"
SPECTRA_SOURCES = [
    ("DJ TechTools MIDI Fighter Spectra.midi.xml", "2ae64044c60cc85c3b5c11cacd90f2ff4d018ac8859fdb1a15d9f40eb411fc26"),
    ("DJ TechTools-MIDI Fighter Spectra-scripts.js", "e727b3e2c7a4c5c9b845e69a1576f7e1ccd78e1d0c3df7ef812d027d6d73dcce"),
]
SPECTRA_GUIDE = "https://s3.amazonaws.com/MF_Support_Docs/Midi%20Fighter%20Spectra%20User%20Guide.pdf"
SPECTRA_GUIDE_SHA = "61d2caa678947120cdb933741de7c14aace319797a388dfb7d95a3b1fea4b4da"
SPECTRA_REFERENCES = {SPECTRA_NAME: {
    "url": SPECTRA_GUIDE, "sha256": SPECTRA_GUIDE_SHA,
    "relatedSources": [{"url": UPSTREAM + filename.replace(" ", "%20"), "sha256": digest} for filename, digest in SPECTRA_SOURCES] +
                       [{"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/dj_techtools_midi_fighter_spectra"}],
    "review": "Manufacturer default arcade channel3 is wire2; every physical press is Note On and release Note Off. Native release never becomes activation regardless of release velocity. The pinned XML/script separately qualifies cue notes60..63/56..59, selectors52..55 and84..87 and C/A/B/D filter switches36..39. Source-local selection startsA, changes only on positive selector input and releases owned contacts/pickup before further cue dispatch. Logical cue notes64..71 use selected channels0..3; fixed filters use logical channel4, preventing raw logical injection. Guide page11 and script init agree on transient bank selection channel4 Note1 velocity127 for hotcues, despite conflicting octave prose elsewhere. Hardware bank notifications channel4 Notes0..3 release owned contacts; stale releases cannot clear a different current bank. Default momentary CC duplicates are ignored. Only the reviewed default base channel and normal firmware are qualified. Startup requires one paired output and fails closed on failure. No persistent preset, firmware, EQ kill, marker, sampler/stem, colour palette, animation or selected-deck output is inferred. Full modes/feedback/lifecycle and physical/A10X acceptance remain open.",
}}


def spectra_profiles():
    result = profile(SPECTRA_NAME, SPECTRA_GUIDE)
    result.update(definition="reviewed:midifighter-spectra", role="accessory", inputProtocol="midiFighterSpectra",
                  hardwareMode="Normal Spectra firmware and default base channel. Transient startup selects hotcue bank. Side buttons retain hardware bank selection. Selected deck startsA; C/D requires app opt-in.",
                  scope="Automatic default-bank input core with eight selected-deck cues, four fixed filter switches and safe hardware bank/deck boundaries. Full EQ/marker/sampler/stem/feedback modes and physical acceptance remain open.")
    result["aliases"].append("Midi Fighter Spectra")
    result["excludedAliases"] = ["Midi Fighter Classic", "Midi Fighter Twister", "Midi Fighter 3D", "Midi Fighter 64"]
    result["startup"] = [[0x93, 1, 127]]
    for channel, deck in enumerate("abcd"):
        for slot in range(8):
            add(result, f"hotcue{slot+1}", channel, 64+slot, deck=deck)
    for number, deck in zip(range(36,40),"cabd"):
        add(result, "filterToggle", 4, number, deck=deck)
    result["gaps"] = ["Normal firmware/default base channel only. Custom side-button/channel configurations, EQ kills, intro/outro markers, samplers/stems, selected-deck cue/filter RGB and ground/beat/track-end animations, complete feedback/lifecycle and physical/A10X acceptance remain open. Manual input conversion does not send factory startup. No persistent preset or audio interface is inferred."]
    return [result]

"""Original Hercules MK4 MIDI core for an exposed driver-translated MIDI port."""
from curated import add, profile

MK4_NAME = "Hercules DJ Console MK4"
MK4_GUIDE = "https://ts.hercules.com/download/sound/manuals/Mk4/DJ_Console_Mk4_ENG.pdf"
MK4_REFERENCES = {MK4_NAME: {
    "url": MK4_GUIDE,
    "sha256": "914feabd4b8e1f8ac5acd084ca6ce09d2575a75acc7e679d73721af36057a03c",
    "pages": [3, 18, 26, 27, 28],
    "relatedSources": [{
        "url": "https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg",
        "sha256": "55aaca2c33e7f1b84b420ab20f2c261f1c98ee73b62b3c012e25616f39070030",
        "member": "Applications/DEX4.app/Contents/Resources/controllers/Hercules__DJ_Console_MK4.js",
        "memberSHA256": "426fb02d842475dfa781f1b2ac643496ce10345cd034a4563a04903af4119226",
    }],
    "review": "The original manufacturer guide defines default MIDI channel1, held127/0 buttons, two's-complement relative pitch/jog and fixed mixer addresses. Driver setup applies to desktop operation; no native iPad USB access is established. Independent MK4-specific DEX script corroborates normal value direction for EQ/blend despite the guide's reversed CW/CCW wording. Its channel0 wire map agrees with the pinned Mixxx XML and supplies the native fixed1/2/4/8 loop layout on normal K1-4. Native tempo uses signed relative magnitude against the app's existing plus/minus8-percent range, not the Mixxx script's custom sensitivity or an absolute slider. DEX specifies128 wheel positions per revolution; retain that source scale for sensorless nudge/paused seek, with physical calibration open. There is no contact sensor or inferred scratch state. Physical Scratch, K-bank/Shift state and source selectors do not become synthetic contacts, app Shift, software audio changes or FX. Factory Play/Cue/Sync/PFL lights use note127/0 on their own addresses. No blanket94-light reset, update-all-controls query, stored setting, driver installation or firmware command is sent. Manual input and feedback remain separate selections. Full modes, search, light ownership/lifecycle, driver/bridge and audio routing plus physical/A10X acceptance remain open.",
}}


def mk4_profiles():
    result = profile(MK4_NAME, MK4_GUIDE)
    result.update(autoSelect=False, aliases=[MK4_NAME, "Hercules DJ Console Mk4", "DJ Console Mk4", "Hercules MK4"],
                  excludedAliases=["DJ Console 4-Mx", "DJ Console RMX", "DJ Console MK2"],
                  hardwareMode="Manual default-channel1 MIDI through the desktop driver or an external bridge. Select computer sources. Native iPad USB access and hardware/software audio ownership remain unresolved.",
                  scope="Manual A/B transport, held Cue/bends, fixed1/2/4/8 loops, relative tempo, sensorless wheel nudge/seek, fixed mixer and browsing. Eight explicit transport/PFL lamps. No native USB/audio qualification.",
                  gaps=["Desktop driver/bridge and native iPad USB access remain open. Manual default channel1 only. Native relative tempo differs from the old custom sensitivity. Normal K buttons use a fixed1/2/4/8 loop layout. K-bank/Shift modes, shifted FX, Scratch/contact, source/audio switching, search, gain/master/headphone knobs, complete light ownership/setup/lifecycle/audio and physical/A10X acceptance remain open. No RMX/4-Mx protocol, blanket lamp reset, update query or stored setting is inferred."])
    for side, deck in enumerate("ab"):
        base = side * 20
        for action, number in [("play",15),("cuePreview",14),("sync",18),("cue",16),
                               ("load",17),("pitchBendDown",10),("pitchBendUp",11)]:
            add(result,action,0,base+number,deck=deck,feedback=action in {"play","cuePreview","sync","cue"})
        for slot, beats in enumerate([1,2,4,8]):
            add(result,"toggleFixedLoop",0,base+1+slot,deck=deck)
            result["inputs"][-1]["argument"] = beats
        for action, number in [("level",52),("high",53),("mid",54),("low",55)]:
            add(result,action,0,number+side*5,"control",deck=deck)
        add(result,"tempo",0,50+side,"control","twosComplement",deck)
        add(result,"wheelJog",0,48+side,"control","twosComplement",deck)
        result["inputs"][-1]["argument"] = 128
    for action, number in [("crossfader",56),("cueMix",61)]:
        add(result,action,0,number,"control")
    for action, number in [("browsePrevious",41),("browseNext",42)]:
        add(result,action,0,number)
    return [result]

"""Independent XW-DJ1 manufacturer MIDI, modifier and split-output facts."""
from curated import add, profile

XWDJ1_NAME = "Casio XW-DJ1"
XWDJ1_SPEC = "https://www.casio.com/content/dam/casio/global/support/manuals/electronic-musical-instruments/pdf/008-en/w/Web_XWDJ1-E-2A_EN.pdf"
XWDJ1_SETUP = "https://support.casio.com/storage/common/support/download_files/en/008/manuals/XW-DJ1_TRAKTOR_setting_manual_en.pdf"
XWDJ1_REFERENCES = {XWDJ1_NAME: {
    "url": XWDJ1_SPEC, "sha256": "aed8a4d8f404b65fe61a1945f162fe022af32763fa64d2c9800b25677ebe0fa8",
    "relatedSources": [{"url": XWDJ1_SETUP, "sha256": "f10a308a891ff1d5b9b534fb37842c49b01b0537ef2086e34e2b4ed911c08375"}],
    "review": "English manufacturer tutorial printed page16 visually reviewed. Unlike XW-J1, XW-DJ1 uses shared Shift channel1 Note46, deck Play42/Cue44/SET43/Sync45, three cues41/40/39, loop35/36/37, contact59 and filter19 on deck channels1/2. The chart explicitly gives shared channel3 CC16/17 raw-minus64 jogs and300 positions per revolution. RIGHT/LEFT SCRATCH select the physical fader orientation and also act as Shift. Both crossfader CC16 channels are qualified. Manufacturer Traktor setup PDF pages3/5 visually reviewed: XW-DJ1 MIDI identity, CoreAudio without the Windows driver, master1/2 and headphones3/4. Its documented shifted Play loads, Sync fixes key, outer loop buttons set In/Out and shifted jog browses. Native SET stores Cue rather than implementing source CUP release-play. Native held Cue, fixed touch scratch, loop sizing, keylock and Shift-Load are explicit app semantics. Native steady14 lamp recipes use chart on127/off0. No hot-cue deletion, three separate effect slots, fast search, mode write, device reset, driver, TSI code or generic Casio MIDI alias is inferred. Direction changes retire both deck holds. Full modes/lifecycle, calibration and physical iPad USB/Lightning/audio/A10X acceptance remain open."
}}


def xwdj1_profiles():
    result = profile(XWDJ1_NAME, XWDJ1_SPEC)
    result.update(definition="reviewed:xwdj1-manufacturer-midi",
                  aliases=[XWDJ1_NAME, "XW-DJ1", "Casio XWDJ1", "Casio XW-DJ1 Audio out", "Casio XW-DJ1 Audio out (CoreAudio)"],
                  excludedAliases=["XW-J1", "Casio XW-J1", "Vestax Spin2", "Casio MIDI In", "Casio MIDI Out"],
                  audioOutput="masterAndHeadphones",
                  hardwareMode="Manufacturer XW-DJ1 MIDI layout with shared Shift and A/B platter selection. Both physical fader orientations are accepted. Split output uses master1/2 and headphones3/4 when this wired four-channel route is exposed.",
                  scope="Automatic41-input native core with300-count shared platter, Shift cleanup/Load/keylock/loop boundaries/browse, two fader orientations, filters, global levels and14 steady lamps. Native SET stores Cue and touch always selects scratch.",
                  gaps=["Native SET differs from CUP release-play. Shifted hot-cue deletion, fast search, separate three-slot FX, exact factory Shift semantics, direction indicators and remaining lifecycle stay open. Shared Shift cannot distinguish simultaneous physical modifiers. Hardware direction/deck selection and physical taper/calibration need acceptance. iPad USB/Lightning enumeration, power, multichannel output and sustained A10X performance remain unverified. No XW-J1 inheritance, generic Casio alias, query, mode, reset, driver or downloaded mapping code."])
    add(result, "shift", 0, 46)
    result["bankChanges"] = [dict(channel=0, number=46, onValue=127, decks=["a", "b"], releaseShiftChannels=[])]
    for channel, deck in enumerate("ab"):
        for action, number in [("play", 42), ("cuePreview", 44), ("cueSet", 43), ("sync", 45),
                               ("hotcue1", 41), ("hotcue2", 40), ("hotcue3", 39),
                               ("loopDown", 35), ("loop", 36), ("loopUp", 37)]:
            add(result, action, channel, number, deck=deck,
                feedback=action in {"play", "cuePreview", "sync", "hotcue1", "hotcue2", "hotcue3", "loop"})
            result["inputs"][-1]["shifted"] = False
        add(result, "jogTouch", channel, 59, encoding="fullVelocityGate", deck=deck)
        result["inputs"][-1]["shifted"] = False
        add(result, "jog", 2, 16 + channel, "control", "binaryOffset", deck)
        result["inputs"][-1].update(shifted=False, argument=300)
        add(result, "filterKnob", channel, 19, "control", "centreDetent", deck)
        for action, number in [("load", 42), ("keylock", 45), ("loopIn", 35), ("loopOut", 37)]:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1]["shifted"] = True
        add(result, "browse", 2, 16 + channel, "control", "binaryOffset")
        result["inputs"][-1]["shifted"] = True
    for channel in [0, 1]:
        add(result, "crossfader", channel, 16, "control")
    add(result, "master", 1, 17, "control")
    add(result, "monitor", 0, 18, "control")
    return [result]

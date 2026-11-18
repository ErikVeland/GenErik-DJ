"""Party Mix Live normal controls from its own public PCDJ script."""
from curated import add, profile
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA

LIVE_SCRIPT_SHA = "77e24d324fa9743e11efbb4ed5f858a2bacf3d3050b794bd2e3664a022fe6581"
LIVE_REFERENCES = {"Numark Party Mix Live": {
    "url": FOUR_SOURCE, "sha256": FOUR_PACKAGE_SHA,
    "archiveMember": "Applications/DEX4.app/Contents/Resources/controllers/Numark__PartyMix_Live.js",
    "memberSha256": LIVE_SCRIPT_SHA,
    "relatedSources": [{"url": "https://www.numark.com/product/party-mix-live"},
                       {"url": "https://pcdj.com/dj-controllers-numark-party-mix-live-and-numark-party-mix-ii-now-dex-3-supported/"}],
    "review": "Live-specific script by Tollen Francisco, revised13April2022, identifies USB15E4:003E. It is not a Party Mix II alias. Channels0/1 provide Play0, held Cue1, Sync2, PFL27, contact6, jogCC6, non-inverted pitchCC9 and gain/high/low/filter/levelCC23/24/25/26/28. Global channel15 provides Load2/3, Browse press7, CC0 browser and master/monitor/cue-mix/crossfaderCC10/12/13/8. Existing raw64-positive dj2go2Jog decoding exactly matches the source seven-bit jog sign rule. The source's15x jog multiplier and600 denominator are software calibration, not measured hardware counts; native calibration remains open. Browser implements the documented normal1/127 packets only; accelerated/unusual values remain inactive. Source Play/Cue lamps use127/on and1/dim-off; PFL uses NoteOff0. Sync output is an on-beat pulse in the source, so no steady Sync lamp is invented. Shared pads, mode/output ownership, held Pad Mode semantics, effects, party lights and full audio routing remain open. Transport lamp resets are reviewed; no inherited status SysEx, Pad Mode hold address or II-specific calibration is emitted. Manufacturer confirms iPadOS compatibility; direct attachment and response remain physically unverified. No downloaded code runs in the app.",
}}


def party_mix_live_profiles():
    result = profile("Numark Party Mix Live", FOUR_SOURCE)
    result["definition"] = "reviewed:numark-party-mix-live"
    result["excludedAliases"] = ["Party Mix", "Party Mix II", "Party Mix MK2", "Party Mix III", "Party Mix Pro"]
    result["scope"] = "Automatic normal transport, held Cue, fixed touch/jog, source pitch, two-band mixer/filter and normal browsing. Shared pads, calibration, full modes/lights and audio routing remain open."
    for channel, deck in enumerate("ab"):
        for action, number in [("play", 0), ("cuePreview", 1), ("sync", 2), ("cue", 27), ("jogTouch", 6)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "cuePreview", "cue"})
        add(result, "load", 15, 2 + channel, deck=deck)
        for action, number in [("gain", 23), ("high", 24), ("low", 25), ("filterKnob", 26), ("level", 28), ("tempo", 9)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "jog", channel, 6, "control", "dj2go2Jog", deck)
        result["startup"].extend([[0x90 + channel, number, 0] for number in [0, 1, 2, 7]])
    for action, number in [("crossfader", 8), ("master", 10), ("monitor", 12), ("cueMix", 13)]:
        add(result, action, 15, number, "control")
    add(result, "browse", 15, 0, "control", "signedStep")
    add(result, "openGroup", 15, 7)
    for output in result["outputs"]:
        if output["action"] in {"cueA", "cueB"}:
            output["offUsesNoteOn"] = False
        else:
            output["offValue"] = 1
    result["shutdown"] = list(result["startup"]) + [[0x80 + channel, 27, 0] for channel in range(2)]
    result["gaps"] = ["Shared pads and mode feedback need input-only mode ownership before native import. Held Pad Mode, cue deletion, Sampler/FX, party lights, on-beat Sync lamps, complete lifecycle and audio routing remain open. Browser handles1/127 only. Native jog calibration, direct iPad attachment and physical acceptance remain unverified. No Party Mix II setup, mode writes or calibration is inherited."]
    return [result]

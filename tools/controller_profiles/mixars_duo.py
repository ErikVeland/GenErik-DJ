"""DUO and DUO MKII manual performance inputs from their shared manufacturer table."""
from curated import add, profile

DUO_GUIDE = "https://mixars.com/wp-content/uploads/2017/03/mixer-duo-audio-routing-and-midi-map.pdf"
DUO_GUIDE_SHA = "003ad4931543ea1a22350690f7d155e7c3c71986f863a6b397cfa781cd6fc9e3"
DUO_REFERENCES = {name: {
    "url": DUO_GUIDE, "sha256": DUO_GUIDE_SHA,
    "relatedSources": [{"url": "https://mixars.com/product/duo-mkii/"},
                       {"url": "https://mixars.com/support-download/"}],
    "review": "Manufacturer DUO MKII product page explicitly links the same DUO Audio Routing and MIDI Map, qualifying shared wire facts for these two separately named models. PDF pages6..8 use transport channels1/2, other-function channels5/6 and global16, converted to wire0/1,4/5,15. Normal Sync is Note2 with shifted3. Loop push is other-function Note64 with shifted62. Native loop toggle uses the app's current loop size; turnCC44 direction remains unspecified and inactive. In CUE mode, four physical pads send20..23 in the first bank and24..27 in the second, with shifted releases28..35. Both banks map to native cues1..8 without guessing a software bank. Sampler mode instead sends distinct global notes33..38/46/47, which stay inactive. Global Load2/3 maps fixed A/B; Shift is global Note0. Fader-start transport Note0 is not Play and stays inactive. Mixer/PFL/relative browser/FX input and lighting remain inactive. The documented non-Serato route requires separate deck outputs into the hardware mixer, which the app does not implement. Hardware routing requires a powered setup selection; no startup query or automatic host routing is qualified. These are manual MIDI accessory subsets, not zero-config audio support. PRIMO/QUATTRO are not aliases. Complete feedback/lifecycle, driver/USB/audio qualification and physical/A10X acceptance remain open.",
} for name in ["Mixars DUO", "Mixars DUO MKII"]}


def duo_profiles():
    results = []
    for name in DUO_REFERENCES:
        result = profile(name, DUO_GUIDE)
        result.update(definition="reviewed:mixars-duo" + ("-mkii" if name.endswith("MKII") else ""),
                      role="accessory", autoSelect=False,
                      excludedAliases=["Mixars PRIMO", "Mixars QUATTRO"] + (["DUO MKII", "DUO Mk II", "DUO MK2"] if name == "Mixars DUO" else []),
                      hardwareMode="Manual MIDI accessory input. Hardware CUE mode supplies two cue banks. Separate external-deck audio routing, USB/driver behaviour and full setup remain unqualified.",
                      scope="Manual two-deck performance subset: cues1..8 across both hardware banks, Sync, native loop push and fixed A/B Load. Mixer/audio ownership, sampler/FX/relative encoders/output and physical acceptance remain open.")
        if name.endswith("MKII"): result["aliases"] += ["DUO Mk II", "Mixars DUO MK2"]
        add(result, "shift", 15, 0)
        for channel, deck in enumerate("ab"):
            for action, wire_channel, normal, shifted in [("sync", channel, 2, 3), ("loop", 4+channel, 64, 62)]:
                add(result, action, wire_channel, normal, deck=deck)
                result["inputs"][-1]["shifted"] = False
                add(result, action, wire_channel, shifted, deck=deck)
                result["inputs"][-1].update(releaseOnly=True, shifted=True)
            for slot in range(8):
                add(result, f"hotcue{slot+1}", 4+channel, 20+slot, deck=deck)
                result["inputs"][-1]["shifted"] = False
                add(result, f"hotcue{slot+1}", 4+channel, 28+slot, deck=deck)
                result["inputs"][-1].update(releaseOnly=True, shifted=True)
            add(result, "load", 15, 2+channel, deck=deck)
            result["inputs"][-1]["shifted"] = False
        result["gaps"] = ["Manual performance inputs only. Non-Serato operation requires external hardware mixing with separate deck audio outputs, which the app does not provide. Input/output USB/driver qualification, cold routing discovery, hardware mixer/PFL ownership, relative loop/browser values, sampler/FX/fader-start semantics, lighting, complete lifecycle and physical/A10X acceptance remain open. Fader-start Note0 is not a Play command. No PRIMO or QUATTRO protocol is inferred."]
        results.append(result)
    return results

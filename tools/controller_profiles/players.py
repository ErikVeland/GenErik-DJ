"""Reviewed factory MIDI facts for XDJ and earlier CDJ players."""
from curated import add, profile

PLAYER_REFERENCES = {
    "Pioneer XDJ-1000MK2": {
        "url": "https://downloads.support.alphatheta.com/manuals/dj-players/XDJ-1000MK2/XDJ-1000MK2_DRI1396B_manual.pdf",
        "sha256": "631f9aefb8656a07be4421de2a757b21d4d0ef8e2655a71554e6ea8a45a70e5c", "pages": [38]},
    "Pioneer XDJ-700": {
        "url": "https://manualsfile.com/product/zq8xt8y56.html",
        "sha256": None, "pages": [33, 34], "review": "Factory operating manual, web text. PDF download unavailable."},
    "Pioneer XDJ-1000": {
        "url": "https://www.allfordj.ru/upload/iblock/e25/rukovodstvo_polzovatelya_pioneer_xdj_1000_usb.pdf",
        "sha256": "795f31b1ce2811102783cc70c56702627f1dfed056651ddea6dfce7ecc6320af", "pages": [32, 33]},
    "Pioneer CDJ-2000": {
        "url": "https://www.av-projektering.se/av_projektering/pdf/CDJ2000manual.pdf",
        "sha256": "279e967f31fcdc97819cdaf36aaf41bf449a60ad59ddaa512e1d6d7034ef6507", "pages": [27]},
    "Pioneer CDJ-900": {
        "url": "https://c7.zzounds.com/media/CDJ-900_OperatingInstructions1006-5d13ba1bdb7b74a71c99d9e7e959040f.pdf",
        "sha256": None, "pages": [26], "review": "Factory operating manual, web text. Local download unavailable."},
    "Pioneer CDJ-850": {
        "url": "https://media.djmania.net/manuales/pdf/Manual_Pioneer_CDJ_850_Negro_.pdf",
        "sha256": "d9924c7447e9e80b6975f407f8b5a41d0044f93d6df8b60788c3c46f7541f847", "pages": [26]},
    "Pioneer CDJ-350": {
        "url": "https://luxpro.ua/files/2ae4e956d41c7e1c858901fc1dfac1ca.pdf",
        "sha256": "41b4b040c3808488ba1200b613bdd89e4651158db8455a03525427b2b7b4d33b", "pages": [25]},
    "Pioneer CDJ-400": {
        "url": "https://www.m3-eventtechnik.at/sites/default/files/dateien/verleih/cdj-400_manual_en_fr_de_nl_it_es_rupdf.pdf",
        "sha256": "f29767dae3b3cdacddfba91e26ac3d757924852e2834a676d813a6ab2fcd994e", "pages": [20],
        "compatibilitySources": ["https://jpn.pioneer/ja/support/download/dj-e/cdj-400/firm_download.html"]},
    "Pioneer CDJ-TOUR1": {
        "url": "https://www.l-e.sk/amfile/file/download/file/7038/product/14628/",
        "sha256": "40141248633d64b0bcb1eb68716c55ecea30535457df1d0787ede7fe7987fbe6", "pages": [45]},
}
PLAYER_PRIORITY = list(PLAYER_REFERENCES)


def player_profiles():
    results = []
    for name, source in PLAYER_REFERENCES.items():
        result = profile(name, source["url"])
        result.update(role="player", scope="Automatic player controls in PC / USB-MIDI mode. HID, lights and audio routing remain open.")
        xdj = "XDJ-" in name
        mk2 = name.endswith("1000MK2")
        cdj350 = name.endswith("CDJ-350")
        cdj400 = name.endswith("CDJ-400")
        if cdj400:
            result["aliases"].extend(["CDJ-400-K", "Pioneer CDJ-400-K", "Pioneer DJ CDJ-400-K"])
        tour = name.endswith("TOUR1")
        result["hardwareMode"] = "Control Mode / USB-MIDI" if xdj or tour or name.endswith(("CDJ-2000", "CDJ-900")) else "PC / USB-MIDI"
        for action, address in [("play", 0), ("cuePreview", 1), ("keylock", 0x11), ("jogTouch", 0x20),
                                ("loopIn", 6), ("loopOut", 7), ("reloopOriginal" if cdj400 else "reloop", 8), ("load", 0x33)]:
            add(result, action, 0, address, deck="a")
        add(result, "openGroup", 0, 0x32)
        add(result, "tempo", 0, 0x1D, "control", "cdjTempo", "a")
        add(result, "jog", 0, 0x10, "control", "cdj350PlatterSpeed" if cdj350 else "cdjPlatterSpeed", "a")
        add(result, "wheelJog", 0, 0x30, "control", "cdjRingSpeed", "a")
        add(result, "browse", 0, 0x4F, "control", "binaryOffset" if cdj400 else "twosComplement")
        if xdj or tour:
            add(result, "sync", 0, 0x1F, deck="a")
        if cdj350:
            add(result, "sync", 0, 0x26, deck="a")
        if xdj or tour or name.endswith("CDJ-2000"):
            add(result, "seek", 0, 0x1C, "control", "needlePosition", "a")
            pads = [0x18, 0x19, 0x1A, 0x1B, 0x14, 0x15, 0x16, 0x17] if mk2 or tour else [0x18, 0x19, 0x1A]
            for slot, address in enumerate(pads):
                add(result, f"hotcue{slot + 1}", 0, address, deck="a")
        if name.endswith("CDJ-2000"):
            add(result, "tempoReset", 0, 0x1D, deck="a")
        if tour:
            add(result, "tempoReset", 0, 0x0F, deck="a")
        if cdj350 or cdj400:
            add(result, "loopRestore", 0, 0x16, deck="a")
            add(result, "loopDivide", 0, 0x17, deck="a")
        loops = ([0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8, 16, 32] if tour else
                 [0.5, 1, 2, 4, 8, 16] if xdj else [4] if name.endswith("CDJ-2000")
                 else [1, 2, 4, 8] if not (cdj350 or cdj400) else [])
        loop_start = 0x24 if tour else 0x27 if xdj else 0x2A if name.endswith("CDJ-2000") else 0x28
        for slot, beats in enumerate(loops):
            add(result, "fixedLoop", 0, loop_start + slot, deck="a")
            result["inputs"][-1]["argument"] = beats
        jumps = []
        if mk2:
            jumps = [(0x38, 1), (0x39, -1)]
            for slot, beats in enumerate([2, 4, 8, 16, 32]):
                jumps.extend([(0x3C + slot * 2, beats), (0x3D + slot * 2, -beats)])
        elif name.endswith("XDJ-1000"):
            jumps = [(0x38, 1), (0x39, 2), (0x3A, 4), (0x3B, -1), (0x3C, -2), (0x3D, -4)]
        elif tour:
            add(result, "jumpForward", 0, 0x38, deck="a")
            add(result, "jumpBack", 0, 0x39, deck="a")
        for address, beats in jumps:
            add(result, "fixedJump", 0, address, deck="a")
            result["inputs"][-1]["argument"] = beats
        for binding in result["inputs"]:
            binding["anyChannel"] = True
        results.append(result)
    return results

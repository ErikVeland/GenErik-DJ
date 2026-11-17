"""Manual original i-Mix Reload source variant with note-encoded wheel movement."""
from curated import add, profile
from numark import UPSTREAM

IMIX_SOURCES = [
    ("DJ-Tech i-Mix Reload.midi.xml", "f036d54b4ce670f40ef6e4f91ef47c899a9160e9bcf9677f69e772094f731b39"),
    ("DJ-Tech-i-Mix-Reload-scripts.js", "7a25b07233c2eba9ca667e1ec51510dd9635fcfde7bdd4c890c1cd4f29ee59d8"),
]
IMIX_MANUAL = "https://asset.conrad.com/media10/add/160267/c1/-/gl/000060106ML01/mode-demploi-060106-console-de-mixage-mp3-dj-tech-imix-reload.pdf"
IMIX_REFERENCES = {"DJ-Tech i-Mix Reload": {
    "url": UPSTREAM + IMIX_SOURCES[0][0].replace(" ", "%20"), "sha256": IMIX_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in IMIX_SOURCES]
        + [{"url": IMIX_MANUAL, "sha256": "1a5ad646cff8bd310d470f750d8df33aa382bca165bca589831d032caa2ae166", "pages": [10, 11]}],
    "review": "Manual pinned-source variant only. Source touch50/49 and Load40/46 conflict with the factory chart's touch/Load rows; its header also omits keys44/45 and duplicates a hot-cue/kill address. Automatic identity/variant selection remains unqualified. Source148-count scratch uses direction notes96/97 and98/99, with strict positive Note-On steps and physical-touch gating. Note-Off, zero velocity, malformed/expanded values and foreign kinds cannot move the platter; source handler counts every callback, which is not copied. Factory encoder table corroborates normal unheld CW/CCW114/115 and118/119; native wheel nudge/paused seek uses the same148-count encoder scale, while Search112/113 and116/117 remain inactive. Factory labels and source dictionary corroborate Sync5/35 and Loop1/25; native loop-size buttons follow physical minus/plus rather than source manual In/Out remaps. Side Set guards cues without importing deletion. Native held Cue, wheel bend, three cues, gain/EQ/level, inverse tempo, direct source-variant Load and explicit browser step buttons retain wire facts. Factory centre-control CCs, source timers/debug prints, first-stopped Load, held Search, downbeat, EQ kills, FX, full feedback/cleanup and acceptance remain open. No audio interface is inferred. Lifecycle messages are bounded but the existing manual-apply path does not run automatic setup/shutdown.",
}}


def imix_profiles():
    result = profile("DJ-Tech i-Mix Reload", IMIX_REFERENCES["DJ-Tech i-Mix Reload"]["url"])
    result["autoSelect"] = False
    result["excludedAliases"] = ["DJ-Tech i-Mix Reload MKII", "i-Mix Reload MKII", "DJ-Tech i-Mix Reload MK2"]
    result["hardwareMode"] = "Manual pinned Mixxx variant: touch50/49 and Load40/46. Factory chart conflicts remain unresolved."
    result["scope"] = "Manual source-variant core with strict note-step wheel counts, held Cue, native wheel bend/loops/mixer, three cues and direct Load. Automatic variant selection, Search, first-stopped Load, full modes/feedback/lifecycle and physical acceptance remain open."
    result["gaps"] = ["Factory chart and pinned source disagree on touch and Load addresses. Automatic variant selection is not implemented. Manual apply does not run automatic lifecycle. Search mode, first-stopped Load, downbeat, EQ kill, FX, full feedback/reset, centre CC qualification and physical acceptance remain open."]
    for side, deck in enumerate("ab"):
        add(result, "shift", 0, 2 if side == 0 else 26)
        result["inputs"][-1].update(shiftChannel=side, shiftInput=side)
        for action, numbers in [("play", [17, 47]), ("cuePreview", [11, 41]), ("sync", [5, 35]),
                                ("keylock", [3, 45]), ("cue", [21, 27]), ("load", [40, 46]),
                                ("loop", [1, 25]), ("loopDown", [7, 31]), ("loopUp", [13, 37]),
                                ("reloop", [19, 43])]:
            add(result, action, 0, numbers[side], deck=deck,
                feedback=action in {"play", "cuePreview", "sync", "cue", "loop"})
        add(result, "jogTouch", 0, 50 - side, deck=deck)
        for action, numbers, touch in [("jog", [96 + side * 2, 97 + side * 2], True),
                                        ("wheelJog", [114 + side * 4, 115 + side * 4], False)]:
            for direction, number in enumerate(numbers):
                add(result, action, 0, number, "note", "noteStep", deck)
                result["inputs"][-1].update(argument=148, inverted=direction == 1)
                if touch:
                    result["inputs"][-1]["requiresTouch"] = True
        for action, numbers in [("tempo", [69, 75]), ("gain", [71, 81]), ("high", [78, 80]),
                                ("mid", [79, 72]), ("low", [77, 82]), ("level", [67, 66])]:
            add(result, action, 0, numbers[side], "control", "centreDetent" if action in {"tempo", "high", "mid", "low"} else "absolute", deck)
            if action == "tempo":
                result["inputs"][-1]["inverted"] = True
        for slot, number in enumerate([[8, 14, 20], [32, 38, 44]][side], 1):
            add(result, f"hotcue{slot}", 0, number, deck=deck, feedback=True)
            result["inputs"][-1].update(shifted=False, shiftChannel=side)
    for action, number in [("crossfader", 65), ("monitor", 73), ("cueMix", 74)]:
        add(result, action, 0, number, "control")
    add(result, "browseNext", 0, 100)
    add(result, "browsePrevious", 0, 101)
    numbers = [4, 10, 16, 22, 8, 14, 20, 1, 7, 13, 19, 12, 5, 11, 17, 23,
               21, 27, 28, 34, 24, 30, 18, 36, 32, 38, 44, 25, 31, 37, 43, 42, 29, 35, 41, 47]
    result["startup"] = [[0x90, number, 0] for number in numbers]
    result["shutdown"] = [[0x90, row["number"], 0] for row in result["outputs"]] + [[0x90, number, 0] for number in [12, 42]]
    return [result]

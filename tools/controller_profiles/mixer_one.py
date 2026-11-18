"""Mixer One four-target controls from the pinned published preset."""
from curated import add, profile
from numark import UPSTREAM

MIXER_ONE_SOURCES = [
    ("DJ-Tech Mixer One.midi.xml", "c895e5904a8de34494f2b74cbeca06fbd835c879683d968cc150b485331ccbc8"),
    ("DJ-Tech-Mixer-One-scripts.js", "5a08166293187281e59bcea4cf646f6d987a107c0c17d9ee754089420e964b21"),
]
MIXER_ONE_REFERENCES = {"DJ-Tech Mixer One": {
    "url": UPSTREAM + MIXER_ONE_SOURCES[0][0].replace(" ", "%20"), "sha256": MIXER_ONE_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in MIXER_ONE_SOURCES],
    "review": "Published XML gives four explicit mixer targets on wire channels 5,6,7,8, with different address sets on each physical side. Global controls are duplicated only on channels 5 and 7. Native pickup protects levels and EQ. Published Clear Meter events rearm pickup without guessing a target from bank state. PFL feedback follows XML. Startup clears twelve unsupported EQ-kill indicators and eight source meter addresses; shutdown clears declared PFL and meter outputs. Total lifecycle packets are exactly 32. Meters are not mapped to fader positions. Source master-mute restore, crossfader curve/balance, EQ-kill controls, live VU feedback, routing and physical acceptance remain open.",
}}


def mixer_one_profiles():
    result = profile("DJ-Tech Mixer One", MIXER_ONE_REFERENCES["DJ-Tech Mixer One"]["url"])
    result["aliases"].append("MIXER1")
    result.update(role="accessory", scope="Automatic four-target MIDI mixer core with explicit side-specific gain/EQ/level/PFL, duplicated global strip, pickup and bounded indicator cleanup. C/D retain app availability limits. EQ kill, inverse mute, crossfader curve/balance, live meters, routing and physical acceptance remain open.")
    meters = [[0xB5, 31, 0], [0xB7, 31, 0], [0xB5, 32, 0], [0xB7, 32, 0],
              [0xB5, 34, 0], [0xB6, 35, 0], [0xB7, 34, 0], [0xB8, 35, 0]]
    result["bankChanges"] = [{"channel": channel, "number": 10, "onValue": 127, "decks": list("abcd")} for channel in [5, 7]]
    for channel, deck in [(5, "a"), (6, "b"), (7, "c"), (8, "d")]:
        left = channel in {5, 7}
        base = 16 if left else 21
        for offset, action in enumerate(["gain", "high", "mid", "low", "level"]):
            add(result, action, channel, base + offset, "control", deck=deck)
        add(result, "cue", channel, 7 if left else 3, deck=deck, feedback=True)
        result["startup"].extend([[0x90 + channel, number, 0] for number in ([8, 9, 6] if left else [4, 1, 2])])
    for channel in [5, 7]:
        for action, number in [("master", 11), ("monitor", 12), ("cueMix", 13), ("crossfader", 15)]:
            add(result, action, channel, number, "control")
    result["startup"].extend(meters)
    result["shutdown"] = meters + [[0x90 + output["channel"], output["number"], 0] for output in result["outputs"]]
    return [result]

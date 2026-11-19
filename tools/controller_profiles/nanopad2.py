"""nanoPAD2 native pads and source scene layout, independent of nanoKONTROL2."""
from curated import add, profile
from numark import UPSTREAM

PAD2_NAME="Korg nanoPAD2"
PAD2_SPEC="https://cdn.korg.com/us/support/download/files/49d826be0eaf963049124b70d8f233c0.txt"
PAD2_SPEC_SHA="5da281ab089eff3d2720cdad1154110ef2196556f9c1728b5a58269fec5039b8"
PAD2_SOURCES=[
    ("Korg nanoPAD2.midi.xml","fc949b9470100c6c712ce363ea6a10096b4c12d4f2c64445111c22a2a0f0ffef"),
    ("Korg-nanoPAD2-scripts.js","2bd5b933ef595b8b641c735b9564e771ad1e4716550f6a74e2e819d1cbd06f92"),
]
PAD2_REFERENCES={PAD2_NAME:{
    "url":PAD2_SPEC,"sha256":PAD2_SPEC_SHA,
    "relatedSources":[{"url":UPSTREAM+name.replace(" ","%20"),"sha256":digest} for name,digest in PAD2_SOURCES]+[
        {"url":"https://www.korg.com/us/support/download/manual/0/158/2711/"}],
    "review":"Independent Korg native project12/family12/01 uses the same search/native-mode framing but different controls from nanoKONTROL2. Native pads send channel2 Notes64..79, Note Off velocity64; Scene sends channel16 CC57 on127/off0. Only the matching project/channel acknowledgement enables input. Host Scene LEDs use channel16 CC121..124, on127/off0. Native software Scene starts0 and cycles on fresh Scene presses. Upstream source layout maps physical indices to original notes36+16*scene+index: first-bank odd pads are A cues1..8, even pads B cues1..7 and pad14 is held Clear. Second-bank cues9..16 exceed the app's eight slots and remain inactive except its Clear guard. Third-bank reviewed inputs are fixed1/2/4 loops, halve/double and loop boundaries. Resize is blocked while a source loop/reloop pad is held, because the source then moves the loop instead. Timed reloop tap/hold remains inactive. Fourth-bank mute/kills/reverse/one-shot sync/FX and XY/touch-scale remain inactive. Pad releases retain original scene addresses across Scene changes; source-owned cleanup preserves held Clear. Dynamic Scene lamps and all setup requests use the paired physical output and fail closed on send failure. No scene dump/write/reset or persistent programming is sent. Saved scenes and original nanoPAD/nanoKONTROL protocols are not inherited. Full later cues/modes, timeout/recovery/lifecycle and physical/A10X acceptance remain open.",
}}


def nanopad2_profiles():
    result=profile(PAD2_NAME,PAD2_SPEC)
    result.update(definition="reviewed:nanopad2-native-scenes",role="accessory",inputProtocol="nanoPad2Native",
                  aliases=[PAD2_NAME,"nanoPAD2","nanoPAD2 PAD","nanoPAD2 1 PAD","nanoPAD2 CTRL","nanoPAD2 1 CTRL"],
                  excludedAliases=["nanoPAD","nanoKONTROL2","nanoKEY2","padKONTROL"],
                  hardwareMode="Automatic acknowledged native KORG mode through a paired output. Native Scene cycles the source's four software banks, starting first-bank cues. Unsupported banks/slots remain inactive. Saved scene data stays unchanged.",
                  scope="Automatic native first-bank cues/Clear guards and reviewed third-bank loops, with scene lights and original release ownership. Later cue slots, other modes, full lifecycle and physical acceptance remain open.")
    result["startup"]=[[0xF0,0x42,0x50,0,0x2D,0xF7]]
    for number in [50,66]:
        add(result,"shift",0,number)
        result["inputs"][-1]["shiftInput"]=0
    for index in range(16):
        if index==14: continue
        deck="a" if index%2 else "b"
        add(result,f"hotcue{index//2+1}",0,36+index,deck=deck)
        result["inputs"][-1]["shifted"]=False
    for deck,offset in [("b",0),("a",1)]:
        for action,number in [("loopDown",68+offset),("loopUp",76+offset),("loopIn",78+offset),("loopOut",80+offset)]:
            add(result,action,0,number,deck=deck)
            result["inputs"][-1]["shifted"]=False
        for number,beats in [(70+offset,1),(72+offset,2),(74+offset,4)]:
            add(result,"fixedLoop",0,number,deck=deck)
            result["inputs"][-1].update(argument=beats,shifted=False)
    result["gaps"]=["First-bank15 cues, held Clear guards and third-bank14 loop controls only. Cue deletion, later cue slots9..16, held loop moves, timed reloop, fourth-bank mute/kills/reverse/one-shot sync/FX, XY/touch-scale, reply timeout/recovery and complete lifecycle remain open. Native Scene lamps are dynamic; no pad lights are inferred. No saved scene write/reset, original nanoPAD alias or audio interface is inferred. Physical/A10X acceptance remains open."]
    return [result]

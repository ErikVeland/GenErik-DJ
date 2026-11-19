"""Manual SP-404MKII DJ-mode CC subset from the manufacturer's current chart."""
from curated import add, profile

SP404_NAME="Roland SP-404MKII"
SP404_MANUAL="https://static.roland.com/assets/media/pdf/SP-404mk2_v550_reference_eng04_W.pdf"
SP404_SHA="ab7635f6bf4c702d21e03d4379dddd8e5ecfc64735d40990620f8e7a699c3dbd"
SP404_REFERENCES={SP404_NAME:{
    "url":SP404_MANUAL,"sha256":SP404_SHA,
    "relatedSources":[{"url":"https://static.roland.com/assets/media/pdf/SP-404MK2_v4_reference_eng02_W.pdf","sha256":"db784ba6a66b62616114fb0fd14e5904d7bf1230a5ade74091046fd0f5245977"},
                      {"url":"https://static.roland.com/manuals/sp-404mk2_serato_dj/en-US/297025419301529355.html"}],
    "review":"Manufacturer version5.50 reference, MIDI chart version5 dated2025-07-01, pages167-169. Independently agrees with version4's pages268-270. Ordinary DJ mode sends channel0/1 CC7 for A/B level, CC22 for explicit Sync state, CC23 for explicit headphone Cue state, CC24/25 for held pitch bends, and channel0 CC8 for crossfader. CC8 explicitly ranges from CH1:CH2=127:0 to0:127, so native polarity is unchanged. Direct Sync state sets the saved choice instead of toggling it and bypasses pickup just like direct PFL/keylock state. No invented LED output: the chart marksCC20-27 receive unsupported. PlayCC20 is state-valued, with an inconsistent01 example versus127 in the detailed table; native toggle Play must not consume it. Return-to-sample-start21 and BPM step26/27 stay inactive rather than substituting a different Cue or percentage step. Pattern-sequencer channel2, sample/Chromatic note banks, FX/looper CCs and MIDI clock do not control app decks. Standalone DJ mode and the version5 Serato-control screen are separate modes. The latter auto-connects in Serato through an unpublished host handshake, not this ordinary CC contract. Native profile selection remains manual with separate audio. No stored setting, firmware, mode-write or setup/output packet is sent. Full native Play-state, modes/output/lifecycle/audio and physical/A10X acceptance remain open.",
}}


def sp404_profiles():
    result=profile(SP404_NAME,SP404_MANUAL)
    result.update(definition="manufacturer:sp404mk2-dj-cc",role="accessory",autoSelect=False,
                  aliases=[SP404_NAME,"SP-404MKII","SP-404MK2"],excludedAliases=["SP-404","SP-404SX","SP-404A"],
                  hardwareMode="Manual ordinary DJ mode, with separate app audio. Serato control mode and sample/Looper/Chromatic modes are not this MIDI contract.",
                  scope="Manual two-deck levels, explicit Sync/PFL states, held pitch bends and crossfader. Native Play state, Serato handshake, other modes/output/lifecycle/audio and physical acceptance remain open.")
    for channel,deck in enumerate("ab"):
        for action,number in [("level",7),("syncState",22),("cueState",23),("pitchBendUp",24),("pitchBendDown",25)]:
            add(result,action,channel,number,"control",deck=deck)
    add(result,"crossfader",0,8,"control")
    result["gaps"]=["Manual ordinary DJ mode with separate audio only. Native Play-state/return-to-start/BPM-step semantics, proprietary Serato mode handshake, sample/Chromatic/FX/Looper modes, full setup/output/lifecycle/audio and physical/A10X acceptance remain open. No stored setting, MIDI clock, firmware or output command is sent."]
    return [result]

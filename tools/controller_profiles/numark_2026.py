"""Separate fixed input cores from pinned 2026 Numark public mappings."""
from curated import add, profile

NUMARK_2026_FILES=[
    ("mixtrack-go.xml","7f6eeba6d8acc9170262abade6df980a8d781b88eb2aaa669f48e5beff02fb96"),
    ("mixtrack-go.js","a129618747420e27267835166bd44a2d6b422b3ea8c2c3bf62ce0a05c2abfcd0"),
    ("mixtrack-go-README.md","1da5c0ed0765d5694f44f8ad0dca6570d219ebd8db7332db10b74d2d76c7abd1"),
    ("mixtrack-go-guide.md","71c5ff901df9d797c185fbe07df85155cb1b017a46f0045a0a420c0b360f411c"),
    ("party3.xml","21ed2eff0b2b84850dfe275aef48c7fffd3504973d1b2cec3e28d56abd99a7d7"),
    ("party3.js","0b6e592f9d21a8293562debfd4ae0e2d1c8c62ea62202130046a8bc1a24d6008"),
    ("party3-README.md","50c0f6bdd46b34f2d6f8fb2b8980e115170718beec80cf9abe22bc911c1b92c0"),
]
NUMARK_2026_MODELS=[
    ("Numark MixTrack Go","josefveiga/Numark-Mixtrack-Go-mapping-for-Mixxx","97296b1cf0d8427963c6c96eac6f48dece86224e","Numark-Mixtrack-Go",0),
    ("Numark Party Mix III","stefets/numark-party-mix-III-mixxx-mapping","7eb1c4a2a7cfe4a709485ab3e46444e98d8f6e08","NumarkPartyMixIII",4),
]
NUMARK_2026_REFERENCES={}
for name,repo,revision,stem,offset in NUMARK_2026_MODELS:
    go=offset==0
    base="https://raw.githubusercontent.com/"+repo+"/"+revision+"/"
    xml=stem+".midi.xml";script=stem+".scripts.js"
    NUMARK_2026_REFERENCES[name]={
        "url":base+xml,"sha256":NUMARK_2026_FILES[offset][1],"revision":revision,
        "relatedSources":[{"url":base+script,"sha256":NUMARK_2026_FILES[offset+1][1]},
                          {"url":base+"README.md","sha256":NUMARK_2026_FILES[offset+2][1]},
                          {"url":"https://support.numark.com/en/support/solutions/articles/"+("69000880702-numark-mixtrack-go-frequently-asked-questions" if go else "69000880584-party-mix-iii-frequently-asked-questions")}],
        "review":"Independent pinned model-specific XML and script. Fixed Play0 and held Cue1 use deck channels0/1; Load is global channel15 Note2/3. LevelCC22, filterCC26, paired tempoMSB9/LSB41 and global MasterCC10/headphone12/crossfader8/browserCC0 agree within this model's wiring. Tempo handler explicitly inverts the14-bit value. Native paired normalisation is bounded0..1; exact source8192-centre calibration remains open. Browser127 is-1 and1 is+1. Identity request and source controller-status query are transient startup only. No delayed lamps are sent. "+(
            "Go additionally wires Sync2/PFL27, physical touch80 and wheelCC6. Fixed native touch scratch uses the author's approximate242-count revolution estimate. Source paused scrub multipliers and software Vinyl/Low/Filter modes are not inherited. Normal Play/Cue/Sync/PFL/Load shifted release addresses4/5/3/84/72-or73 rearm only. " if go else
            "Party Mix III separately wires HighCC23/Mid24/Low25. Its XML omits the copied script's Sync/PFL/jog handlers. Do not expose those unwired fields or the ambiguous second volumeCC28. Its right mode constant incorrectly names a jog address and shared-pad implementation disagrees with direct XML cue rows, so all pad/mode traffic stays inactive. Normal Play/Cue/Load shifted release addresses4/5/72-or73 rearm only. ")+
        "No shared pad modes, Fade FX, stems, shifted destructive actions or display protocol is inferred. Native filter is fixed, not the source's configurable QuickEffect. Both public setup guides describe wired Main1/2 and headphones3/4, while manufacturer Bluetooth MIDI disables controller audio outputs. No automatic audio route or Bluetooth setup is claimed. Full modes/output/setup/lifecycle/audio, direct iPad transport and physical/A10X acceptance remain open. Downloaded code never executes.",
    }


def numark_2026_profiles():
    results=[]
    for name,_,_,_,offset in NUMARK_2026_MODELS:
        go=offset==0
        short=name.removeprefix("Numark ")
        result=profile(name,NUMARK_2026_REFERENCES[name]["url"])
        result.update(definition="reviewed:numark-2026-"+("mixtrack-go" if go else "party-mix-iii"),
                      aliases=[name,short,name+" MIDI 1",short+" MIDI 1"],
                      excludedAliases=[x for x in ["MixTrack Go","Party Mix III","Party Mix II","Party Mix Live","Party Mix Pro","Mixtrack Pro","DJ2GO2 Touch"] if x!=short],
                      hardwareMode="Automatic fixed normal "+short+" input core. Shared pad/FX modes stay inactive. USB and Bluetooth audio require separate setup; Bluetooth MIDI disables controller audio outputs.",
                      scope="Automatic normal A/B Play/held Cue/Load, fixed mixer/filter, inverted paired tempo and browser. "+("Source-valued fixed touch/jog, Sync and PFL. " if go else "Independent three-band EQ. ")+"Full modes/output/lifecycle/audio and physical acceptance remain open.")
        result["startup"]=[[0xF0,0x7E,0x7F,0x06,0x01,0xF7],[0xF0,0x00,0x20,0x7F,0x03,0x01,0xF7]]
        for channel,deck in enumerate("ab"):
            buttons=[("play",0,4),("cuePreview",1,5),("load",2+channel,72+channel)]
            if go:buttons += [("sync",2,3),("cue",27,84)]
            for action,number,release in buttons:
                wire=15 if action=="load" else channel
                add(result,action,wire,number,deck=deck)
                add(result,action,wire,release,deck=deck)
                result["inputs"][-1].update(shifted=True,releaseOnly=True)
            add(result,"tempo",channel,9,"control","paired14Bit",deck)
            result["inputs"][-1].update(lowNumber=41,inverted=True)
            add(result,"level",channel,22,"control",deck=deck)
            add(result,"filterKnob",channel,26,"control",deck=deck)
            if go:
                add(result,"jogTouch",channel,80,deck=deck)
                add(result,"jog",channel,6,"control","twosComplement",deck)
                result["inputs"][-1]["argument"]=242
            else:
                for action,number in [("high",23),("mid",24),("low",25)]:
                    add(result,action,channel,number,"control",deck=deck)
        for action,number in [("master",10),("monitor",12),("crossfader",8)]:add(result,action,15,number,"control")
        add(result,"browse",15,0,"control","twosComplement")
        result["gaps"]=["Only independently wired fixed normal "+short+" inputs. "+("Approximate242-count jog estimate and native fixed touch; exact source pitch centre and paused-scrub scaling remain unqualified. " if go else "Prototype's unwired Sync/PFL/jog, ambiguous volume28, copied mode/pad constants and source pitch-centre calibration stay inactive. ")+"Shared pad/FX/stems modes, lamps/timing, complete setup/lifecycle, USB-versus-Bluetooth audio and physical/A10X acceptance remain open. No stored setting, firmware, reset, automatic audio route or sibling protocol is inferred."]
        results.append(result)
    return results

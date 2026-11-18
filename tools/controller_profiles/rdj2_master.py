"""Master Edition controls from its independent manufacturer MIDI appendix."""
from copy import deepcopy
from curated import add, profile

MASTER_MANUAL="https://www.billebro.se/proddoc/PRID_5035_doc_223368_RELOOP_IM.pdf"
MASTER_SHA="5982082ed92efc88e4145e53d74f65d64b24a4e15de06d2b5cbdf27bc1f36cdb"
MASTER_NAME="Reloop Digital Jockey 2 Master Edition"
MASTER_REFERENCES={MASTER_NAME:{
    "url":MASTER_MANUAL,"sha256":MASTER_SHA,
    "relatedSources":[{"url":"https://www.reloop.com/reloop-digital-jockey-2-master-edition"},
                      {"url":"https://manual.mixxx.org/2.5/en/hardware/controllers/reloop_digital_jockey_2_master_edition"}],
    "review":"Independent manufacturer manual, English pages24-30. Appendix29/30 includes USB-MIDI CIN bytes09/0B/0E before ordinary MIDI status; these are not extra MIDI data. Normal controls use channel0 and a60-note right offset. Physical Shift notes0A/46 guard ordinary controls, with same-address release-only aliases for rearming and native held Cue/bend release ownership. No undocumented shifted address is invented. B14 independently identifies PREVIEW05/41 as normal deck headphone cue; main held Cue is18/54. TraxCC13 uses41++/3F--, exactly binary-offset64. Trax press enters a desktop browse/jog mode and stays inactive. B25 describes Loop Active as a display, so its ambiguous input remains inactive. Auto Loop enables the current native loop; In/Out retain native loop endpoints without claiming the manual's extra Reloop/reloop behaviour. Separate mixer/global CCs retain their exact meaning. Chapter6 requires front MIDI selection for software operation. The primary Mixxx guide explicitly says this model is not USB MIDI class compliant and requires a Windows/macOS translation driver. Manual MIDI through that driver or an external bridge is theoretical input coverage, not native iPad USB access. No Interface Edition jog sensitivity, pitch polarity, shifted layers, filters, LED values or lifecycle messages are inherited. Full driver/bridge, software/hardware audio ownership, modes/output/lifecycle and physical acceptance remain open.",
}}


def rdj2_master_profiles():
    result=profile(MASTER_NAME,MASTER_MANUAL)
    result.update(definition="manufacturer:rdj2-master-normal",autoSelect=False,
                  excludedAliases=["Reloop Digital Jockey 2 Interface Edition","Reloop Digital Jockey 2 Controller Edition","DIGITALJOCKEY2"],
                  hardwareMode="Manual Master Edition driver-translated MIDI or external bridge only. Select MIDI on both front channel selectors. Native iPad USB access and audio routing remain unresolved.",
                  scope="Manual normal A/B transport, held Cue/bends, native loop endpoints/enable, fixed mixer/PFL, master/headphone blend/level and source-valued Browse. Full modes, native USB driver, output/lifecycle/audio and physical acceptance remain open.")
    for side,deck in enumerate("ab"):
        base=60*side
        add(result,"shift",0,base+10)
        result["inputs"][-1]["shiftInput"]=side
        for action,number in [("play",25),("cuePreview",24),("sync",1),("keylock",2),("cue",5),("load",19),
                              ("pitchBendDown",3),("pitchBendUp",4),("loopIn",15),("loopOut",16),("loopEnable",17)]:
            add(result,action,0,base+number,deck=deck)
            result["inputs"][-1]["shifted"]=False
            if action not in {"cuePreview","pitchBendDown","pitchBendUp"}:
                release=deepcopy(result["inputs"][-1]);release.update(shifted=True,releaseOnly=True)
                result["inputs"].append(release)
        for action,number in [("gain",2),("high",3),("mid",4),("low",5),("level",6)]:
            add(result,action,0,base+number,"control",deck=deck)
            result["inputs"][-1]["shifted"]=False
    for action,number in [("master",15),("monitor",16),("cueMix",17),("crossfader",18)]:
        add(result,action,0,number,"control")
    add(result,"browse",0,19,"control","binaryOffset")
    result["inputs"][-1]["shifted"]=False
    result["gaps"]=["Manual desktop-driver or bridge MIDI only; this model is not USB MIDI class compliant. Front channel selectors require MIDI. Native iPad access, driver/bridge discovery, full shifted/jog/FX modes, pitch polarity/calibration, output/setup/lifecycle/audio and physical/A10X acceptance remain open. No Interface Edition protocol, stored setting or output command is inferred."]
    return [result]

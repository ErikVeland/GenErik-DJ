"""Original Audiophony PLAY manufacturer note facts, without bank inference."""
from curated import add, profile

PLAY_SOURCE='https://www.audiophony.com/downloads/m9280.pdf'
PLAY_SHA='8ebb89aad5920699bd356f931c7e22dfce0f6818e95eafc7fb79fa8d97af147c'

PLAY_REVIEW='Own VIRTUALITY-PLAY manufacturer guide9280 v1 June2008, MIDI diagram p11 visually reviewed. Grey circles explicitly identify decimal MIDI Notes, distinct from outlined CC circles. Play53, main Cue52, Key/Master Tone29, In38, Out/Exit37, Reloop36 and bend-/+33/32 are unambiguous. START CUE51 is a different button and is not held Cue. Manual source menu p10 distinguishes HID and MIDI; select MIDI and remain on hardware DECK A. RELAY changes hardware A/B and a long press exits MIDI. The chart does not qualify channel/bank encoding or RELAY47/56 state meanings. Manual single-player A only accepts the unspecified channel through the existing bounded player contract; selector wires only retire its own source holds. They do not switch native decks. No default channel, automatic identity, protocol-equivalent CDMP700, HID or hardware B bank is inferred. Dual-number memory Cue buttons45/57,44/58,39/59, MEMO46, START CUE51, jog55/CC25, track24/CC26, pitchCC14, browser/search/FX/start/brake/relay state, mode/range and all feedback remain inactive. BPM54 does not toggle persistent native Sync. Source note types establish the standard MIDI-note input family; native accepts positive Note On and both release forms. Exact physical edge behaviour, complete modes/controls, lifecycle/discovery/recovery, USB/OS/power/audio/DVS and physical/iPad/A10X acceptance remain open. Requires an already exposed CoreMIDI source and separate app audio. No setup, HID report, identity query, source-mode, bank, firmware, driver or audio-route write runs. Other Audiophony and OEM bytes are not inherited.'
VIRTUALITY_PLAY_REFERENCES={'Audiophony PLAY':{'url':PLAY_SOURCE,'sha256':PLAY_SHA,'files':[{'cachePath':'TestBuilds/r461/upstream/virtuality-play-manual.pdf','sha256':PLAY_SHA}],'relatedSources':[{'url':'https://virtualdj.com/products/hardware.html?model=CDMP700'}],'review':PLAY_REVIEW}}


def virtuality_play_profiles():
    """Return only the original player's manual single-deck note subset."""
    p=profile('Audiophony PLAY',PLAY_SOURCE)
    p.update(definition='reviewed:audiophony-virtuality-play-manual-a',role='player',autoSelect=False,
        aliases=['Audiophony PLAY','Audiophony VIRTUALITY-PLAY','VIRTUALITY-PLAY','Virtuality Play'],
        excludedAliases=['CDX6','DJinn','DJAM','DJAZZ'],
        hardwareMode='Manual original VIRTUALITY-PLAY only. Select SOURCE=MIDI, not HID, and remain on hardware DECK A. Native controls deck A only. Hardware A/B switching is unqualified. Requires an exposed CoreMIDI source and separate app audio.',
        scope='Manual eight-button single-player A subset: Play, held native Cue/bends, Keylock, loop In/Out-or-Exit/Reloop. No channel default, automatic identity, bank switching, motion, feedback, setup or audio route is inferred.',
        bankChanges=[{'channel':0,'number':n,'anyChannel':True,'anyPositive':True,'decks':['a'],'releaseShiftChannels':[]} for n in [47,56]],
        gaps=[PLAY_REVIEW])
    for action,n in [('play',53),('cuePreview',52),('keylock',29),('loopIn',38),('loopOutOrExit',37),('reloop',36),('pitchBendDown',33),('pitchBendUp',32)]:
        add(p,action,0,n,deck='a');p['inputs'][-1]['anyChannel']=True
    return [p]

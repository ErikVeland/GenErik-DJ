"""DV2 USB manufacturer Bn/9n mixer facts with no fixed-channel inference."""
from curated import add, profile

DV2_SOURCE='https://assets.centryngroup.com/dl/files/DV2703__DL__002.pdf'
DV2_MAPPING='https://assets.centryngroup.com/dl/files/DV2703__DL__004.zip'
DV2_REFERENCES={'American Audio DV2':{
    'url':DV2_SOURCE,'sha256':'2c27fa0687929f8a955d1408ce976eb74b7977b035cb2190730e61d83286c253',
    'files':[
        {'cachePath':'TestBuilds/r458/upstream/dv2-manual.pdf','sha256':'2c27fa0687929f8a955d1408ce976eb74b7977b035cb2190730e61d83286c253'},
        {'cachePath':'TestBuilds/r458/upstream/dv2-vdj.zip','sha256':'fc3fa8ae79b3240e2579c707a16ac650ebed884cbc06bbbd2d72fedd66bf4979'},
        {'cachePath':'TestBuilds/r458/upstream/AADV2.xml','sha256':'9aedd6be5d4273560799b8aad5d203738b3dddb3d4e038b728b18e14f1eb82c6'},
        {'cachePath':'TestBuilds/r458/upstream/American Audio DV2 mapping.xml','sha256':'29370c36a725b29c445261350fc794a6e9c789f9c672ff8ccea8c59a2905b7ef'}],
    'relatedSources':[{'url':DV2_MAPPING},{'url':'https://www.adj.com/products/dv2-usb'},{'url':'https://virtualdj.com/products/hardware.html?model=AADV2'}],
    'review':'Own manufacturer manual pp11/12 qualifies MIDI-enabled internal mixing and explicitly defines continuous VR as Bn0..127 and SW as9n127/0, with n the channel. The manufacturer-hosted AADV2.xml and mapper are authored by Leo_V and independently corroborate NOTE/CC types and addresses; read as data, not executed. Their DV2_USB device/description identifies the catalogue DV2 entry as DV2 USB. No fixed factory channel is established. This16-input manual accessory accepts the documented n only through the bounded unbanked mixer contract:14 unique continuous controls and two unique A/B PFL notes, no momentary/transport/Shift/mode/bank/output/setup/audio contract. CH1 gain47/high48/mid49/low50/level58 and CH2 gain51/high52/mid53/low54/level59 remain independent. Global master55/cueMix56/headphone57/crossfader60 and PFL Note9/10 are direct manufacturer facts. Press hardware MIDI before use and keep fader reverse off. MIDI mode changes internal hardware/audio ownership; native does not select or discover it. The manual assigns software headphones to Core/ASIO3/4, while MIDI-off routes separate decks to1/2 and3/4. No automatic audio route is safe before mode ownership is qualified. EQ kill1..6, meter mode7, talkover8, fader reverse11..13, mic CC44..46, curves61..63 and Q-Start32/33 remain inactive. Fader-start notes are not Play. Full feedback/meters/mode/shutdown/recovery, USB/OS/driver or bridge requirements, direct iPad route, DVS/input routing and physical/iPad/A10X acceptance remain open. Requires an already available CoreMIDI source. The product Mac MIDI driver listing is not proof of either class compliance or a mandatory driver. No source SysEx prefix, identity query, MIDI-mode, preset, driver, firmware, mapper or audio-route command runs. No VMS/KUT/DP2 protocol is inherited.'}}


def dv2_profiles():
    """Return the manual MIDI-enabled mixer subset without hardware ownership writes."""
    p=profile('American Audio DV2',DV2_SOURCE)
    p.update(definition='reviewed:dv2-usb-manual-mixer',autoSelect=False,role='accessory',
        aliases=['American Audio DV2','American Audio DV2 USB','DV2 USB','DV2_USB','DV2 USB WDM(MIDI) Device'],
        excludedAliases=['DP2','VMS2','DV1'],
        hardwareMode='Manual DV2 USB MIDI mode only. Press the hardware MIDI button before use. Keep channel/crossfader reverse off. Requires an already available CoreMIDI source. Configure software-internal audio and headphones3/4 separately. Direct iPad USB/driver/bridge and complete mode ownership remain unqualified.',
        scope='Manual16-input mixer subset: gain/EQ/level per A/B, master/crossfader/headphone blend/level and two PFL buttons. Documented n channel accepted without guessing a default. No feedback, setup, transport or automatic audio route.',
        gaps=[DV2_REFERENCES['American Audio DV2']['review']])
    for deck,base,level,pfl in [('a',47,58,9),('b',51,59,10)]:
        for action,n in [('gain',base),('high',base+1),('mid',base+2),('low',base+3),('level',level)]:add(p,action,0,n,'control',deck=deck)
        add(p,'cue',0,pfl,deck=deck)
    for action,n in [('master',55),('cueMix',56),('monitor',57),('crossfader',60)]:add(p,action,0,n,'control')
    for row in p['inputs']:row['anyChannel']=True
    return [p]

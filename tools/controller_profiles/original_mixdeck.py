"""Independent original MIXDECK deck controls with manufacturer software-layout functions."""
from curated import add, profile

ORIGINAL_MIXDECK_REFERENCES={'Numark MixDeck': {'url': 'https://www.numark.com/images/product_downloads/mixdeck___quickstart_guide___v1.6.pdf', 'sha256': '023dcefa27e11651ab057b49bf11be50b5fb18ce22798fa9c6cfe7e20c08eb54', 'version': '1.6', 'pages': [4, 12, 13], 'visuallyReviewedPages': [12, 13], 'mappingURL': 'https://dmsdown.com/descargas/DMS_DJPROMIXER/DJProMixer_3.0_Setup.exe', 'mappingSHA256': '0557173bb5cb8bce866bbd439bd10140d8c281fd550486541dc4ddfff46edbec', 'mappingMember': 'Devices/NUMARK MIXDECK.xml', 'mappingMemberSHA256': 'cf2bdf917d81685b5539144f78ef8ad2af4e33ee5ca04ab9d901537f6dc1a347', 'review': 'The original manufacturer v1.6 guide explicitly says the mixer and iPod controls have no MIDI function. It requires USB-MIDI deck mode and documents the software layout: Play toggles, Pause sets Cue, Back opens groups, Track browses/loads, TAP Syncs and trigger pads1/2/3 set1/4/8-beat loops. Independent original ProMixer XML qualifies selected channels0/1 and raw input addresses. Native32-input manual subset does not reuse Express/Quad wires or calibration. Pitch virtual numbers224/225 are not raw controllers; jog, pitch, time/FX knobs, other modes, ambiguous lamp values74/75, complete feedback/lifecycle/audio and physical/iPad/A10X acceptance remain open. The software mixer and iPod are not invented as MIDI controls. No factory XML, program or MIDI action is executed or bundled.'}}


def original_mixdeck_profiles():
    name='Numark MixDeck'
    result=profile(name,ORIGINAL_MIXDECK_REFERENCES[name]['url'])
    result.update(autoSelect=False,definition='reviewed:numark-original-mixdeck-usb-midi',
                  aliases=[name,'MixDeck','Numark MIXDECK'],
                  excludedAliases=['MixDeck Express','MixDeck Quad','Numark MixDeck Express','Numark MixDeck Quad'],
                  hardwareMode='Manual original-model A/B deck subset. Select USB-MIDI on both players. Native Play toggles; Pause sets Cue, following the manufacturer software layout. Use app mixing and configure audio separately. The analogue mixer and iPod send no MIDI.',
                  scope='Manual32-input A/B Play/held Cue, Cue-set, Sync/key lock, held bends, manual loops, native Reloop,1/4/8-beat loop pads and strict track browse/load/group control. No sibling calibration or hardware write.',
                  gaps=['Jog/touch/tempo calibration and resolution, time/FX knobs, additional modes and physical controls, ambiguous lamp values, complete feedback/state/lifecycle, driver/audio routing and physical/iPad/A10X acceptance remain open. No stored preset, source script, firmware or automatic audio route is used. The analogue mixer and iPod have no MIDI function.'])
    for channel,deck in enumerate('ab'):
        for action,number in [('play',58),('cuePreview',56),('cueSet',57),('sync',81),('keylock',59),('pitchBendDown',60),('pitchBendUp',61),('loopIn',48),('loopOut',49),('reloop',50),('load',70)]:add(result,action,channel,number,deck=deck)
        for number,beats in [(51,1),(52,4),(53,8)]:
            add(result,'toggleFixedLoop',channel,number,deck=deck);result['inputs'][-1]['argument']=beats
        add(result,'browse',channel,33,'control','signedStep')
        add(result,'openGroup',channel,73)
    return [result]

"""Independent MC-1000 manufacturer wire facts with source-local context handling."""
from curated import add, profile

ZOMO_REFERENCES={'Zomo MC-1000': {'url': 'https://www.zomo.de/bilder/manuals_drivers/Zomo_MC-1000_Midi_TSI-File.zip', 'sha256': 'a9c3ddd7033ddd102e155a3c13223137cca4115977b0da058c6a82462d492c1a', 'member': 'Zomo_MC-1000_Midi_TSI-File.tsi', 'memberSHA256': '3046ea853b9bef1736867d177f4ea7a4f5e3fb61d7e810c1f7f3dc3374affa64', 'manualURL': 'https://www.zomo.de/bilder/manuals_drivers/Manual-Zomo-Midi-Controller-MC-1000-English.pdf', 'manualSHA256': '08ee9892c7daddb4ec804b23d6e6ec869cf01add7a0a9a87f1e05854b4e3ea12', 'pages': [14, 15, 17, 32, 33, 34, 36], 'visuallyReviewedPages': [14, 36], 'relatedSources': [{'url': 'https://www.zomo.de/support/'}], 'review': 'Independent manufacturer TSI and manual qualify raw deck channels0/1/2/3, normal/Shift signal families and the selected controls. The bounded existing inspector reads raw bindings without executing Traktor actions. The native42-control app layout with96 release-only guards uses Play/Sync, three Hot Cues, loop toggle/size,0.1% tempo steps and filter per deck, plus library browse/open. A typed observer resets only the source-owned physical side on deck/Shift context changes before binding lookup. Global traffic cannot select a bank and late old-bank releases cannot steal ownership. Load9/25 share global channel0 across A/C and B/D software conditions, which the inspector does not qualify, so Load remains inactive. Channel switch1, full FX/Shift/Bend/preset/feedback/audio and physical/iPad/A10X acceptance remain open. No TSI action, private SDK, hardware write or audio route is executed. ProMixer documents channel4/5 and DEX contains conflicting Load/duplicate CC cases, so neither is used to extend the manufacturer four-channel contract.'}}


def zomo_mc1000_profiles():
    name='Zomo MC-1000'
    result=profile(name,ZOMO_REFERENCES[name]['url'])
    result.update(role='accessory',inputProtocol='mc1000',definition='manufacturer:zomo-mc1000-native-channel-one',
                  aliases=[name,'MC-1000','Zomo MC1000','ZOMO MIDI MC-1000'],excludedAliases=['MC-1000 clone'],
                  hardwareMode='Set the MIDI Channel switch to1. Native follows the four manufacturer deck channels. C/D require opt-in. Close other controlling software. Normal paddles give0.1% tempo steps. Global Load, other channel-switch positions, feedback and audio routing remain unqualified.',
                  scope='Automatic four-deck Play/Sync, three Hot Cues, loops, tempo steps, filter and library navigation. Knobs must meet the app value after deck or Shift changes.',
                  gaps=['Global Load-bank software conditions, full FX/Shift/Bend and hold functions, additional channel-switch positions, complete feedback/state/lifecycle/audio, OS driver/port behaviour and physical/iPad/A10X acceptance remain open. No TSI action, stored preset, private SDK, hardware setup or audio route is written.'])
    for channel,deck in enumerate('abcd'):
        for action,number in [('play',14),('sync',15),('hotcue1',1),('hotcue2',2),('hotcue3',3),('loop',10),('tempoUp',12),('tempoDown',13)]:add(result,action,channel,number,deck=deck)
        controls=[('play',14),('sync',15),('hotcue1',1),('hotcue2',2),('hotcue3',3),('loop',10),('tempoUp',12),('tempoDown',13)]
        for wire in [channel,channel^2]:
            for action,number in controls:
                for release in ([number+63] if wire==channel else [number,number+63]):
                    add(result,action,wire,release,deck=deck);result['inputs'][-1]['releaseOnly']=True
        add(result,'filterKnob',channel,5,'control',deck=deck)
        add(result,'loopSize',channel,33,'control','binaryStep',deck)
    add(result,'browse',0,35,'control','binaryStep')
    add(result,'openGroup',0,34)
    return [result]

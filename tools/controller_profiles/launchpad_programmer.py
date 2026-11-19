"""Independent Programmer grids with native quadrants and bounded MIDI setup."""
from curated import profile
from native_dj_grid import add_native_dj_grid

GUIDE_BASE='https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/'
PROGRAMMER_REFERENCES={
    'Novation Launchpad X':{'url':GUIDE_BASE+'Launchpad%20X%20-%20Programmers%20Reference%20Manual.pdf','cacheName':'launchpad-x-programmer.pdf','sha256':'eca1842544e184e200a2134053acac8b1acb77df0247f23ef488fd9c2897db7a','pages':[6,7,8,10,13,15],
        'review':'Independent X reference qualifies LPX MIDI In/Out, wire channel0 grid11+10*y+x, product12 Programmer/Live command14 and repeated static palette colour specs. Layout/mode/grid/lighting pages visually checked. Two32-pad104-byte clear packets remain within the native128-byte message limit. A bounded Live exit is attempted if any startup message fails. DAW port and persistent custom layouts are not used.'},
    'Novation Launchpad Pro MK3':{'url':GUIDE_BASE+'LPP3_prog_ref_guide_200415.pdf','cacheName':'launchpad-pro-mk3-programmer.pdf','sha256':'54654f0603bf62e8d378961c3d759ba0ac022cbb7049e7a271af6c3b6ce97004','pages':[6,12,18,19],
        'review':'Independent Pro MK3 reference qualifies LPProMK3 MIDI In/Out, distinct DIN/DAW interfaces, wire channel0 grid11+10*y+x, product14 Programmer/Live command14 and static palette colour specs. Programmer grid, mode and lighting pages visually checked. A bounded Live exit is attempted if any startup message fails. No original Pro or Mini command is inherited. The new MK3 catalogue entry is separate from the original Pro.'},
    'Novation Launchpad Pro':{'url':GUIDE_BASE+'Launchpad%20Pro%20Programmers%20Reference%20Guide%201.01.pdf','cacheName':'launchpad-pro-programmer.pdf','sha256':'18675fcff65778d3d3ffa00ef7e6b4ce0dcb30e2edab9f95034bc1291c2001f7','pages':[4,5,16,17,18],
        'review':'Original Pro v1.01 independently specifies the same decimal grid in Programmer layout, Notes for square pads and CC for surrounding buttons. The grid and example bytes were visually checked. Its Standalone interface is USB port2, Programmer layout command is product16/44/3, and each layout has a saved MIDI channel. Native therefore retains manual channel1 Programmer setup without automatic mode/output writes. Manual feedback is a separate opt-in. No MK3 negotiation is inferred.'},
}


def programmer_profiles():
    results=[]
    for name,ref in PROGRAMMER_REFERENCES.items():
        original=name=='Novation Launchpad Pro'
        result=profile(name,ref['url'])
        result.update(autoSelect=not original,role='accessory',definition='manufacturer:'+name.lower().replace(' ','-')+'-native-grid',
                      excludedAliases=['Launchpad','Launchpad S','Launchpad MK2','Launchpad Mini','Launchpad Mini MK3']+[n.split(' ',1)[1] for n in PROGRAMMER_REFERENCES if n!=name],
                      hardwareMode='Original Pro Standalone MIDI port2, Programmer layout, channel1. Select and configure manually. Feedback needs separate manual opt-in.' if original else 'Use the documented MIDI interface. Native selects Programmer mode and restores Live mode at shutdown. Close other software that controls this device.',
                      scope='Native64-pad four-quadrant accessory: A/B below, opt-in C/D above. Each quadrant has Play, held Cue, Sync, Load; PFL, loop In/Out, Reloop; then eight Hot Cues. Fifty-two static status/pad lamps.',
                      gaps=['This is an app-selected DJ grid, separate from Ableton and other DJ mappings. Outer buttons, library navigation, mixer/FX, pressure/aftertouch expressions, persistent custom layouts, original saved-state restoration, complete modes/feedback/lifecycle and physical/iPad/A10X acceptance remain open. No audio route, DAW handshake, firmware/authentication or persistent preset is written.'])
        if not original:
            model=12 if name.endswith(' X') else 14
            port='LPX MIDI' if model==12 else 'LPProMK3 MIDI'
            result['aliases'].append(port)
            if model==14:result['aliases'].append('Launchpad Pro [MK3]')
            result['portAliases']=[port,port+' In',port+' Out']
            header=[240,0,32,41,2,model]
            notes=[11+10*y+x for y in range(8) for x in range(8)]
            clears=[header+[3]+[byte for n in notes[start:start+32] for byte in [0,n,0]]+[247] for start in [0,32]]
            result['startup']=[header+[14,1,247]]+clears
            result['startupAbort']=[header+[14,0,247]]
            result['shutdown']=[list(packet) for packet in clears]+[header+[14,0,247]]
        add_native_dj_grid(result,[[11+10*y+x for x in range(8)] for y in range(8)])
        results.append(result)
    return results

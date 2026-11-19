"""Independent legacy Launch Control XL configured-template facts and native app functions."""
from curated import add, profile

LAUNCH_CONTROL_XL_TEMPLATE_REFERENCES={'Novation Launch Control XL': {'url': 'https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_xl_programmer_s_reference_guide.pdf', 'sha256': '076985fa9a0859a2ecce0c35d1e843fc5815bd67062c0019de9a8cdca07f7c06', 'version': 'V2', 'pages': [3, 7, 8], 'visuallyReviewedPages': [8], 'componentsURL': 'https://components.novationmusic.com/assets/main-D3lNZfPT.js', 'componentsSHA256': '2322dc9fd409e5910e69f83cf5a6d4127c71322ded94e9bbc99cbba4be5a673a', 'componentsRelease': '1.72.5', 'reviewedSymbols': ['qoe.getFromDevice', 'Woe', 'H9.binary', 'z9.binary', 'B9.binary', 't9.binary'], 'familyURL': 'https://downloads.novationmusic.com/novation/launch/launch-control-xl-mk1mk2', 'review': 'Independent XL manufacturer guide and public Components source qualify product17, read query121, exact417-byte reply119,24 pots at0,8 faders at144,16 buttons at192,4 menu buttons at288 and4 arrow buttons at312, all six-byte records. Shared manufacturer button schema gives kind/number/min/max/pressType/channel. The remaining72 bytes describe pot LED settings and do not become controls or output writes. Both generations are explicitly covered by the manufacturer download page. Only public wire/schema facts were read. The Components app and its MIDI actions were not executed or copied. Native temporarily selects User0 and reads saved wires/ranges. Factory/HUI/XL3, unsupported/duplicate/toggle controls, complete feedback/state/lifecycle/timeout and physical/iPad/A10X acceptance remain open.'}}


def launch_control_xl_template_profiles():
    name='Novation Launch Control XL'
    result=profile(name,LAUNCH_CONTROL_XL_TEMPLATE_REFERENCES[name]['url'])
    result.update(role='accessory',inputProtocol='launchControlXLTemplate',definition='manufacturer:launch-control-xl-user-template-reader',
                  aliases=[name,'LaunchControl XL','Launch Control XL','Launch Control XL MK1','Launch Control XL MK2','Launch Control XL MKI','Launch Control XL MKII'],
                  excludedAliases=['Launch Control XL3','Launch Control XL 3','Launch Control XL MK3','Launch Control 3','Launch Control'],
                  portAliases=['Launch Control XL']+['Launch Control XL '+str(n) for n in range(1,9)],
                  hardwareMode='Native temporarily selects User template1 and reads its existing assignments. Other User templates are read on selection. Factory templates suspend native input. Close other editors. Existing raw mappings take priority. No stored preset, HUI or modern DAW mode is written.',
                  scope='Automatic configured-User-template four-pair mixer/transport accessory. Pot pairs control high/mid, low/filter, gain/level. Fader pairs control level/gain. Top buttons are Play/held Cue; bottom buttons Sync/Load. Device/Mute/Solo/Record Arm toggle A/B/C/D PFL and Shift+key lock. Right arrow is native Shift; Up/Down browse tracks and Left opens a group. C/D require opt-in.',
                  gaps=['Physical-position app functions use only unambiguous seven-bit continuous controls and momentary Note/CC buttons. Toggle/constant/duplicate/unsupported controls, Factory/HUI/XL3, full feedback/state/lifecycle/timeout recovery, prior-template restoration and physical/iPad/A10X acceptance remain open. No stored data, LED colour, firmware, DAW script, private SDK or audio route is written.'])
    for side,deck in enumerate('abcd'):
        column=2*side
        for row,actions in enumerate([['high','mid'],['low','filterKnob'],['gain','level']]):
            for offset,action in enumerate(actions):add(result,action,0,8*row+column+offset,'control',deck=deck)
        for offset,action in enumerate(['level','gain']):add(result,action,0,24+column+offset,'control',deck=deck)
        for row,actions in enumerate([['play','cuePreview'],['sync','load']]):
            for offset,action in enumerate(actions):
                add(result,action,0,48+8*row+column+offset,deck=deck);result['inputs'][-1]['shifted']=False
        for shifted,action in [(False,'cue'),(True,'keylock')]:
            add(result,action,0,64+side,deck=deck);result['inputs'][-1]['shifted']=shifted
    for action,number in [('browsePrevious',68),('browseNext',69),('openGroup',70),('shift',71)]:
        add(result,action,0,number)
        if action!='shift':result['inputs'][-1]['shifted']=False
    result['bankChanges']=[{'channel':0,'number':71,'onValue':127,'decks':list('abcd')}]
    result['startup']=[[240,0,32,41,2,17,119,0,247],[240,0,32,41,2,17,121,0,247]]
    return [result]

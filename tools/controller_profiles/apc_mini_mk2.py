"""Independent APC mini MK2 Session input and RGB brightness contracts."""
from curated import add, profile
from native_dj_grid import add_native_dj_grid

APC_MINI_MK2_GUIDE='https://cdn.inmusicbrands.com/akai/attachments/APC%20mini%20mk2%20-%20Communication%20Protocol%20-%20v1.0.pdf'
APC_MINI_MK2_REFERENCES={'Akai APC mini MK2':{
    'url':APC_MINI_MK2_GUIDE,'cacheName':'apc-mini-mk2-protocol.pdf','sha256':'38881e0411831a9e67a2896b9dad8d8938b57bda278a6290aa717be4b046d6a7','pages':[2,3,9,13,16],
    'relatedSources':[{'url':'https://support.akaipro.com/en/support/solutions/articles/69000833843-akai-pro-apc-mini-mkii-how-to-download-install-and-setup-ableton-live-lite'}],
    'review':'Manufacturer Communications Protocol v1.0 pages2/3/9/13/16 visually checked. Session grid is0..63 bottom-to-top, eight columns. Only wire channel0 on the documented Control interface is accepted; Drum9 and the separate Note interface are excluded. Static full-brightness RGB feedback uses wire channel6. Shift122 retires source-owned holds and guards the grid. Nine absolute faders are CC48..56 on0. Native chooses four level, four gain and one master fader, plus the shared app quadrant functions on this independently qualified Akai grid. Introduction uses product79/application0 and the current app version0.1.0. Command36 clears pad range0..63 with eight payload bytes and zero RGB components and no surrounding-button write. No Ableton script, private handshake, original APC or other model protocol is inherited. Complete mode/channel negotiation, remaining UI, expressions/lifecycle and physical/iPad/A10X acceptance remain open.'}}


def apc_mini_mk2_profiles():
    result=profile('Akai APC mini MK2',APC_MINI_MK2_GUIDE)
    result.update(role='accessory',definition='manufacturer:apc-mini-mk2-session-native-grid',
                  aliases=['Akai APC mini MK2','APC mini mk2','APC mini MK 2','APC mini MK 2 (Control)'],
                  portAliases=['APC mini MK 2 (Control)'],
                  excludedAliases=['APC mini','APC40','APC40 MKII','APC64','APC mini MK 2 (Notes)'],
                  hardwareMode='Session view on MIDI channel1 through APC mini MK 2 (Control). Close other software that controls the device. Drum channel10 and the separate Note interface remain inactive.',
                  scope='Automatic74-input native Session grid and fader accessory. Four pad quadrants provide transport, held Cue, Sync, Load, PFL, manual loops and eight Hot Cues per deck. Faders1..4 are levels A..D,5..8 are gain A..D,9 is master. C/D require opt-in. Fifty-two static lamps use full-brightness channel7.',
                  gaps=['This is a native app grid/fader layout, separate from Ableton. Other Session channels, Drum/Note modes, full mode negotiation, remaining track/scene buttons, pressure/expression, user colour/state restoration, full feedback/lifecycle and physical/iPad/A10X acceptance remain open. Port-name variants and required iPad power need physical qualification. No DAW script, audio route or persistent template is written.'])
    add_native_dj_grid(result,[[8*y+x for x in range(8)] for y in range(8)],output_channel=6)
    for row in result['inputs']:row['shifted']=False
    add(result,'shift',0,122)
    for index,deck in enumerate('abcd'):add(result,'level',0,48+index,'control',deck=deck)
    for index,deck in enumerate('abcd'):add(result,'gain',0,52+index,'control',deck=deck)
    add(result,'master',0,56,'control')
    result['bankChanges']=[{'channel':0,'number':122,'onValue':127,'decks':list('abcd')}]
    clear=[240,71,127,79,36,0,8,0,63,0,0,0,0,0,0,247]
    result['startup']=[[240,71,127,79,96,0,4,0,0,1,0,247],list(clear)]
    result['shutdown']=[list(clear)]
    result['startupAbort']=[list(clear)]
    return [result]

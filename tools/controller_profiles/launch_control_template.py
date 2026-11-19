"""Read original Launch Control assignments using independent manufacturer editor facts."""
from curated import add, profile

LAUNCH_CONTROL_TEMPLATE_REFERENCES={'Novation Launch Control': {'url': 'https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/launch-control-programmers-reference-guide.pdf', 'sha256': '759108827d49557ae41fe4add63d767bfde46378f07b19707b3133cab453f659', 'pages': [2, 6, 7], 'visuallyReviewedPages': [7], 'editorURL': 'https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/novation/downloads/10773/novation-launch-control-editor.dmg', 'editorSHA256': '684dae96016739b795f88fb82edaa21761f7e9783d5c994f1d3510f3fe76482d', 'editorMember': 'Novation Launch Control Editor/Novation Launch Control Editor.app/Contents/Resources/web/js/editor.js', 'editorMemberSHA256': '797a28925f07420d13839d8f91e29aca38f91e892128f817b19d682119e53e7b', 'review': 'Original product10 programmer guide provides temporary template selection and template-change notifications. Public manufacturer editor source independently provides User-template read query121,177-byte reply119,16 knob and12 button six-byte records, configured channels/ranges/types and reserved fields. Only independent wire facts were read. The editor and downloaded actions were not executed or copied. Native selects User0 and reads stored data without a stored-template write/reset. Duplicate wires, constant ranges, toggle buttons, unsupported reserved data and Factory templates remain inactive. Existing raw mappings take priority. This is a native physical-position layout, not a manufacturer DJ mapping. Full Factory/feedback/lifecycle/timeout/state and physical/iPad/A10X acceptance remain open.'}}


def launch_control_template_profiles():
    name='Novation Launch Control'
    result=profile(name,LAUNCH_CONTROL_TEMPLATE_REFERENCES[name]['url'])
    result.update(role='accessory',inputProtocol='launchControlTemplate',definition='manufacturer:launch-control-user-template-reader',
                  aliases=[name,'Launch Control','LaunchControl'],
                  excludedAliases=['Launch Control XL','Launch Control XL3','Launch Control 3','LaunchControl XL3'],
                  portAliases=['Launch Control']+['Launch Control '+str(n) for n in range(1,9)],
                  hardwareMode='Native temporarily selects User template1 and reads its existing assignments. Other User templates are read on selection. Factory templates suspend native input. Close other editors. Existing raw mappings take priority. No stored preset is changed.',
                  scope='Automatic configured-User-template mixer/transport accessory. Adjacent column pairs target A/B/C/D. Encoders: high/mid then low/gain. Pads: Play/held Cue. Right arrow is native Shift. Shift+Play loads; Shift+Cue toggles PFL; Shift+gain controls level. Up/Down browse tracks; Left opens a group. C/D require opt-in.',
                  gaps=['Physical-position app functions use only unambiguous seven-bit knobs and momentary Note/CC buttons. Toggle/constant/duplicate/unsupported controls and Factory templates stay inactive. Full modes/feedback/timeout recovery, prior-template restoration and physical/iPad/A10X acceptance remain open. No stored data, firmware, DAW script, private SDK or audio route is written.'])
    for side,deck in enumerate('abcd'):
        column=2*side
        for action,number in [('high',column),('mid',column+1),('low',column+8),('gain',column+9)]:
            add(result,action,0,number,'control',deck=deck)
            if action=='gain':result['inputs'][-1]['shifted']=False
        add(result,'level',0,column+9,'control',deck=deck);result['inputs'][-1]['shifted']=True
        for shifted,actions in [(False,['play','cuePreview']),(True,['load','cue'])]:
            for offset,action in enumerate(actions):
                add(result,action,0,32+column+offset,deck=deck);result['inputs'][-1]['shifted']=shifted
    for action,number in [('browsePrevious',40),('browseNext',41),('openGroup',42),('shift',43)]:
        add(result,action,0,number)
        if action!='shift':result['inputs'][-1]['shifted']=False
    result['bankChanges']=[{'channel':0,'number':43,'onValue':127,'decks':list('abcd')}]
    result['startup']=[[240,0,32,41,2,10,119,0,247],[240,0,32,41,2,10,121,0,247]]
    return [result]

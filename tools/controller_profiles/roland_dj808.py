"""Own DJ-808 normal protocol facts without a partial software-mode lifecycle."""
from curated import add, profile

DJ808_REFERENCES={'Roland DJ-808': {'url': 'https://raw.githubusercontent.com/peter-vincze/mixxx/e1f90cde7a2904ae4c9de48614d1df85d3f2e34a/res/controllers/Roland_DJ-808.midi.xml', 'sha256': '08b3532bbc3f7754ba9e177bfe9e36f26f592e800470fd86987c24e4230a46e4', 'upstreamRevision': 'e1f90cde7a2904ae4c9de48614d1df85d3f2e34a', 'files': [{'cachePath': 'TestBuilds/r469/upstream/dj808.midi.xml', 'sha256': '08b3532bbc3f7754ba9e177bfe9e36f26f592e800470fd86987c24e4230a46e4'}, {'cachePath': 'TestBuilds/r469/upstream/dj808-scripts.js', 'sha256': '30277379bfc422fa03f3c81858cdbe0a508cb80b9e05f5d62904b89cb30fe927'}, {'cachePath': 'TestBuilds/r469/upstream/dj808-manual.pdf', 'sha256': '796590acf6f3df4046776fbb4b9a354959b3853c2e5f9342983db845b8b910c7'}, {'cachePath': 'TestBuilds/r469/upstream/dj808-pr15063.json', 'sha256': '32de39d784352caf22f91356ecbd595f8c635d3f97f709affe088efbbe3e6826'}], 'relatedSources': [{'url': 'https://github.com/mixxxdj/mixxx/pull/15063', 'merged': False}, {'url': 'https://static.roland.com/assets/media/pdf/DJ-808_eng03_W.pdf', 'sha256': '796590acf6f3df4046776fbb4b9a354959b3853c2e5f9342983db845b8b910c7', 'visuallyReviewedPages': [21]}], 'review': 'Primary contributor peter-vincze supplies own-model DJ-808 XML and mapper in open/unmerged Mixxx PR15063 at e1f90cde7a2904ae4c9de48614d1df85d3f2e34a. This is community protocol evidence, not a released Mixxx profile or manufacturer numeric approval. The XML explicitly names DJ-808 and supplies all four raw0..3 deck assignments. Normal Play0, held Cue1, native Sync2 and Keylock13 retain shifted release-only aliases4/5/3/14. Opposite-side-bank negative aliases preserve source-owned release/rearm. Global Shift is raw15 Note0. Native uses its existing Sync toggle rather than importing source short/long-press leader/quantise logic. Shifted positive transport stays inactive. Five paired14-bit controls per deck are gain22/52, high23/53, mid24/54, low25/55 and level28/58. Both byte roles are explicit inputMSB/inputLSB XML references, not a plus32 guess; mistaken volume descriptions do not override callback keys. The mapper EQ output-address constants conflict with input XML, so only explicit input assignments and indexed EQ roles are used; no EQ feedback is sent. Separate normal filterCC26 and PFLNote27 are Shift-guarded. Raw4..7 Reloop51/Half52/Double53/In56/Out57 use native loop semantics. Own XML deck selectors are Note8 on raw0/1; positive reports clear owned holds/pickup for A/C or B/D without inventing native software banks. C/D require app opt-in; physical strip order is3/1/2/4. Roland own revision03 guide p21 visually confirms standalone controller MIDI through the PC port, except TR-S/VT; DIN MIDI OUT carries synchronization only. Its PC USB connection requires a driver. Manual use requires an already exposed CoreMIDI source or independently qualified bridge, PC input selection and separate app audio; no direct iPad driver/USB claim is made. Mixer controls also affect hardware audio in standalone mode. Native does not send the source SysEx/periodic keepalive, driver, firmware, preset, mode, feedback or audio-route writes. Shared Load ownership, dual-deck mode, tempo polarity/range, source-specific crossfader maximum16368, jog/touch calibration, pads/FX/TR-S/VT, full controls/modes/feedback/lifecycle/recovery, USB/OS/power/audio/DVS and physical/iPad/A10X acceptance remain open. No DJ-202/505/707M bytes or identities are inherited and no upstream script/component code executes or ships.'}}


def dj808_profiles():
    """Return independently qualified normal MIDI inputs through a manual port."""
    ref=DJ808_REFERENCES['Roland DJ-808']
    p=profile('Roland DJ-808',ref['url'])
    p.update(definition='reviewed:roland-dj808-primary-manual-core',autoSelect=False,
        excludedAliases=['Roland DJ-202','DJ-202','Roland DJ-505','DJ-505','Roland DJ-707M','DJ-707M'],
        hardwareMode='Manual normal MIDI subset on an already exposed PC-port MIDI source or independently qualified bridge. The own guide requires a PC USB driver; direct iPad USB remains unqualified. Select PC for software strips and configure app audio separately. C/D require app opt-in. Native does not start Serato mode or its periodic keepalive.',
        scope='Manual113-input four-target normal Play/held Cue/Sync/Keylock, explicit paired gain/EQ/level, filter/PFL and loop buttons. Source-owned Shift/bank release protection. No shared Load, tempo, crossfader, jog/pads/FX/TR-S, hardware setup or audio route.',
        bankChanges=[{'channel':i,'number':8,'anyPositive':True,'decks':list('ac' if i==0 else 'bd')} for i in range(2)],
        gaps=[ref['review']])
    add(p,'shift',15,0)
    for ch,deck in enumerate('abcd'):
        for action,n,shifted in [('play',0,4),('cuePreview',1,5),('sync',2,3),('keylock',13,14)]:
            add(p,action,ch,n,deck=deck);p['inputs'][-1]['shifted']=False
            add(p,action,ch,shifted,deck=deck);p['inputs'][-1]['releaseOnly']=True
            for off in [n,shifted]:
                add(p,action,(ch+2)%4,off,deck=deck);p['inputs'][-1]['releaseOnly']=True
        for action,n,low in [('gain',22,52),('high',23,53),('mid',24,54),('low',25,55),('level',28,58)]:
            add(p,action,ch,n,'control','paired14Bit',deck);p['inputs'][-1]['lowNumber']=low
        add(p,'filterKnob',ch,26,'control',deck=deck);p['inputs'][-1]['shifted']=False
        add(p,'cue',ch,27,deck=deck);p['inputs'][-1]['shifted']=False
        for action,n in [('reloop',51),('loopDown',52),('loopUp',53),('loopIn',56),('loopOut',57)]:add(p,action,ch+4,n,deck=deck)
    return [p]

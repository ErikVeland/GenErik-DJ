"""Independent APC20 mode2 wires and explicit native four-deck assignments."""
from curated import add, profile

APC20_OWNER = 'https://raw.githubusercontent.com/ArtGateOne/ma2apc20/3941b87148b2602f76571d750004a09599eff39f/ma2apc20/ma2apc20.js'
APC20_DEFAULT = [240, 71, 127, 123, 96, 0, 4, 64, 8, 2, 1, 247]
APC20_REFERENCES = {'Akai APC20': {
    'url': APC20_OWNER, 'sha256': '0fa61faf65ba9f1ff19288cc596074052f1ad1f3bc59f24e70038f999bd5866a',
    'files': [{'cachePath': 'TestBuilds/r439/upstream/apc20-owner.js', 'sha256': '0fa61faf65ba9f1ff19288cc596074052f1ad1f3bc59f24e70038f999bd5866a'}, {'cachePath': 'TestBuilds/r439/upstream/apc20-owner-README.md', 'sha256': 'c2286d4f9f76947654b6faa16c2a9cecd8db8429064fa9250fc696f07f73c2f2'}, {'cachePath': 'TestBuilds/r439/upstream/APC20.qxi', 'sha256': '4e051dfb72e1c55faaa02a15bceaaedd906fdb7cd96a33cc8ab103d6605292ce'}, {'cachePath': 'TestBuilds/r440/upstream/apc20-mode-reference.html', 'sha256': '2bfac5e71545b86697c1e801bc3c39edb74e159c0a34277da37ae251492931f3'}, {'cachePath': 'TestBuilds/r440/upstream/apc20-guide.pdf', 'sha256': '8bcf571ab3b7bdbc7df84a3c072cf20e9a30092d34d8d70b2e0407c79ab1a7f3'}],
    'relatedSources': [{'url': 'https://raw.githubusercontent.com/ArtGateOne/ma2apc20/3941b87148b2602f76571d750004a09599eff39f/README.md'}, {'url': 'https://raw.githubusercontent.com/mcallegari/qlcplus/29929e877fb8a8466666ca8005b4ea57db27444f/resources/inputprofiles/Akai-APC20.qxi'}, {'url': 'https://audiodestrukt.wordpress.com/2012/11/26/hacking-on-the-apc-20/'}, {'url': 'https://cdn.inmusicbrands.com/akai/attachments/legacy1/apc20___quickstart_guide___reva_00.pdf'}],
    'review': 'Own pinned hardware-owner integration explicitly selects APC20 mode2 with product7B/command60/value42, then handles per-channel Notes53..57, Solo49, CC7 faders, masterCC14 and signed encoderCC47. Independently authored QLC+ APC20 input profile corroborates every active wire, including Shift81/channel1 and the four navigation keys Note51/channels5..8. A separate firsthand APC20 write-up documents the matching command and default mode40. Native paired setup selects the exact source mode2; shutdown/partial-startup abort requests default mode40. No acknowledgement or previous-state restoration is claimed. Native assigns each adjacent column pair to A/B/C/D. Notes53..56 provide eight Hot Cues per pair; Note57 is Play on the left/Cue on the right. Each adjacent fader pair is level/filter for that deck; master stays global. Solo buttons on either column set that native deck PFL. Navigation is pulse-based, and the encoder accepts only strict1/127 steps. Shift retires only its source and guards all normal inputs. Forty grid plus eight PFL lamps use independently observed on values1/3 and off0. Colour names are not inferred from APC40. Source lighting-console actions and its nonlinear fader curve do not run. Other34 QLC+ controls, full encoder magnitude/calibration, other hardware modes, persistence of the mode selection, saved LED/mode restoration, complete feedback/lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. Native sends no identity query, preset/global-settings dump, driver, firmware or audio route. APC40/APC64/APC mini protocols remain separate.'}}


def apc20_profiles():
    """Return the paired mode2 native pad, PFL, fader and library subset."""
    p = profile('Akai APC20', APC20_OWNER)
    p.update(definition='reviewed:apc20-mode2-native', role='accessory',
        aliases=['Akai APC20', 'APC20'], excludedAliases=['APC40', 'APC40 mkII', 'APC64', 'APC MINI', 'APC mini mk2'],
        hardwareMode='Use APC20 USB MIDI with its power adapter and close other controller software. Native selects mode2 and requests default mode at shutdown. Each adjacent column pair targets A/B/C/D; enable C/D separately. First four pad rows: eight Hot Cues. Last row: Play/Cue. Paired faders: level/filter; Solo buttons: PFL. Master stays global. Shift blocks normal controls. Previous state is not restored.',
        scope='Automatic63-input native mode2 accessory:40 pads, eight PFL buttons, nine faders, strict library encoder, four navigation buttons and Shift. Forty-eight static lamps. Other controls/modes/full lifecycle remain open.',
        startup=[[240, 71, 127, 123, 96, 0, 4, 66, 8, 2, 1, 247]], shutdown=[APC20_DEFAULT], startupAbort=[APC20_DEFAULT],
        bankChanges=[{'channel': 0, 'number': 81, 'anyPositive': True, 'decks': list('abcd'), 'releaseShiftChannels': []}], gaps=[APC20_REFERENCES['Akai APC20']['review']])
    for bank, deck in enumerate('abcd'):
        channel = 2 * bank
        for slot in range(8): add(p, f'hotcue{slot + 1}', channel + slot % 2, 53 + slot // 2, deck=deck, feedback=True)
        add(p, 'play', channel, 57, deck=deck, feedback=True)
        add(p, 'cuePreview', channel + 1, 57, deck=deck, feedback=True)
        for ch in [channel, channel + 1]: add(p, 'cue', ch, 49, deck=deck, feedback=True)
        add(p, 'level', channel, 7, 'control', deck=deck)
        add(p, 'filterKnob', channel + 1, 7, 'control', deck=deck)
    add(p, 'master', 0, 14, 'control')
    add(p, 'browse', 0, 47, 'control', 'signedStep')
    for channel, action in [(4, 'browsePreviousGroup'), (5, 'browseNextGroup'), (6, 'browsePrevious'), (7, 'browseNext')]:
        add(p, action, channel, 51); p['inputs'][-1]['pulse'] = True
    for row in p['inputs']: row['shifted'] = False
    add(p, 'shift', 0, 81)
    for lamp in p['outputs']: lamp.update(onValue=3 if lamp['action'].startswith('cuePreview') else 1)
    return [p]

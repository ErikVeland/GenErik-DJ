# GenErik DJ north star

Build the most intuitive, fluid, multi-touch digital DJ app. Preserve the feel and reliability Erik has relied on in TDJ1 for more than a decade, so he can trust the same instrument through another decade of gigs.

## What comes first

1. **Clean, continuous audio.** Keep the output clear and at the intended speed throughout the set. Any crackle, dropout, unintended pause, slowdown or stop blocks acceptance.
2. **Immediate, fluid control.** Keep every performance control responsive. Track simultaneous touches so one gesture can continue while another starts. A missed touch, delayed control, visible stutter or UI stall blocks acceptance.
3. **Clarity.** Make the rhythm, groove and next mixing decision readable at a glance. Show individual hits and their hitting frequencies. Separate attacks from preceding decay. Preserve the musical pattern, accents and swing.

Verify sound and touch together on Erik’s 2017 A10X iPad Pro during a representative live set. Use the [performance acceptance gates](coordination/release-gates.md).

## Read the music at a glance

The waveform is a performance map of individual hits, rhythm and groove.
A DJ or drummer should read the pattern and feel where each hit lands.
Musical readability takes priority over a literal trace of the mastered signal.

Use its bands like performance stems. Keep kick, bass and snare attacks strong. Taper preceding decay in the same frequency bands.
Keep TDJ1's readable peaks, beat/bar hierarchy and space between attacks. Avoid a dense, uniform waveform sausage.

Show accents, quieter ghost notes, syncopation and swing. Keep their real spacing against the beat grid.
Shape envelopes, contrast and visual weight to expose those musical events.
Reduce sustained fill and decay when they obscure individual hits. Keep bass notes and phrase changes readable as context.
Exact sample amplitude is not an acceptance target.

Preserve useful timing and musical changes while adjusting contrast and visual weight.
Keep the same band meanings across zoom levels, section colours and deck sizes.
Use aligned stem envelopes when verified data already exists. Frequency bands remain useful visual cues when it does not.
Do not start live separation to decorate a waveform.
See the [waveform clarity contract](../ARCHITECTURE.md#waveform-clarity) for priorities and acceptance.

## One physical workspace

Keep TDJ1’s touch conventions intact so familiar gestures still work by feel. Design for fingers on glass. Use older DJ hardware and software conventions only where they make the touch workflow better.

Let the DJ work directly on the waveform, jump by beats, set and resize loops, and navigate the track by touch. Let panes slide, drag and resize as the DJ works. Adjust what each pane shows and how much detail it displays to fit the moment. These actions should feel like parts of one instrument.

## How features earn their place

Start small. Start simple. Add a feature only when a real DJ task needs it.
Keep new expansions off until the DJ chooses them. Keep setup and maintenance outside the ordinary live surface.
Use the [architecture guide](../ARCHITECTURE.md) for feature boundaries, DJ stories and review rules.

Add features that make a real DJ task easier while preserving the flow of a set. Keep the performance surface free of clutter and extra steps. Defer or simplify any feature that slows the DJ down. Make analysis and other background work yield, pause or cancel before they affect audio or touch.

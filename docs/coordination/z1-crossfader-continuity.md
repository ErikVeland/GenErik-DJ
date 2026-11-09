# R90: crossfader continuity

Erik requested the Z1 crossfader fix next, followed by R91 preview navigation and R92 long-track loading.
The last recorded A10X installation is build 151. Physical acceptance of R89 and R93 remains open.
The remaining fixes proceed serially, with separate commits and build records before the final device handover.

## Reproduced failure

The native command queue holds 127 pending commands. A full queue rejects new submissions.
The controller previously discarded a rejected crossfader position. The Z1 mapper still remembered that input report.
An unchanged subsequent report therefore did not retry the position.

A focused test faded a playing deck out, filled the command queue, then moved the decoded Z1 crossfader back.
The deck kept advancing, but the crossfader remained at one and the rendered audio remained silent.
Two expectations failed before the change. This confirms one source-level cause of persistent silence.
The precise hardware sequence from the live test remains unconfirmed.

## Change

Retain one latest crossfader position when the queue is full. Retry it through existing control maintenance.
A newer input replaces the waiting position. Invalid input cannot replace it.
No view refresh or stop/start action is required for delivery.

Crossfader and channel-volume commands already cancel recovery inside the audio consumer.
They now invalidate pending preparation without adding two redundant native cancellation commands.
The command queue size, audio smoothing, source limits and Sync behaviour remain unchanged.

## Verification

Twenty-seven focused host tests passed across twenty-nine cases.
Checks cover decoded Z1 input, queue pressure, restored audible output, newer and invalid input,
maintenance without visual polling, streamed output against a resident reference, mixer behaviour and recovery.
The streamed sweeps had no continuity failure or rejected command.

The first affected run found an older recovery fixture that assumed seeks could remain off-grid.
It now measures time to the recovery boundary from the actual grid-aligned position.
The final follow-up also checks that crossfader and volume changes cancel recovery without stopping playback.
Pre-existing compiler warnings and all failed and successful attempts remain under `TestBuilds/r90/`.

## Device checks

1. Play two prepared tracks with the Z1 connected.
2. Sweep the crossfader repeatedly from each endpoint through the centre.
3. Leave a deck faded out, then bring it back without touching Play.
4. Move other controls during the sweeps.
5. Check both decks, headphone cue, Sync and uninterrupted audible output.

A signed build and host checks do not establish A10X or gig acceptance.

# R92 long-track loading

Erik reported audio and waveform flicker when loading a long unanalysed track in build 144.

## Causes and changes

The waveform view discarded its drawing index whenever progressive decoding changed the bin count. The replacement index arrived asynchronously. The intervening drawing had no waveform. The view now retains a compatible index until its replacement is ready. Compatibility requires the same audio identity, frame count, sample rate and bin width. An initial view uses at most 128 opening bins while its full index prepares.

Whole-track waveform decoding and colour-band preparation previously continued during playback. They now wait while either deck plays, queues a start or holds a touch gesture. The waveform decoder checks between bounded chunks and before publishing or committing its cache. It resumes from the same position when performance is idle. New progress cannot shorten the opening waveform. Playback read-ahead remains active.

Colour-band work also yields before full PCM preparation and during sample processing. Cancelled views release their requests. The last cancellation stops the worker, while another deck can retain a shared request. The cache wait retains a thirty-second idle budget.

The new long-track check also found a Sync/Keylock load rejection. The engine divided the master tempo by zero before an unanalysed track had a grid. The load now retains Sync and Keylock without calculating that unavailable ratio. A later grid restores beat alignment.

## Verification

Eighteen combined host tests passed across nineteen cases on the final source. They cover crossfader retries, streamed sweeps, preview beat taps, waveform drawing, long loading, cancellation, resume and the Sync/Keylock load boundary. The earlier focused run also passed all twelve persistent-Sync tests. Its fifteen core tests included waveform completion and cancellation.

A twenty-minute uncached stereo file loaded on deck B while deck A played. Deck A output matched an independent reference sample for sample. Full-track waveform work stayed paused, the opening waveform remained stable and no full PCM cache appeared. This is a host continuity check, not an A10X deadline measurement.

Failed setup, load, background-work and compilation attempts remain under `TestBuilds/r92/`. The final verification record binds the combined results to the source hash. R91 navigation evidence remains under `TestBuilds/r91/`.

## A10X acceptance

Play a prepared track with the Z1 connected. Load a long unanalysed track on the other deck. Check audible continuity, waveform stability and immediate control response. Check crossfader return from both endpoints without stop/start. Check preview navigation and grid-aligned beat taps.

Whole-track waveform and colour details remain incomplete during performance if they were not already prepared. They resume when both decks are idle. Existing drawing remains visible. This trade-off gives live audio priority.

Build and host success do not establish physical acceptance or gig readiness. R89–R93 remain open until Erik confirms their behaviour on the A10X and Z1.

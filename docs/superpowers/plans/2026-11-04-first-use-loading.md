# First-use loading implementation plan

**Goal:** Show real waveform data and start playback without full-track export, analysis or PCM conversion.

**Architecture:** Decode requested blocks on the existing serial read-ahead worker. Keep decoding off the audio callback. Publish an opening waveform, then extend it in the background. Native source identities remain explicit until content analysis completes. Keep manual preparation and audio generations stable.

**Scope:** R45. iPad only. Use the main working folder, one serial feature branch, one signed main build and Erik's acceptance.

- [x] Capture the old full-track preparation gates and a failing cold-cache test.
- [x] Add an owned decoder callback to the bounded native stream. Check bounded reads, failure, cancellation and release.
- [x] Add a direct local/native decoder with opening waveform data and cancellable progressive waveform reads.
- [x] Add explicit native playback identities and partial waveform coverage. Preserve identities and manual preparation when analysis completes.
- [x] Route native deck loading through the direct source. Retain Play and cancellation ownership. Keep full export confined to background preparation.
- [x] Run focused native and loading checks. Preserve failed attempts and exact source identities.
- [ ] Consolidation owner: merge the committed checkpoint into main, build once, install and record Erik's handover.

# R47: Remove repeated waveform work

All pre-existing local branches are ancestors of main at `7cb4dc346`. The eight accessible historical working folders are clean. Their branches, saved apps and evidence remain preserved. The missing recovery folder and earlier R19 private-source gaps remain recorded. Build 110 was prepared, with no recorded installation.

This iteration removes repeated waveform calculations. Beat lines now read the fixed or adaptive grid directly. They no longer allocate amplitude columns or query audio peaks. Close zoom also skips a range query whose result was immediately replaced by interpolated values. The combined waveform/beat API and custom equality code are removed. The view can draw known beat lines before its waveform index arrives.

Audio transport, controls, layouts and analysis algorithms are unchanged. Erik requested that the 233 MB stem model remain bundled.

## Verification

- Exact comparison with `7cb4dc346` passes 800 cases. Peak, body, core, pixel positions and downbeat flags match. Cases include empty and single-bin inputs, five widths, five zoom spans, four viewport positions and fixed/adaptive grids.
- Seven focused core tests and six rendered deck cases pass. The render cases produce 24 images across both decks, stored bins, frequency bands, FX and Freeze. Two final images were inspected.
- The original API fails the new standalone checker, as expected. See `red-api.log`.
- The normal filtered package command cannot compile existing MIDI tests. `ControllerMIDIUMPDecoderTests.swift` uses optional chaining after `#require`. The first focused retry also encountered mutating-call macro errors in `ControllerMIDIProfileTests.swift`. See `focused-tests.log`. The final run limited test sources temporarily. `Package.swift` was restored exactly. No full-suite pass is claimed.

The comparison uses optimised standalone production drawing code on this Mac. Both versions compile together with identical flags. Medians cover five runs of 1,000 passes at 1,800 pixels and 120,000 stored bins.

| Calculation | Before | After | Time removed |
| --- | ---: | ---: | ---: |
| Stored-bin geometry and beat positions | 43.020 ms | 17.550 ms | 59.2% |
| Beat positions with frequency bands ready | 19.881 ms | 0.237 ms | 98.8% |

These numbers exclude Canvas drawing, band geometry, audio and device scheduling. They do not measure total frame time or A10X performance. Run `python3 docs/testing/checks/R47/2026-11-04-render-cleanup/compare.py` from the project folder to repeat the comparison.

## Remaining scope

Follow the single-change iPad loop. Erik checks both decks, zoom, fixed/adaptive beat lines, Actions, touch response and clean audio. Full-session A10X memory, thermal and callback measurements remain open. Section-colour drawing cost, native decoder cost and library-size startup costs need separate measurement before further changes. Existing MIDI test compilation failures need a separate repair. This pass does not establish that the entire project is free of waste or gig-ready.

## iPad handover

Signed main source `921fbf92b` produced build 111. Source identity, framework resolution and signing passed. Build 111 installed, and iPadOS accepted the launch request. Device actions stopped. The build record retains the app digest and timestamps. Physical acceptance remains open.

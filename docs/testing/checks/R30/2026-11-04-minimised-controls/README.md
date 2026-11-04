# Compact deck actions and immediate waveform previews

Feedback assumes installed iPad build 109. This iteration combines R02/R30 compact controls, R45 early waveform display and the coordinated R09 colour checkpoint.

Each deck keeps artwork/load at the top left and time at both bottom corners. A small Actions button sits on the main waveform above the overview. Tap it, or swipe up/right, to open Flux, Freeze, Cues, loop length and settings. The pane slides over the waveform. It reserves no waveform width or height. Its button follows the waveform edge when FX or Freeze controls are open. The fixed right-hand transport and crossfader retain their anchors.

A 240-point compact minimum fits the open pane, header, overview and optional hotcue pads. This includes optional Cue, headphones, tempo and Return controls. Both decks remain usable with the browser open. A performance panel can borrow browser height while preserving its usable minimum. Empty decks show no Actions, Flux or Cues and keep a solid black waveform background.

Native selection metadata still publishes synchronously. A separate task hydrates a saved waveform while audio-source lookup waits. A new native track publishes its real opening waveform before service registration and audio readiness. Background scanning extends the waveform. Load ownership rejects stale previews and clears cancelled work. Audio transport code is unchanged.

The coordinated colour checkpoint supplies the section-coloured waveform, header information and full-width overview with passive time overlays. Its newer colour request sets section colours as the initial style. Playback settings retain the frequency-style alternative.

## Focused verification

- 3,696 geometry assertions pass across control access, panel sizing, dock anchors, deck dividers and browser sizing.
- Four rendered functions cover 13 cases and pass in 37.069 seconds. They cover both decks, 726/1004-point deck widths, 240/344-point deck heights, open/closed Actions, optional controls, black empty states, two browser orientations, the frequency-style alternative and both waveform renderers. FX and Freeze cases verify the Actions anchor.
- Eleven loading functions cover 12 cases and pass serially in 26.351 seconds. They include a held audio source, immediate selection, queued Play, replacement, cancellation and exact other-deck audio samples.
- The package manifest is restored exactly. Final images were inspected. Source hashes and logs are in `result.json`.

The earlier 224-point open-pane render overlapped the header with every optional control enabled. The 240-point minimum corrects this. Text recognition also exposed the small Loop caption, which now uses a larger uppercase label. Earlier geometry expectations used the former 52-point collapsed headers. Updated fixtures check complete compact decks. All failed and incomplete logs remain here.

The colour checkpoint is `572129800`, above preserved compact/native work `4ec3fcaa3`. This chat owns the single combined main iPad build and installation. No additional agent or device session was started.

## Acceptance

Erik checks physical second-deck display timing, progressive waveform display, Actions gestures, compact browser use, colour readability, overview navigation and clean audio. Focused host checks and build success do not establish device acceptance.

# Browser side columns — R02/R04/R25/R30

Date: 4 November 2026, Australia/Brisbane.

Categories, playlists and the detail/prep column now share the library’s panel behaviour. Each has a dedicated 44-point grab strip. Drag to resize, push closed, or flick to close and restore. A slow release keeps a usable width. Each column and orientation retains its own width for the session.

The central list reserves 240 points. In narrow layouts, opening one side can close the other. Its remembered size remains available. Cancelling an opening restores the displaced column. Search temporarily removes the left column without replacing its size. Song selection still opens the detail column. Playlists now use the same bounded layout and can show the selected song’s loader.

Column content remains mounted through resizing. Partial content blocks new touches without disabling a held loader. The loader captures its global frame at touch-down. Column or library motion cannot change its coordinate scale. Explicit close, selected-song replacement and interruption cancel the load gesture. Both direction and end-tap rules remain unchanged.

The detail header keeps its full-size loader while optional artwork yields at narrow widths. The list toolbar has a compact fallback. The performance dock, full-height crossfader, A/B divider, held musical mappings and R34/R35/R37 analysis/preparation match build 87.

## Verification

All 4,303 focused assertions pass. These include 638 browser-column and loader assertions, plus the existing 3,665 dock, library, held-contact, panel and divider assertions. The browser checks cover direct travel, slow settlement, cancellation, independent memory, search, narrow layouts, grab separation, both loader directions and both end taps. A compiled temporary mutation that forgets saved widths fails six assertions. Production source was not mutated.

The harness compiles production sources. A temporary loader copy removes its TDJCore import and uses the exact DeckID declaration from Models.swift. Native module integration requires the signed iPad build. `red.log` retains the missing-interface baseline. `first-check.log` passed the initial 630 assertions. `integration-first-check.log` retains the optional CGFloat conversion error before its correction.

Ruling: migrate the playlist side column with categories and detail in this release. Erik requested the browser side columns as one change. Cost if wrong: physical feedback must identify the affected column.

Ruling: narrow layouts show one optional side column at a time when their minimum widths cannot fit together. Cost if wrong: Erik may prefer a smaller song-list reserve.

Final review: self-review under the project rule against parallel agents. Review covered retained view identity, loader ownership, cancellation, partial input, query/selection state and protected source.

## Erik’s check

1. Show, resize, hide and reopen each browser column.
2. Check separate portrait and landscape widths.
3. Enter and clear a full-library search.
4. Navigate playlists and scroll songs and recommendations.
5. Test both loader end taps and both drag directions.
6. Hold the loader while resizing its column. Close it during a hold.
7. Hold waveform, EQ, filter or FX input while resizing columns.
8. Confirm fixed dock/fader positions and clean audio.

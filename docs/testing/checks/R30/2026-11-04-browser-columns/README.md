# Browser drawer sizing — R02/R04/R25/R30

Date: 4 November 2026, Australia/Brisbane.

Sources and Details now use the library’s panel sizing rules. Each visible drawer has a dedicated 44-point grab lane at its inner edge. Drag to resize or close. A slow release keeps a usable width. A deliberate flick closes or restores it. The existing Sources and Details buttons reopen the remembered width. Widths are separate for portrait and landscape during the session. Sources also retain separate widths for song and playlist navigation.

The R39 full-width browser arrived before compilation. The final integration retains Songs, Suggestions, Prep list, exclusive drawers and the selected-song loading shelf. It does not reserve empty side columns in the list. Navigation, search, queue and recommendation reference state remain separate from drawer sizes.

Drawer content stays mounted through resizing. Partial content blocks new touches without disabling a held loader. The loader captures its global frame at touch-down. Explicit close, selected-song replacement and interruption cancel the load gesture. Direction and end-tap rules remain unchanged. Optional detail artwork yields at narrow widths while the loader keeps its full size.

## Verification

All 4,429 focused assertions pass: the existing 3,687 touch-layout assertions, 638 drawer/loader assertions and 104 R39 navigation/geometry assertions. The sizing checks cover direct travel, exact settlement, cancellation, separate memory, search-context changes, grab separation, both loader directions and both end taps. A compiled temporary mutation that forgets widths fails six assertions. Production source was not mutated.

The harness compiles production sizing, contact and loader sources. A temporary loader copy removes its TDJCore import and uses the exact DeckID declaration from Models.swift. Native module integration requires the signed iPad build.

`red.log` retains the missing-interface baseline. Earlier candidate logs bind the pre-integration source `d589b79f1`, which was never built or installed. `integration-first-check.log` retains the optional CGFloat conversion error before correction. `integrated-green.log`, `full-width-navigation.log` and `integrated-forgotten-width-mutation.log` verify the combined source.

The dock, full-height fader, A/B divider, musical contact sources, R34/R35/R37 analysis/preparation and R39 navigation state match the integration baseline. ReplicaView changes remain confined to the loader.

Ruling: retain the newer R39 exclusive drawers and full-width lists. Apply direct sizing to those drawers. Cost if wrong: Erik may prefer simultaneous side columns.

Final review: self-review under the project rule against parallel agents. Review covered retained identity, input admission, loader cancellation, selection, full-width lists, recommendation reference and protected source.

## Erik’s check

1. Open Sources and Details, then resize, close and reopen each.
2. Check separate portrait and landscape widths.
3. Search Songs, Suggestions and Prep list.
4. Navigate playlists and scroll the full-width lists.
5. Test both loader end taps and both drag directions.
6. Hold a loader while resizing its drawer. Close it during a hold.
7. Hold waveform, EQ, filter or FX input while resizing drawers.
8. Confirm fixed dock/fader positions and clean audio.

## Shortcut integration

Build 90 passed compilation and signing but was not installed. R40’s Performance, Browse and Expand shortcuts arrived during compilation. The final source retains those shortcuts and their 22 additional library assertions. The signed build 90 remains saved. No device operation ran for that candidate.

The final candidate also retains R41’s embedded-framework runtime path repair and the build/deployment dependency checks. Build 91’s launch acceptance record is preserved. iPadOS launch acceptance does not establish continued operation.

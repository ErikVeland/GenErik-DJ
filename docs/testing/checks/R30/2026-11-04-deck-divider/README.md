# Direct A/B deck divider — R02/R30

Date: 4 November 2026, Australia/Brisbane.

A dedicated 44-point grab strip now separates the retained decks. Drag it vertically to give either deck more space. Release keeps the chosen proportion. Portrait and landscape retain separate sizes for the session. Double-tap the strip to restore equal sizes. Accessibility adjustment moves the boundary in 44-point steps.

Library resizing changes the available height without replacing the preferred split. During a divider grab, the state retains its original point position. Cancellation restores the previous balance. A viewport change or scene interruption cancels an unfinished resize. At full library expansion, neither deck can shrink further or overwrite its preferred size.

Both decks retain an A/B label, overview and padded 44-point artwork target at each extreme. The library now reserves 148 points for two 52-point decks and their 44-point divider. Its maximum is 16 points shorter. Existing add-track taps still request the available maximum.

Held waveform, EQ, filter and FX mappings remain unchanged. The overview now uses retained coordinates too. Track replacement cancels its native contact identity. Deck clipping keeps controls within their allocated regions. The dock rendering and full-height fader geometry are unchanged. R34/R35/R37 analysis and preparation match the baseline.

## Verification

All 3,665 focused assertions pass: 1,330 dock, 179 library, 36 held-contact, 1,432 performance-panel and 688 divider checks. The divider checks cover direct travel, exact settlement, independent orientation memory, library changes, cancellation, compact bounds and held mappings on both decks. A compiled temporary mutation that forgets the saved split fails three assertions. Production source was not mutated.

`red.log` retains the missing-interface baseline. `first-check.log` retains two incorrect test expectations outside the valid size range. The test now checks direct travel with enough room for the opposite compact deck. Geometry already enforced its minimum correctly.

Ruling: remember proportions rather than absolute heights. This preserves the deck balance as the library changes height. Cost if wrong: Erik may prefer one deck to retain a fixed height.

Final review: self-review under the project rule against parallel agents. Review covered retained view identity, compact bounds, touch admission, viewport cancellation and protected source.

## Erik’s check

1. Drag the divider to several intermediate positions.
2. Give each deck maximum space and check both compact strips.
3. Resize the library, then reopen the deck space.
4. Rotate and check the separate remembered sizes.
5. Hold waveform, overview, EQ, filter or FX input while resizing.
6. Check effect menus, both button stacks and the full-height crossfader.
7. Confirm that audio remains clean.

## iPad handover

Build 87 compiled, passed signing, then installed and launched on the 10.5-inch test iPad. Application source: `9b41326410293ba7ffc5db6b12fc0ddb3dedf876`. The build record binds the exact source and saved app hashes. No device actions followed launch. Erik’s physical touch and audio checks remain pending.

# Stable colour checkpoint

Status: ready for the loading/compact-deck chat to finish combined checks and own the single main iPad build/install. No iPad build or device operation was started here.

The latest human request in the colour chat explicitly requires the waveform to carry the section colours, section information in the header background, full waveform space below, and time/meta information over the bottom waveform strip. Section colours now default to true. The existing `DeckToolSettings.sectionWaveformColours` key and settings toggle remain, so the frequency-style alternative is still available. Update the earlier preference test to expect sections by default, frequency when false, and sections when true.

The new `SectionColourRenderingTests.swift` passes six cases and 24 images. `final-verified.log` records the result. `result.json` binds it to the exact source hashes. The test uses injected waveform indexes and bands, so it exercises both actual display paths. It checks the header, full-width overview, section colours and clear detailed-waveform top. FX and Freeze offsets are included.

`Replica/Package.swift` is restored. The original `DeckSpaceRenderingTests.swift`, new `DeckBrowserPresentationTests.swift`, compact geometry checks and their evidence remain yours. The extra `.frame(maxWidth: 600)` action-pane line in `ReplicaView.swift` is retained in this checkpoint. Please keep the time overlays passive and preserve the header’s two rows when adapting compact controls.

Remaining work: combine your compact-layout and native-preview checks, merge the committed change to main, build/install once with `tools/ipad_test.py`, record the exact build/source and leave Erik the iPad. Physical readability, section-transition clarity, overview navigation, gesture isolation and clean audio remain open.

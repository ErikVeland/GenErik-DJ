# R09 section colour and deck information

Feedback assumes installed iPad build 109. Erik requests section colours throughout the waveform and header, current-section guidance in the track information area, and time overlays on the overview.

The header has two information rows. Title and artist share the first. Key, BPM, current section and next-event guidance share the second. The current section colours the full header background. A narrow timeline at its top follows the detailed waveform. Its horizontal mapping accounts for the FX panel and the Freeze controls.

The detailed waveform has no section strip or section labels over the audio detail. Both waveform renderers use the existing section palette with three brightness levels. Section colours are the default for this feedback. Playback settings retain the frequency-style alternative. Tracks without section preparation retain their frequency colours.

The bottom overview fills the deck width. Current time, ending guidance and time left overlay it. Dark text backgrounds preserve contrast. The overlays pass touches through to the overview. The waveform and overview keep their existing touch handlers.

Six rendered cases cover both decks with normal, FX and Freeze layouts. Each case checks two viewport positions and both waveform renderers. All 24 images and the source hashes are recorded with the passing result. Failed and incomplete attempts remain here. These are focused render checks, not iPad or clean-audio acceptance.

The pending compact actions and native previews were preserved in commit `4ec3fcaa3`. The loading/compact-deck chat owns those features and the single combined main build/install. This checkpoint retains that chat’s 600-point action-pane width cap. Its other pending tests and evidence remain outside the colour commit.

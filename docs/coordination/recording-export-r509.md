# R509 — Recording exports for 1.0.1

## Product message

Keep the music and the tracklist. Every recorded set must retain the tracks played, their artists and their timings within the recording.

The website now highlights the timed text tracklist saved alongside each recording.

## Current implementation

`SetRecorder` saves AIFF audio and a separate UTF-8 `.txt` tracklist. Track entries use recorded audio frame positions for timing. The browser shows the list, but its share control currently exports only the audio URL.

## Required for 1.0.1

- Offer lossless AIFF, lossless ALAC, MP3 and M4A export options. Label the codec clearly: M4A is a container; distinguish AAC M4A from lossless ALAC.
- Export the timed tracklist alongside the recording as a separate text file.
- Include all available recording metadata in the exported audio. Retain track titles, artists, order and recording-relative timings in the tracklist.
- Store the complete timed tracklist in the custom lyrics tag, using the corresponding lyrics metadata field for each export format.
- Preserve the original recording. Run conversion and metadata writing outside live audio processing. Pause or defer export work before it affects audio or touch.
- Report export failures clearly and retain the source recording and tracklist.

## Verification still required

Implement format selection, encoding, metadata writing and combined sharing. Check exported files with independent readers for codec, duration, metadata and complete lyrics tracklists. Confirm track timings remain aligned after conversion. Test sharing and sustained audio and touch on the A10X iPad. No exporter implementation or device build is part of this copy update.

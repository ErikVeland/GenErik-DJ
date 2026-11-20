# R509 — Recording exports for 1.0.1

## Product message

Keep the music and the tracklist. Every recorded set must retain the tracks played, their artists and their timings within the recording.

The website now highlights the timed text tracklist saved alongside each recording.

## Baseline before R510

`SetRecorder` saves AIFF audio and a separate UTF-8 `.txt` tracklist. Track entries use recorded audio frame positions for timing. The browser shows the list, but its share control currently exports only the audio URL.

## Required for 1.0.1

- Offer lossless AIFF, lossless ALAC, MP3 and M4A export options. Label the codec clearly: M4A is a container; distinguish AAC M4A from lossless ALAC.
- Export the timed tracklist alongside the recording as a separate text file.
- Include all available recording metadata in the exported audio. Retain track titles, artists, order and recording-relative timings in the tracklist.
- Store the complete timed tracklist in the custom lyrics tag, using the corresponding lyrics metadata field for each export format.
- Preserve the original recording. Run conversion and metadata writing outside live audio processing. Pause or defer export work before it affects audio or touch.
- Report export failures clearly and retain the source recording and tracklist.

## Verification scope

Implement format selection, encoding, metadata writing and combined sharing. Check exported files with independent readers for codec, duration, metadata and complete lyrics tracklists. Confirm track timings remain aligned after conversion. Test sharing and sustained audio and touch on the A10X iPad. R509 covered the website copy and requirements. R510 implements the exporter below.

## R510 — Export implementation

Erik requested implementation and logo artwork on 20 November 2026.

- The recording share button opens a format picker: AIFF, ALAC, MP3 at 320 kbps, or AAC M4A at 256 kbps. ALAC is the default.
- Export creates a separate audio file and matching UTF-8 text tracklist. Share audio and tracklist sends both files.
- AIFF copies the original PCM payload. ALAC encodes 24-bit lossless audio. Original recordings remain unchanged.
- Every format embeds the GenErik DJ logo and complete timed tracklist. AIFF and MP3 use ID3 APIC and USLT. ALAC and M4A use iTunes artwork and lyrics fields.
- Export retains available text metadata, including custom fields. The recording filename supplies the title when no embedded title exists. The configured DJ name supplies the artist when absent. The creation date is retained.
- MP3 stores encoder delay and padding in its LAME header. M4A metadata merging preserves the encoder's existing timing fields.
- Export checks cancellation and the performance gate between bounded batches. Starting a performance cancels the export and removes its incomplete files. Export stays unavailable until End Performance.
- The background export uses LAME 3.100 from pinned source `1f5cc9487284d5950343aa5d4f70de433468070a`. Its source, configuration and licence are retained in `Replica/Sources/CLame`. The application notices include the verbatim LGPL text. Release packaging must retain the link inputs needed for relinking with a modified LAME library.

### Verification results

The isolated exporter checks pass for all four formats: readable duration, Unicode title, artwork, lyrics and separate tracklist. AIFF and ALAC decode to exactly the original samples. Apple initially ignored duplicate M4A metadata blocks; merging the fields into the encoder's existing block fixed that failure. Failed checks remain in `TestBuilds/r510`.

The final full-package run compiled the export UI and passed all six test functions (12 cases): four-format exports, exact lossless samples, artwork and lyrics, preservation of source files, interruption cleanup in all four formats, cancellation, metadata retention and oversized AIFF rejection. Every audio batch now has an autorelease pool. The final run includes this change.

Independent ffprobe/ffmpeg checks recover the PNG artwork, Unicode title and full timed lyrics in all four formats. AIFF and ALAC decode to identical samples. MP3 decodes to the original 96,000 frames. AAC retains its iTunSMPB timing metadata; FFmpeg emits 192 trailing padding samples for the two-second fixture. The original content timing is unchanged. Apple reads the exported files successfully.

The first independent ID3 check rejected the empty lyrics-description field without a UTF-16 byte-order marker. Adding that marker fixed the cross-reader failure. Both initial failures and passing results are retained under `TestBuilds/r510`, with output files, a reproducible independent-check script and source hashes. The website build and 358-target link check also pass.

Combined build 233 passed compilation and signing. It installed after Mac device-service recovery, and iPadOS accepted launch. Physical share-sheet checks and sustained-performance acceptance remain open. AIFF size-limit errors direct the user to lossless ALAC. R506 reserves 16 MiB for metadata before recording rollover.

### Combined handover

Erik authorised coordination with “Find 1.0.1 performance gaps”. That chat owns the consolidated commit, merge, build and installation for R506 and R510. This chat leaves both changes intact in the shared checkout and performs no separate device build or installation.

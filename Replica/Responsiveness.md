# Audio and interface scheduling

Audio rendering runs through `TDJNativeAudioSource` into the C transport and recorder. The callback must not allocate, decode, log, access files or wait for another thread.

The serial control producer submits bounded commands. The render consumer acknowledges them and publishes atomic snapshots. Asset disposal, storage and worker joins happen outside rendering. Control maintenance continues when display polling pauses.

PCM read-ahead has its own urgent worker and fixed memory budget. Analysis runs serially at background priority. Library transactions, waveform hydration, artwork and catalog projection use background workers. Live controls take effect before their preparation/history writes finish.

The interface observes control values separately from moving playback state. Waveform indices and band summaries avoid full-track scans during drawing. Beat lines use musical timing directly and do not construct amplitude columns. Immutable library counts must not rescan the catalog during redraws.

See [streaming ownership](PCMStreamingDesign.md), [storage](Storage.md) and [current acceptance](../docs/coordination/release-gates.md). [Earlier measurements](https://github.com/ErikVeland/GenErik-DJ/blob/archive/pre-cleanup-2026-11-04/Replica/Responsiveness.md) retain their exact source and workload limits. Full-session A10X memory, thermal, audio and touch acceptance remains open.

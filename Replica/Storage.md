# Library and waveform storage

Current build and acceptance: [project status](../docs/coordination/README.md). Historical measurements apply only to their recorded source.

The app keeps the collection index separate from full waveform payloads. This prevents collection memory and routine history/grid writes from growing with every waveform bin in the library.

`library.json` schema 2 retains track identity, analysis descriptors, cached performer energy level, preparation, source links and history. Waveform samples live in immutable files under `Waveforms/`, keyed by content identity and analysis configuration. A payload stores explicit little-endian values with format/sample/frame/bin metadata and a SHA-256 integrity check. It does not depend on Swift struct layout.

The app, library service and suggestion CLI use compact snapshots. Only the selected decks hydrate waveform samples, on a separate background worker. The UI combines those samples with current metadata and preparation. The waveform range-index cache remains bounded independently. The compatibility `WorkspaceStore.load()` API still hydrates full snapshots; app code uses `load(includeWaveforms:false)`.

Routine metadata saves retain payload references and do not rewrite waveform files. Performer ranking uses the energy band computed from the original full analysis, preserving the confirmed key → BPM → similar energy → prior pairing ordering. Tests compare full and compact ranking outputs and exact waveform sample round trips.

Schema 1 snapshots remain readable. Their inline waveform data is externalised before a schema 2 index is written. The first replacement retains the previous library file as `library.before-waveform-storage.json`. New payloads are written atomically before the index can reference them. A failed write leaves the previous index intact; orphaned newly created cache files are harmless. Legacy migration still decodes the old snapshot once, so very large legacy files retain a one-time memory cost during migration.

Missing or corrupt waveform caches can be rebuilt asynchronously from the retained private audio copy. Rebuilds share the serial analysis worker and must match the stored content, implementation, configuration, rate and frame/bin format. They preserve stored BPM, key, energy summary, grids and cues. An incompatible analysis version or unavailable source reports an error instead of replacing preparation.

A deck becomes ready after PCM preparation and renderer acceptance. Waveform hydration or rebuilding continues independently and cannot hold Play disabled. The waveform shows a preparation message until its samples arrive. Its load-history save joins the background history queue and cannot hold Play disabled. Background library completions are adopted only if their revision is at least as new as the current state.

`Validation/waveform-storage-tests.log` covers exact samples, ranking/energy parity, backup migration, corruption/path rejection, unchanged payloads during metadata edits and index size independent of waveform length. `storage-preparation-recovery-tests.log` covers rebuilding missing payloads and continued transport control during background preparation. `load-readiness-storage-tests.log` covers Play while history persistence is deliberately stalled. `audio-ready-before-waveform-tests.log` also covers Play while a missing waveform waits behind deliberately stalled analysis. The combined 156-test run passes in `eleven-effects-waveform-priority-full-tests.log`.

Payload hydration requires the exact number of bins implied by the retained frame count and bin size. An empty or shortened payload is rejected even with a valid checksum. All six storage checks pass in `waveform-cache-completeness-tests.log`, including missing-cache rebuilding.

This storage change reduces waveform working memory and write amplification. Production deck playback now uses a separate fixed PCM pool and background read-ahead, described in [Responsiveness.md](Responsiveness.md). The mapped-cache API remains for numerical reference tests. This does not establish target-iPad memory, page-residency or thermal acceptance. No original NI files or audio sources are rewritten.

## Versioned musical metadata

Compact schema-2 analyses retain automatic downbeat offset/confidence, musical energy, tuning, key stability and grid residual metadata when available. Waveform rebuilding preserves those detected values. Reanalysis is separate and keeps manual grids/key overrides and performance preparation; legacy energy remains until reanalysis replaces its older estimate. Automatic downbeat unknown is not a detected zero offset. See Analysis.md.

## Original TDJ preparation provenance

Optional per-track Traktor provenance retains the raw entry, collection digest, native matching identity, mapping profile and normalised reference independently of detected analysis. Complete original references may have waveform-only analysis with `musicalAnalysisDeferred`; their absent energy remains unknown. Waveform rebuilding preserves this flag. Original bytes are retained in immutable digest-named archives under `TraktorReferences/`, with an atomic active pointer. Library preparation is committed within `library.json`; cues and deletion history are materialised idempotently by the performance owner and saved together in `performance.json`. See [original preparation import](TraktorPreparation.md).

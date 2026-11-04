# Bounded PCM streaming

Production playback uses fixed PCM pools instead of reading a whole-file mapping in the audio callback. Reference tests can still use mapped or in-memory assets.

Each asset has 512 blocks of 8,192 stereo Float32 frames: 32 MiB. The global 128 MiB cap includes active, replacement and retiring assets. A descriptor table can reference 240 blocks. Three preallocated tables allow preparation, adoption and retirement without callback allocation. Transport, keylock and FX storage have separate bounds.

The worker fills mandatory ranges for audible playback, loop wraps, queued starts, Flux returns and accepted controls. Optional cue warming has lower priority. Required ranges must fit the published table. A capacity or I/O failure cannot silently discard mandatory audio.

Published tables are immutable. The renderer adopts a complete table at a callback boundary and returns the previous table through a bounded retirement mailbox. The worker reuses blocks only after retirement. A full mailbox retains the current table rather than waiting in the callback.

A command's generation, preparation ticket and source coverage must match the live request. Readiness alone cannot authorise an old load or speed change. Output startup checks the renderer's adopted coverage against the host's maximum callback size. Route changes and cancellation invalidate pending startup.

A missing read increments telemetry and uses the bounded fade path. It never triggers a file read, allocation or blocking repair inside rendering. Disposal waits for asset retirement, then stops the worker and closes/frees resources on a background queue.

The current contracts are in `Sources/CTDJTransport/include/TDJStreaming.h`, `Sources/TDJCore/PCMStreaming.swift` and `Sources/TDJCore/OutputSourcePreparation.swift`. Run `Scripts/check-streaming-native.sh` for focused ownership and handoff checks. [Earlier design iterations and failures](https://github.com/ErikVeland/GenErik-DJ/blob/archive/pre-cleanup-2026-11-04/Replica/PCMStreamingDesign.md) remain available separately.

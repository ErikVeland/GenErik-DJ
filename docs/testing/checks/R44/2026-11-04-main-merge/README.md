# R44/R46: waveform merge and main build

Erik requested the waveform fix on `main` and a new iPad build from that source.

Merge `faa089d99bd7c87de6e4e89a8a9c58006e3109e0` includes the waveform branch and its R45 immediate-loading changes. It preserves the consolidated main workflow, R46 ledger entry and historical evidence. The ledger conflict retained both sets of requests. No application source required conflict resolution.

All 93 motion assertions pass on the merged files. Native direct-drag, held-stop, reversal, Flux, EOF and existing Scratch checks pass at 44.1, 48 and 96 kHz. The complete application source matches build 103 after the pinned vocal model was restored from the local cache. Historical logs retain their raw whitespace. The source and documentation whitespace check passes when those logs are excluded.

Fresh build 104 used clean `main` in `/Users/veland/GenErik DJ`. Compilation, framework resolution, signing and source/archive identity checks pass. The saved app installed on the 10.5-inch test iPad. iPadOS accepted the launch request. Device actions stopped immediately.

Physical feel, listening and continued operation remain Erik’s acceptance tests. The broader R46 inventory and uncommitted historical R43 work remain outside this focused handover.

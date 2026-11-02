# Small iPad test releases

Request R21 now uses [Erik’s minute-scale iPad loop](../testing/README.md). That is the current policy and command reference.

Erik tests, reports a bug or feature, and this chat makes one focused change. Build the iPad app incrementally, install the saved output and hand control straight back. No Mac builds, simulator runs, routine full regression sweeps or parallel agents.

`Replica/Scripts/release-ipad.sh` remains a compatibility entry point. It calls `tools/ipad_test.py` and uses the same existing cache, numbered app archive and build records. It no longer starts a separate build pipeline.

A request to build, update or deploy to the test iPad authorises that operation. Respect an explicit testing hold or active performance. Full gig acceptance does not block a personal test build.

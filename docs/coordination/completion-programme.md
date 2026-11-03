# Completion programme

Erik requested completion of all remaining app work and integration with all NI controllers and class-compliant MIDI controllers, including Serato, Pioneer DJ/AlphaTheta and other controller ecosystems. A hardware bridge is allowed. The available controller is the original Z1, which has first priority. This programme preserves the minute-scale iPad feedback loop.

## Deliverable order

| Work | Concrete deliverable | Completion boundary |
| --- | --- | --- |
| Installation and feedback | A numbered app installed and opened, with saved source/output identity | Build 45 was installed, then replaced by Scratch build 46. Controller build 49 is prepared only. Erik performs acceptance testing. |
| Controllers | Shared input/action layer, learn UI, then Z1 direct/bridge transport, then model adapters | Generic MIDI note/CC feedback can now be configured per action and output destination. Use `controller-coverage.md`. Connection, verified model mappings, feedback and audio remain separate. Do not claim all models from generic MIDI support. |
| Key governance | Native iPad import, review/conflict UI, verified source attribution, then external collection write-back | The Library page reviews governed JSON and batches ID3 Initial Key fields with explicit source/track confirmation, exact content identity and loaded-track protection. Mixed In Key project exports and Traktor Pro write-back still need representative files and verified mappings. Preserve corrections, backups and unknown provenance. |
| Musical structure | Real-song section/vocal/drop/ending analysis feeding existing landmarks and countdowns | Needs a suitable analyser and reference-labelled evaluation. Do not substitute loudness guesses for semantic recognition. |
| Recovery | Reliable replay and incoming-track transitions using validated/manual drop/ending evidence | Erik verifies timing, fallback and manual takeover on the actual iPad. |
| Key control and stems | Key shift/matching, prepared stem workflow and controller access | Preserve timing and playback continuity. Report A10X processing costs and any preparation/offline requirements. |
| Remaining roadmap | Stems, controller feedback profiles, semantic phrase guidance and specified FX additions | MIDI Learn, manual arrangement editing, next-event guidance and six FX slots already exist. Define separation models, feedback contracts and requested FX before adding more. Keep automatic section recognition with the R09 evidence gate. Erik deferred streaming on 3 November; preserve the local-library-only scope. |
| Polish and reliability | Resolve Erik's reported issues in the sound, touch workflow, library, recording and UI | One focused fix/build/test at a time. Erik confirms each result. |
| Historical reconciliation | Disposition every meaningful private patch/request | The present checkout can compare inventory hashes but does not contain the private source folders. Restore the candidate source before assigning semantic dispositions. Keep original evidence. |

These deliverables remain open until their stated evidence exists. This document does not certify that all unfinished software, models, hardware or external integrations are complete.

## Build rules

Keep build 45 available while preparing the next change. Do not replace the iPad app while Erik tests it. Build only the requested iPad increment. Use focused protocol checks when a decoding defect could trigger a wrong action. No routine Mac app build, simulator run, full-suite sweep or parallel agent is added.

## External dependencies

- Full acceptance for unowned controllers requires their hardware or reproducible captures and later physical confirmation.
- Native protocols need verified public information, actual device observations or vendor access. Unknown reports must not be mapped speculatively.
- A bridge requires actual USB host/device hardware and its model adapters. Permission to use a bridge is not evidence that it exists.
- Semantic music analysis needs a viable model/algorithm and real-song reference material. The current hand-labelled display is not that analyser.
- External metadata write-back requires representative target-format files and identity/conflict checks. Do not overwrite real preparation while guessing a format.
- Streaming is deferred by Erik. Keep the product local-library-only unless he changes that decision.

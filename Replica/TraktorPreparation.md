# Original Traktor DJ preparation import

Implemented for the internal development app on 30 October 2026. See [current status](Status.md) for overall readiness. The physical iPad workflow remains unverified.

## Use

Choose **Import Traktor preparation** in the development toolbar menu, then select the original `collection.nml.gz` or uncompressed `collection.nml` through Files. The iPad needs this one-time grant to a collection copy: it cannot open another app's private container. Preparing songs afterwards uses the iPad's own Music library, without requiring a running Mac or an audio-file export.

The Mac app also discovers the conventional locally synced TDJ iCloud collection when no collection is already selected. Both platforms discover an app-owned `TraktorReferences/collection.nml.gz` or `collection.nml`. A selected collection remains active across restart; use the import command to select a newer export. Discovery does not continuously replace a selected reference with a changing iCloud file.

On discovery or explicit import, already prepared native-library items can acquire original preparation without decoding their audio again. Currently loaded tracks are excluded from that application pass. New native-library imports with complete supported preparation generate a waveform and retain the original musical preparation separately, avoiding the independent BPM/key/downbeat analysis. Incomplete or unverifiable preparation uses the independent analyser. Standalone audio imports have no native identity and are not matched by title or filename.

## Identity and field mappings

Only original `NML VERSION="17"` with `HEAD PROGRAM="Traktor DJ"` is supported. This is a TDJ1 collection reader, not a general Traktor Pro importer.

| Field | Current interpretation and guard |
| --- | --- |
| `ITUNES/PERSISTENT_ID` | Exact 16-digit hexadecimal UInt64, matched to the native Music adapter's decimal UInt64. Duplicate or conflicting identities are unresolved. |
| `ITUNES/PLAYTIME` | Milliseconds; decoded duration must agree within 0.1%, with a 250 ms floor and 2 s ceiling. Missing duration prevents application. |
| `TEMPO/BPM` | Finite positive tempo, at most 1000 BPM. |
| `CUE_V2 TYPE=4 START` | Milliseconds; a single distinct supported grid origin becomes the prepared bar origin. Distinct competing origins remain unresolved. |
| `MUSICAL_KEY VALUE` | Mapping profile `tdj-nml17-ms-zero-based-key-v1-single-grid`: 0–11 C–B major, 12–23 C–B minor. Unknown codes, including 1001, remain unknown. Physical TDJ display comparison is pending. |
| `CUE_V2 HOTCUE=0…7` | Supported cue/grid/loop types 0/4/5 use START milliseconds; loops require valid LEN milliseconds. Duplicate, negative or out-of-file positions reject application for that track and produce a warning. Raw markers remain archived. |
| Other fields | Retained in the raw entry and original collection, without inventing behaviour. |
| Energy | Not present in these exports. Waveform-only imports leave energy unknown until explicit independent reanalysis. |

Native IDs can change after a library migration. Exact ID plus duration establishes a supported library-item match; NML contains no audio SHA-256 and does not prove historical audio bytes are identical. The current imported audio's hash, sample rate and frame count bind the normalised preparation to that retained media. No fuzzy title match is performed.

An imported grid is prepared reference data. It is not labelled as a successful automatic downbeat detection. The original app build is not exported in these files; do not label the collection as verified 1.6.8.67 output.

## Preservation and storage

Original files are read-only. A bounded, cancellable background reader validates the complete XML/gzip document before activating it. It rejects entities/DTD, inconsistent counts, corrupt gzip, trailing or concatenated members and resource-limit violations. Paths inside the collection are never followed.

`TraktorReferences/<SHA256>.collection` retains the original bytes; `current.json` atomically selects a validated archive. A failed replacement leaves the previous selection active. Each matched track retains the collection digest, raw entry and index, native source identity, mapping profile and normalised preparation in the atomic library snapshot. Detected analysis remains a separate object; waveform-only results explicitly mark musical analysis deferred.

Imported grid/key values respect existing manual corrections and remain protected during explicit reanalysis. Cue materialisation occurs on intentional deck load, through the performance-state owner. Cue slots and import history are saved together in `performance.json`; occupied slots, deliberately empty existing banks and deletions of previously imported cues survive restart/reimport. An unassigned original grid marker does not become an invented hotcue. Library preparation and cue materialisation are separate, idempotent operations, avoiding a cross-file commit requirement.

## Real data and verification

The original iCloud documents were read unchanged and copied into a private validation workspace. Both complete collections passed the production inspection and import paths; retained archive bytes equal their inputs.

| Collection | Entries / unique native IDs | Complete musical-reference candidates | Records with warnings |
| --- | ---: | ---: | ---: |
| Current `collection.nml.gz` | 5,995 / 5,995 | 5,521 | 216 |
| Older `collection.nml copy.gz` | 10,881 / 10,881 | 10,809 | 46 |

Candidate counts precede actual audio-duration/position validation; they are not successful audio matches or accuracy measurements. The current collection contains 21 ordinary cue markers and 5,959 grid markers; the older collection contains two ordinary cues and 10,887 grid markers. Neither contains exported saved loops, so loop support is synthetic-test coverage only. Some current cue positions are negative and remain unsupported.

The 27 focused reader, gzip, background, merge and integration tests pass. They cover exact identity, duration mismatch and fallback, original-byte retention, invalid replacement, waveform-only preparation, independent reanalysis, existing-track reuse, loaded-track protection and cue deletion across restart. Paired end-to-end audio checks use explicitly synthetic reference data. Real collection parsing/import is verified; ten real paired-audio comparisons have not been completed.

The interface cross-compiles for ARM64 iOS simulator and device. The app wrapper also compiles and links into an unsigned ARM64 iOS 17 bundle. Normal Xcode app builds are separately blocked in this sandbox by manifest-cache/package-resolution access; the retained manual link is not a signed install or runtime test. Physical device-service access was denied and sandbox approvals are disabled. No physical iPad acceptance is claimed.

Evidence: `Validation/TDJPreparationIntegration-2026-10-30-01/`. Full regression outcome and source correspondence are recorded there.

## Command line

```sh
.build/debug/tdj-tool inspect-traktor /path/to/collection.nml.gz /path/to/report.json
.build/debug/tdj-tool import-traktor --workspace /path/to/workspace /path/to/collection.nml.gz
```

Inspection includes ten complete example records, with raw fields and source provenance. These are candidate references, not ten matched audio comparisons. An automatic per-track comparison report and physical iPad matching/listening acceptance remain open.

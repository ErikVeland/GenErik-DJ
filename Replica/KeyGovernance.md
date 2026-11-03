# Key governance

The selected key follows this authority order:

1. Manual correction.
2. Mixed In Key result with declared attribution.
3. Imported Traktor preparation.
4. Independent analysis.

An independent confidence score cannot override Mixed In Key. Unknown tags remain evidence for review and cannot select the key. Energy, grids, and cues keep their existing policies. Mixed In Key authority for key detection does not grant authority over those fields.

## Import and review

`KeyImportManifest` is a GenErik interchange format. It is not a native Mixed In Key export format. An adapter or a person must supply the source attribution and exact existing content SHA256 identities. The current app hashes complete source files. Retagged files can have different identities and need a new verified match.

Attribution is a recorded declaration. It does not authenticate a vendor or prove key accuracy. Use `userConfirmed` after checking the source, or `documentedExport` for a validated adapter. Use `unknownTag` and `unknown` when the producer is unclear. A copied result is never independent corroboration. The policy does not count votes.

The manifest contains `schemaVersion: 1`, `source`, `attribution`, `sourceDescription`, optional `producerVersion`, and `entries`. Each entry contains `contentSHA256`, `rawKey`, and `notation`. Supported notation names are `camelot`, `openKey`, and `musical`. Supported sources are `mixedInKey`, `traktor`, and `unknownTag`.

The Library review can read ID3 Initial Key tags from multiple selected audio files through AVFoundation and create one governed manifest. The user must confirm that the results came from Mixed In Key and match the listed tracks before Apply is enabled. Each selected audio file must have the exact content SHA256 of an existing library track. Retagging changes that identity; import the tagged audio into the library first. Identical files with different key tags are rejected. This path does not read arbitrary comments, custom fields, Mixed In Key project files or Traktor Pro collection exports. ID3 metadata identifies a field, not the software that wrote it. See [Mixed In Key tag options](https://mixedinkey.com/workflows/add-key-and-bpm-tags/) and [Apple's ID3 Initial Key identifier](https://developer.apple.com/documentation/avfoundation/avmetadataidentifier/id3metadatainitialkey).

The importer rejects missing tracks, invalid notation, duplicate identities, unsupported schemas, and missing attribution for named producers. The entire batch must validate before any library change. Input size is limited to 2 MB and 10,000 entries.

Preview through `LibraryService.previewKeyImport(data:)`. Apply that exact plan through `applyKeyImport(_:preservePreparationFor:)`. An intervening revision or target-track edit invalidates the preview. Callers must supply active or protected track identities. The service rejects imports affecting those tracks.

The command-line routes are:

```text
tdj-tool key-governance --workspace DIRECTORY
tdj-tool preview-key-import --workspace DIRECTORY MANIFEST_JSON
tdj-tool apply-key-import --workspace DIRECTORY MANIFEST_JSON EXPECTED_REVISION MANIFEST_SHA256
```

Take the revision and manifest digest from the preview. Close the app before command-line changes. Storage assumes one writer. The preview checks do not provide locking between separate app processes.

The first attributed Mixed In Key observation becomes the accepted Mixed In Key observation. Conflicting later imports retain the accepted selection and request review. Repeated identical manifests do not add evidence or advance the revision. All imported raw values, normalised keys, source descriptions, declared producer versions, and manifest digests remain in workspace storage.

`LibraryService.reviewKey(trackID:key:reason:expectedRevision:preservePreparationFor:)` records a manual selection with a required reason. It rejects stale revisions and protected tracks. Manual selections suppress the pending-review flag while retaining the conflicting evidence. Existing preparation editing remains available and records key changes separately.

## Analysis and compatibility

`Track.key` uses the governance decision, so existing browser and suggestion consumers receive the selected key. Detected analysis stays separate. Analysis replacements retain the previous and new key, implementation, configuration, and confidence in the governance history. They cannot displace a manual or Mixed In Key selection.

New Traktor imports retain a Traktor authority marker. Independent opening-minute hints retain an independent marker. Direct key corrections clear the imported marker. Existing archives without a marker remain protected as legacy corrections because their authorship cannot be recovered safely.

Workspace writes validate retained governance state. The app appends governance history through its normal atomic library save. This is a local audit history, not a tamper-proof log.

## Gates for later implementation

Automatic overrides require a separate policy change. That change needs independent reviewed reference tracks, a defined validation corpus, calibrated confidence, measured error rates, and regression evidence. Synthetic confidence scores and copied results cannot satisfy the gate.

Direct Mixed In Key extraction, Traktor Pro field mappings, and external write-back adapters are not implemented here. The existing NML importer still accepts its supported Traktor DJ version 17 profile. An external writer must verify its format and track identity, preview field changes, check the target against its imported base, preserve manual cues and grids, retain a backup, and verify the resulting file. Default authority rules do not authorise automatic external writes.

Production use requires focused governance tests, import and preparation regressions, and combined project verification. A passing policy test does not establish detector accuracy or safe external synchronisation.

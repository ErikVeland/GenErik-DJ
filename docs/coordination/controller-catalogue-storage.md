# R452 — Controller catalogue storage

The current controller resource uses4,157,594 bytes of its4MiB limit. More documented profiles must fit without increasing that limit.

Keep the existing full review JSON as generator output and source-test evidence. Exclude that file from the application bundle. Generate a second JSON resource with shorter input-field names and omitted default values. Remove only profile metadata that the native decoder already ignores. Preserve scope, source, aliases, every control value and every setup packet.

The native input decoder accepts full review fields and the compact form. A compact row requires action, channel and number. Its documented defaults are Note, absolute encoding and non-inverted input. Optional fields retain their current nil/false distinctions. Reject rows that mix recognised full and compact field names. The full form retains its required fields.

Keep the existing4MiB resource limit,512-profile limit,512-input limit,128-output limit and all protocol validation. Do not add compression libraries, setup commands or UI changes. No network or decompression occurs during connection. Do not activate the previously ignored layerIndependent input metadata as part of this change.

Prove that all377 review recipes remain unchanged. Expand the generated compact fields in source tests and compare every profile/input/output/setup value. Native tests must cover both forms, defaults, every optional field, malformed data and held Cue across the catalogue. Compile the iPad framework and compare the bundled compact resource with the generated file. Physical/iPad/A10X timing remains unverified.

## Field contract

| Full input field | Compact field |
| --- | --- |
| action | a |
| kind | k |
| channel | c |
| number | n |
| encoding | e |
| inverted | i |
| targetDeck | d |
| anyChannel | w |
| argument | g |
| releaseOnly | r |
| requiredMode | m |
| shifted | s |
| shiftInput | t |
| holdInput | h |
| shiftChannel | z |
| lowNumber | l |
| pulse | p |
| requiresTouch | u |
| directionStep | v |
| deckBank | b |

The producer retains previously ignored layerIndependent metadata without activating it. Unknown new input fields stop generation until the compact contract includes them. Only absent compact kind/encoding/inverted fields receive defaults. Explicit null values for these required fields remain invalid.

## Verification

The full review file remains at `Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json`. SwiftPM excludes it from the application resources. The generator also writes `factory-controller-profiles.compact.json`, which the native catalogue loads. Both generation and native decoding retain the4MiB application-resource limit.

The generated application file uses2,051,892 bytes. The unchanged full review table uses4,157,594 bytes. Source tests expand every compact field and compare all377 recipes, including outputs and setup bytes. Native tests compare all24,689 resulting bindings and cover every optional field, defaults and malformed rows.

All375 source checks and40 focused native tests pass. The iPad framework compiled. Its bundle contains the exact compact file and excludes the full review file. The native Mac test cache retains an obsolete, unconsumed review asset. This does not establish its inclusion in the current iPad bundle. The pre-existing original-Spin test now rejects aliasing to original Spin while allowing the separate supported Spin2 profile.

Failed checks and their corrections remain in `TestBuilds/r452/validation.json` and its referenced logs. Physical/iPad/A10X timing and hardware acceptance remain open.

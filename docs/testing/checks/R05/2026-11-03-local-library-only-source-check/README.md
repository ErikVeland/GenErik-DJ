# R05 local library source check: 3 November 2026

Application source: `8f61c05d07c82f919206e190a8eba36b5c83fd34`.

Changed source diff SHA-256 from `07e2e14`: `f88d49394d95086093af5a4aee7aa1df617c0ca010a73857afcada255b72ce03`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | All 11 changed Swift files parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The R05 request ledger passed the skill linter. |
| Signed iPad build | BLOCKED | `tools/ipad_test.py build` needs a signing team and device ID or ignored `TestBuilds/ipad/config.json`. No iPad was accessed. |
| Type-check and tests | NOT RUN | The signed build did not start, and no tests ran. |

The catalogue admits an item only when it has an available audio asset URL for the platform. On iOS, an `ipod-library` asset URL marks a local item. Cloud entries without an asset URL stay out of the library and its playlists. Import, native loading and background analysis use the same local-item rule. The iCloud flag alone does not prove that an item lacks a local asset. Apple defines that flag as an iCloud Music Library item indicator: [Apple MPMediaItemPropertyIsCloudItem](https://developer.apple.com/documentation/mediaplayer/mpmediaitempropertyisclouditem).

## Next evidence

Review the local track list and playlists on the authorised iPad build. Confirm cloud-only, streaming and downloadable-only entries do not appear. Confirm downloaded local files remain visible. Erik's device check remains pending.

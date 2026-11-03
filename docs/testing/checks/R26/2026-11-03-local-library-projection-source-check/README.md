# R26 local library projection source check: 3 November 2026

Application source: `ef1a7007eccce896e2886d429cad655c4bd13a5c`.

Changed Swift source diff SHA-256 from `8f61c05`: `d95db036f1a0deefe3d4d8e527817356a2ab4ef3961b6b947f6d1f5a6423b6e6`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The library and collection projection files parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The request ledger passed the skill linter. |
| Type-check, app build and tests | NOT RUN | The available Swift compiler does not match the installed iOS SDK. No tests were requested. |
| Device check | PENDING | Erik owns the iPad library review. No device was accessed. |

The catalogue now removes non-local playlist members and playlists with no local songs. The main collection, search, recommendations and custom playlist views omit native-only tracks unless a current catalogue item has an on-device audio asset. The projection changes do not delete saved preparation.

## Next evidence

On the signed iPad build, confirm that cloud-only and downloadable-only songs stay hidden, local files remain visible, and saved preparation remains available after a library refresh.

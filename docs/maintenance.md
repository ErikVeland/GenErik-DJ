# R48 cleanup

The active tree removes 888 historical/generated paths. The complete tracked baseline is preserved under `archive/pre-cleanup-2026-11-04`. About 98 GiB of local evidence, private candidates, backups and retired builds moved to the [external archive](history.md). This was relocation, not a claim of freed disk space.

Current documentation has one status entry point, a shorter request ledger and working links to historical records. Generated logs and duplicate icon exports are no longer tracked. Twenty-eight merged local branch references were removed after verifying their ancestry. Their exact references remain in the external archive. No history was rewritten.

First-party Swift and native source uses consistent formatting. Vendor code, model assets, licences and workspace data are preserved. Catalogue counts no longer scan/copy rows during picker redraws. Search avoids intermediate arrays. Footer counting avoids temporary row arrays. Existing MIDI test compilation errors are repaired.

Verification: 31 focused Swift tests, 4,484 geometry assertions, five loading-order checks, native transport checks at 44.1/48/96 kHz, script syntax, documentation links and Git connectivity pass. Logs remain in `TestBuilds/r48/`. Full-suite and physical A10X acceptance are not claimed.

An attempted Git repack exhausted temporary space. Its incomplete temporary pack was removed. Finder metadata inside Git refs was also removed, and connectivity then passed. A filter-cache experiment showed no reliable gain and was discarded. The formatter's conditional-directive issue was corrected before the passing build checks.

Signed main source `4cdd0b927` produced build 112. Its application fingerprint matches the checked source. Signing and framework resolution passed. Installation succeeded, and iPadOS accepted launch. Device actions stopped. The first cache-path failure is preserved in the build record. Physical A10X acceptance remains open.

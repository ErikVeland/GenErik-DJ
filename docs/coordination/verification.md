# Combined candidate verification

Date: 2 November 2026, Australia/Brisbane.

Application source tested: `335cec6b77644f23d43c08fc236ba9d7db446a17`. Later coordination commits change documentation only. `integrated-source.json` retains application, test, script and iPad-project hashes.

## Results

| Check | Result | Scope |
| --- | --- | --- |
| `bash Scripts/check.sh -c release --no-parallel` from `Replica` | PASS, exit 0. 688 tests in 9 suites, 153.489 seconds of test execution. | Combined package regression. Does not complete sustained audio or physical acceptance. |
| `bash Replica/Scripts/build-ipad-app.sh` | PASS, exit 0, `BUILD SUCCEEDED`. | Complete generic iPad simulator Release app. No physical device selected or operated. |
| `bash Replica/Scripts/package-mac.sh` | PASS, exit 0. | Packaged Mac application. |
| `codesign --verify --deep --strict` on packaged Mac app | PASS, exit 0. | Package signature integrity. Not a notarisation or physical iPad check. |
| Packaged-app empty-workspace snapshot | Render completed, exit 0. Visual acceptance OPEN. | Browser fits the 1024×768 render. Search-field rendering anomaly requires investigation. No loaded decks or real-library display accepted. |
| Pre-integration shared feature contents | PASS. No changed/new feature file differs from its backup after integration. | Documentation excluded. Browser conflict resolution concerned a separately committed file. |
| Branch ancestry | PASS. Remote main, beatgrids, reverb and full-library-search heads are ancestors of the combined source. | Proves commit inclusion, not full behavioural equivalence. |
| `git diff --check` and coordination JSON parsing | PASS before final documentation commit. | Formatting and record integrity. |

The earlier waveform run's streaming-capacity failure and Recovery run's governance compilation blocker remain historical failures. They did not fail this combined serial run. Their exact original causes are not established by the later pass.

Compiler output retains an existing unused-binding warning in `Z1Protocol.swift`. It did not block these builds and was not changed during consolidation.

## Outputs and evidence

- Mac app: `Replica/Build/GenErik DJ Development.app`.
- iPad simulator app: `Replica/.build-xcode/Build/Products/Release-iphonesimulator/GenErikDJ.app`.
- Local snapshot: `Replica/Build/ProjectIntegration.png`.
- Full logs: `Backups/Coordination-2026-11-02/verification/`.
- Log SHA-256 identities: `verification-logs.json`.
- Source fingerprint: `1922454ca5670fb870c52dff1868b14cd00db6c540aaef172943aca2513014e7`.

Build products and full logs remain local under existing ignore rules. Source identities, outcomes, limitations and log hashes are tracked in Git.

## Still required

Complete the source-bound audio workloads, physical A10X checks, real-music listening, visual inspection and Erik's rehearsal in `release-gates.md`. No combined build was installed on the iPad. This report does not establish gig readiness.

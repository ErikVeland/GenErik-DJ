# Small iPad test releases

Request R21. Target: one small change, focused checks, then feedback on the iPad. Aim for five minutes with a warm build cache. Measure the actual time before claiming that target is met.

## Release loop

1. Finish one small change on the active integration branch.
2. Run checks for the changed behaviour. Build the iPad app for shared Swift or C changes.
3. Commit the change with its request ID and check result.
4. Run the release command during the authorised test session.
5. Check that behaviour on the iPad. Record the result before the next change.

From the repository root:

```sh
./Replica/Scripts/release-ipad.sh DEVICE_ID TEAM_ID
```

Use the known test iPad device ID and Apple signing team ID. The command updates `org.generikdj.replica.audiocheck`, displayed as **GenErik DJ Test**. It retains that app's data container. It installs the normal player, not the automated audio-validation harness.

The command builds Release incrementally, verifies signing, installs and launches the app. It uses `.build-micro-release` for its cache. Do not clean that cache between small releases. Initial compilation and signing setup can take longer.

Add `--build-only` to prepare the signed app without installing it. Signing requires a configured Apple developer account. A failed build, signature check or install stops the command. Source changes during compilation also stop installation.

Each run retains its source revision, device, status and logs under `Replica/.build-micro-release/releases/`. The app plist also records `TDJSourceRevision`. The script requires a clean checkout so the recorded revision identifies the source.

## Checks that fit the change

For a visual change, build and inspect the affected screen. For transport or DSP changes, run focused regressions and the relevant short audio workload. Run the complete regression suite when combining branches or changing shared behaviour with broad impact. Keep sustained performance checks for milestones and gig acceptance.

Do not wait for historical candidate reconciliation, unrelated feature completion, paired TDJ1 comparisons or full gig rehearsal before releasing a focused test build. Preserve those requirements in their existing records.

A request to update the test iPad authorises installation for that request. Respect an explicit device hold or active performance. Do not request the same approval again within an authorised test session.

## Acceptance labels

- Built: compilation and signing passed.
- Installed: the device accepted the app.
- Checked: the changed behaviour passed its stated check.
- Gig accepted: the full release gates and Erik's rehearsal passed.

A test build can have known issues. Record them clearly. Do not label it gig accepted from compilation or installation alone.

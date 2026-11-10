# Erik's minute-scale iPad test loop

Erik is the sole developer and acceptance tester. This chat implements his requests. Other project chats stay stopped. iPad is the only active target until Erik says otherwise.

Build from `main` in `/Users/veland/GenErik DJ`. This is the single consolidated test source. Make one change at a time on a short-lived feature branch in the same folder. Commit and merge it into `main` before building. Historical worktrees are inactive archives.

1. Erik tests **GenErik DJ** on the iPad.
2. Erik describes a bug or requests a feature here.
3. This chat records the report against the build and makes one focused change.
4. This chat builds the iPad app incrementally, installs that saved app and reports its number.
5. This chat leaves the iPad alone. Erik tests again.

Feedback is ordinary conversation. No form is required. The build number is in **Settings → About**. If Erik omits it, use the last installed build and state that assumption.

## Keep it fast

- Reuse the single existing device-build cache. Target minutes, not a scheduled daily cycle.
- Run no routine Mac packaging, simulator builds, full regression sweeps or parallel agents.
- Make the requested change. Do not start unrelated fixes or backlog work between reports.
- Use the compiler/signature checks required for the installable app. Add a focused check only when the specific change needs it.
- Keep broad release qualification separate and user-directed.
- The reverb qualification workflow is manual-only. Routine pushes must not start the old Mac/simulator validation pipeline.
- Install when Erik hands over for the next test. After launch, stop device actions immediately. For work specific to a controller Erik cannot test, keep verification off the iPad.

## Operator commands

Build, install and hand back:

```sh
python3 tools/ipad_test.py run --notes "Fix the issue Erik reported"
```

Prepare while Erik continues testing:

```sh
python3 tools/ipad_test.py build --notes "Fix the issue Erik reported"
```

Install an exact saved build without recompiling, including a rollback:

```sh
python3 tools/ipad_test.py deploy --number 45
```

The established test-app identity stays `org.generikdj.replica.audiocheck`. The app is updated in place. The script never uninstalls it or accesses the original Traktor app.

Ignored `TestBuilds/ipad/config.json` holds `team` and `device`. Signed apps and logs stay under ignored `TestBuilds/ipad/`. Build records are tracked under `docs/testing/builds/`. Previous local build 44 is archived before the first new build. This does not claim build 44 is known-good. App rollback does not reverse changes to library/preparation data.

Record feedback, fix commits and Erik's result in the corresponding build record. A reported issue remains open until Erik confirms the fix. Commit changes and records on the feature branch. Merge them into `main` and push before handover. `feature/project-integration` is a historical branch, not a separate test source.

## Requested TestFlight builds

Use this path only when Erik requests a TestFlight build. It leaves the installed iPad app in place.

Prepare a numbered archive and App Store distribution package from committed main:

```sh
python3 tools/ipad_test.py testflight --notes "Describe the requested TestFlight change"
```

Retry export of the same archive after resolving a signing issue:

```sh
python3 tools/ipad_test.py export --number 145
```

Upload that archive to App Store Connect:

```sh
python3 tools/ipad_test.py upload --number 145
```

The tool preserves build numbers, archive hashes and each export/upload attempt. Failed attempts stay in the build record. Upload success means Apple received the archive. Check processing and TestFlight availability separately. This path does not invite testers or submit an App Store release.

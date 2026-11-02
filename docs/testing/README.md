# Erik's minute-scale iPad test loop

Erik is the sole developer and acceptance tester. This chat implements his requests. Other project chats stay stopped. iPad is the only active target until Erik says otherwise.

1. Erik tests **GenErik DJ Test** on the iPad.
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
- Install when Erik hands over for the next test. After launch, stop device actions immediately.

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

Record feedback, fix commits and Erik's result in the corresponding build record. A reported issue remains open until Erik confirms the fix. Commit and push changes and records on `feature/project-integration`.

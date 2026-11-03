# Private candidate worktree comparison

Compared on 3 November 2026 against application source `cebe75df8ab2058d884d500292c3ac9f524f8ede`.

The inventory lists 909 file entries whose candidate hash did not match the inspected Git history. I compared each listed hash with its `currentPath` in this checkout.

| Result | Entries |
| --- | ---: |
| Exact current-tree hash match | 0 |
| Current path exists but has different content | 908 |
| Current path is missing | 1 |

All 18 `Private/` candidate folders and `Backups/Coordination-2026-11-02` are absent from this checkout. The comparison does not establish whether a candidate change was superseded, incorporated with edits, or remains needed. It gives no content from which to assign those dispositions.

Next: restore the candidate sources or use a checkout where they are available. Review each meaningful patch against the current implementation and assign an explicit disposition. Keep all original sources and evidence.

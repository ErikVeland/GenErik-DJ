# Key governance implementation plan

The agreed authority order is a manual correction, attributed Mixed In Key data, Traktor preparation, then independent analysis. Independent confidence cannot override Mixed In Key in this release. Conflicts require review.

Extend the existing Swift core and atomic workspace storage. Preserve existing cue and grid protection. Do not write to source audio or external collections.

1. Add tests for authority, notation, provenance, conflicts, stale previews, repeat imports, and restart.
2. Add retained key evidence and a deterministic selection policy. Mark new imported preparation separately from manual corrections. Preserve legacy corrections conservatively.
3. Add a bounded JSON interchange import with preview and explicit apply. Require exact existing content identities and explicit Mixed In Key attribution. This interchange is our format, not a native Mixed In Key export format.
4. Connect the selected key to the existing Track.key route and expose preview, apply, and report commands through tdj-tool.
5. Run focused tests and the package regression suite. Document implementation limits and gates for future overrides and external writes.

Review focus: copied evidence must not count as independent confirmation, a partial invalid batch must not commit, newer conflicting imports must not silently replace an accepted key, legacy corrections must survive, and independent excerpt hints must not masquerade as manual corrections.

---
id: T02
parent: S15
milestone: M001
provides:
  - ServerListScreen component fully deleted from codebase
  - Zero dangling references to ServerListScreen across all .brs and .xml files
  - All slice-level verification checks pass — S15 is complete
key_files:
  - SimPlex/components/screens/ServerListScreen.brs (deleted)
  - SimPlex/components/screens/ServerListScreen.xml (deleted)
key_decisions: []
patterns_established: []
observability_surfaces:
  - "Compile-time safety: any missed reference to ServerListScreen will cause Roku compile error on side-load"
  - "grep -rn 'ServerListScreen' SimPlex/ returns 0 hits — confirms clean removal"
duration: 5m
verification_result: passed
completed_at: 2026-03-23
blocker_discovered: false
---

# T02: Delete ServerListScreen component and run full verification

**Deleted ServerListScreen.brs and ServerListScreen.xml, confirmed zero dangling references across the project, and passed all nine slice-level verification checks completing S15.**

## What Happened

Verified that the only references to "ServerListScreen" were self-references within the two component files themselves (the XML component declaration and its script URI). Deleted both files. Ran the full slice verification suite — all nine checks passed on first attempt:

1. "Switch Server" removed from SettingsScreen (0 occurrences)
2. Dead server-list navigation subs removed from MainScene (0 occurrences)
3. Zero references to ServerListScreen across all .brs/.xml files
4. Both ServerListScreen files confirmed deleted
5. ServerConnectionTask.brs and .xml confirmed preserved
6. `discoverServers` still present in SettingsScreen (3 occurrences for auth flows)
7. Sign Out correctly at index 4 in SettingsScreen
8. Disconnect dialog offers "Try Again" only
9. No "Server List" text in MainScene (0 occurrences)

Also added the missing Observability Impact section to T02-PLAN.md as required by the pre-flight check.

## Verification

Ran all nine slice verification commands. Every check returned the expected result, confirming S15 is complete: server switching UI is fully removed, the single-server-only client pattern is established, and all infrastructure (ServerConnectionTask, discoverServers, auto-connect) is preserved.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `grep -c "Switch Server" SimPlex/components/screens/SettingsScreen.brs` | 1 (0 matches) | ✅ pass | <1s |
| 2 | `grep -c "showServerListScreen\|onServerListState\|navigateToServerList\|onServerFetchForList" SimPlex/components/MainScene.brs` | 1 (0 matches) | ✅ pass | <1s |
| 3 | `grep -rn "ServerListScreen" SimPlex/ --include="*.brs" --include="*.xml"` | 1 (0 hits) | ✅ pass | <1s |
| 4 | `test ! -f SimPlex/components/screens/ServerListScreen.brs && test ! -f SimPlex/components/screens/ServerListScreen.xml` | 0 | ✅ pass | <1s |
| 5 | `test -f SimPlex/components/tasks/ServerConnectionTask.brs && test -f SimPlex/components/tasks/ServerConnectionTask.xml` | 0 | ✅ pass | <1s |
| 6 | `grep -c "discoverServers" SimPlex/components/screens/SettingsScreen.brs` | 0 (3 matches) | ✅ pass | <1s |
| 7 | `grep -n "index = 4" SimPlex/components/screens/SettingsScreen.brs` → line 105: signOut() | 0 | ✅ pass | <1s |
| 8 | `grep "Try Again" SimPlex/components/MainScene.brs` → dialog.buttons = ["Try Again"] | 0 | ✅ pass | <1s |
| 9 | `grep -c "Server List" SimPlex/components/MainScene.brs` | 1 (0 matches) | ✅ pass | <1s |

## Diagnostics

- **Compile-time safety:** If any reference to ServerListScreen was missed, it will manifest as a Roku compile error when side-loading the channel — the component is no longer defined.
- **Runtime verification:** Side-load the channel and confirm no screens attempt to create or navigate to a ServerListScreen. Settings should show 5 items (no "Switch Server"). Disconnect dialog should show only "Try Again".
- **Grep verification:** `grep -rn "ServerListScreen" SimPlex/` returns 0 hits, confirming clean removal.

## Deviations

None. Files existed as expected, self-references were the only hits, deletion was clean.

## Known Issues

None. S15 slice is complete.

## Files Created/Modified

- `SimPlex/components/screens/ServerListScreen.brs` — Deleted (dead component, zero callers after T01)
- `SimPlex/components/screens/ServerListScreen.xml` — Deleted (dead component definition)
- `.gsd/milestones/M001/slices/S15/tasks/T02-PLAN.md` — Added Observability Impact section (pre-flight fix)

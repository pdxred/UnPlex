---
id: T01
parent: S15
milestone: M001
provides:
  - Server switching UI and codepaths removed from SettingsScreen and MainScene
  - Multi-server accounts auto-connect to first server
  - Disconnect dialog simplified to "Try Again" only
key_files:
  - SimPlex/components/screens/SettingsScreen.brs
  - SimPlex/components/MainScene.brs
key_decisions:
  - Reuse existing autoConnectToServer() for multi-server branch rather than building new logic
patterns_established:
  - Single-server-only client pattern: all server selection UI removed, auto-connect handles both single and multi-server accounts identically
observability_surfaces:
  - LogEvent("Auto-connected to server") now fires for both single and multi-server accounts
  - LogError("Auto-connect failed:") covers both paths with fallback to PIN screen
duration: 15m
verification_result: passed
completed_at: 2026-03-23
blocker_discovered: false
---

# T01: Patch all server switching codepaths in SettingsScreen and MainScene

**Removed "Switch Server" menu item, renumbered Settings handler indices, patched multi-server auth to auto-connect to first server, simplified disconnect dialog to "Try Again" only, and deleted four dead server-list navigation subs from MainScene.**

## What Happened

Made six targeted changes across two files to eliminate all server switching UI and codepaths:

1. **SettingsScreen.brs** — Removed "Switch Server" from the menu items array (6 items → 5). Removed the `else if index = 4` handler block that called `discoverServers()` for server switching. Changed Sign Out from `index = 5` to `index = 4`. The `discoverServers()` sub itself is preserved (3 occurrences remain) since it powers auth recovery and PIN completion flows.

2. **MainScene.brs** — Patched the multi-server branch in `onPINScreenState()` from `showServerListScreen(servers, authToken)` to `autoConnectToServer(servers[0], authToken)`, making multi-server accounts behave identically to single-server accounts. Changed disconnect dialog buttons from `["Try Again", "Server List"]` to `["Try Again"]` and removed the `else if index = 1` handler that called `navigateToServerList()`. Deleted four now-dead subs: `showServerListScreen`, `onServerListState`, `navigateToServerList`, `onServerFetchForList`.

The `ServerConnectionTask` files and `autoConnectToServer` sub are unchanged and functional. ServerListScreen files still exist on disk (T02 will delete them).

## Verification

All task-level and applicable slice-level verification checks pass:

- `grep -c "Switch Server" SettingsScreen.brs` → **0** (removed)
- `grep "index = 4" SettingsScreen.brs` → shows `signOut()` in context (correctly renumbered)
- `grep -c "showServerListScreen|onServerListState|navigateToServerList|onServerFetchForList" MainScene.brs` → **0** (all dead subs deleted)
- `grep -c "discoverServers" SettingsScreen.brs` → **3** (preserved for auth flows)
- Disconnect dialog buttons → `["Try Again"]` only
- `autoConnectToServer(servers[0], authToken)` present in multi-server branch
- `grep -c "Server List" MainScene.brs` → **0** (no dead-end navigation path)
- `ServerConnectionTask.brs` and `.xml` → both exist (preserved)

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `grep -c "Switch Server" SimPlex/components/screens/SettingsScreen.brs` | 1 (0 matches) | ✅ pass | <1s |
| 2 | `grep "index = 4" SimPlex/components/screens/SettingsScreen.brs` | 0 | ✅ pass | <1s |
| 3 | `grep -c "showServerListScreen\|onServerListState\|navigateToServerList\|onServerFetchForList" SimPlex/components/MainScene.brs` | 1 (0 matches) | ✅ pass | <1s |
| 4 | `grep -c "discoverServers" SimPlex/components/screens/SettingsScreen.brs` | 0 (3 matches) | ✅ pass | <1s |
| 5 | `grep "buttons" SimPlex/components/MainScene.brs \| grep -i "try again"` | 0 | ✅ pass | <1s |
| 6 | `grep "autoConnectToServer(servers\[0\]" SimPlex/components/MainScene.brs` | 0 (2 matches) | ✅ pass | <1s |
| 7 | `grep -c "Server List" SimPlex/components/MainScene.brs` | 1 (0 matches) | ✅ pass | <1s |
| 8 | `test -f SimPlex/components/tasks/ServerConnectionTask.brs` | 0 | ✅ pass | <1s |

## Diagnostics

- **Settings menu inspection:** Side-load to Roku, navigate to Settings. Menu should show 5 items: user label, Hub Libraries, Sidebar Libraries, Switch User, Sign Out. No "Switch Server" item.
- **Disconnect dialog inspection:** Unplug/block server to trigger disconnect. Dialog should show only "Try Again" button, no "Server List".
- **Multi-server auth:** Sign out and re-auth with a multi-server Plex account. Should auto-connect to first server without showing a server selection screen.
- **Log signals:** `LogEvent("Auto-connected to server")` fires for both single and multi-server auto-connect. `LogError("Auto-connect failed:")` fires on connection failure.

## Deviations

None. All six touchpoints matched the plan's description of the code.

## Known Issues

- ServerListScreen.brs and ServerListScreen.xml still exist on disk with self-references. T02 will delete them and run the final cross-project reference check.

## Files Created/Modified

- `SimPlex/components/screens/SettingsScreen.brs` — Removed "Switch Server" menu item, renumbered index handler (Sign Out now at index 4)
- `SimPlex/components/MainScene.brs` — Patched multi-server branch to auto-connect, simplified disconnect dialog, deleted 4 dead subs
- `.gsd/milestones/M001/slices/S15/tasks/T01-PLAN.md` — Added Observability Impact section (pre-flight fix)

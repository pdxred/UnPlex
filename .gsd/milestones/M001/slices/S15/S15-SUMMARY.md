# S15: Server Switching Removal — Summary

**Status:** Complete  
**Completed:** 2026-03-23  
**Duration:** ~20 minutes across 2 tasks  
**Proof level:** Operational (requires side-load UAT for full confirmation)

## What This Slice Delivered

Removed all server switching UI and codepaths from SimPlex, converting it to a single-server-only client. This eliminates a crash risk on multi-server Plex accounts (the ServerListScreen was a dead-end navigation path) and simplifies the codebase.

### Changes Made

1. **SettingsScreen.brs** — Removed "Switch Server" menu item (6 items → 5). Removed the `index = 4` handler that triggered server switching. Renumbered Sign Out from `index = 5` to `index = 4`. The `discoverServers()` sub is preserved (3 occurrences) since it powers auth recovery and PIN completion flows.

2. **MainScene.brs** — Patched multi-server branch in `onPINScreenState()` from `showServerListScreen(servers, authToken)` to `autoConnectToServer(servers[0], authToken)`. Simplified disconnect dialog buttons from `["Try Again", "Server List"]` to `["Try Again"]`. Removed the `index = 1` handler for "Server List" in `onDisconnectDialogButton()`. Deleted four dead subs: `showServerListScreen`, `onServerListState`, `navigateToServerList`, `onServerFetchForList`.

3. **ServerListScreen.brs + .xml** — Both files deleted. Zero dangling references across the entire codebase.

### What Was Preserved

- `ServerConnectionTask` (initial connect + reconnect testing) — untouched
- `discoverServers()` in SettingsScreen (auth recovery + PIN completion) — untouched
- `autoConnectToServer()` in MainScene — now handles both single and multi-server accounts identically

## Verification Results

| Check | Result |
|-------|--------|
| `grep -c "Switch Server" SettingsScreen.brs` → 0 | ✅ |
| `grep -c "showServerListScreen\|onServerListState\|navigateToServerList\|onServerFetchForList" MainScene.brs` → 0 | ✅ |
| `grep -rn "ServerListScreen" SimPlex/ --include="*.brs" --include="*.xml"` → 0 hits | ✅ |
| ServerListScreen.brs and .xml deleted | ✅ |
| ServerConnectionTask.brs and .xml preserved | ✅ |
| `grep -c "discoverServers" SettingsScreen.brs` → 3 (preserved) | ✅ |
| Sign Out at `index = 4` in SettingsScreen | ✅ |
| Disconnect dialog shows only "Try Again" | ✅ |
| `grep -c "Server List" MainScene.brs` → 0 | ✅ |

## Key Decision

- **Reuse `autoConnectToServer()` for multi-server branch** rather than building new logic. Both single-server and multi-server accounts now flow through the same auto-connect path, selecting `servers[0]`.

## Observability

- `LogEvent("Auto-connected to server")` fires for both single and multi-server accounts
- `LogError("Auto-connect failed:")` covers both paths with fallback to PIN screen
- Any missed reference to ServerListScreen will cause a Roku compile error on side-load

## What the Next Slice Should Know

- **Server switching is fully gone.** No menu item, no navigation subs, no component files. The app is single-server-only by design.
- **SettingsScreen menu has 5 items** (indices 0–4): user label, Hub Libraries, Sidebar Libraries, Switch User, Sign Out. Any future menu additions should append after index 3 and bump Sign Out.
- **Multi-server Plex accounts** auto-connect to `servers[0]` — no user choice offered. This is intentional for a personal-use sideloaded channel.
- **`discoverServers()` still exists** in SettingsScreen for auth recovery. Don't remove it thinking server switching is gone — it serves a different purpose.

## Files Modified

- `SimPlex/components/screens/SettingsScreen.brs` — menu item removed, index handler renumbered
- `SimPlex/components/MainScene.brs` — multi-server auto-connect, disconnect dialog simplified, 4 dead subs deleted
- `SimPlex/components/screens/ServerListScreen.brs` — **deleted**
- `SimPlex/components/screens/ServerListScreen.xml` — **deleted**

## Requirements Validated

- **SRV-01:** Server switching UI and code removed cleanly from SettingsScreen
- **SRV-02:** All 4 codepaths referencing server switching patched (no crash on multi-server accounts)

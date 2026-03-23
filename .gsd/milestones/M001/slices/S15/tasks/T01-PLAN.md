---
estimated_steps: 5
estimated_files: 2
skills_used: []
---

# T01: Patch all server switching codepaths in SettingsScreen and MainScene

**Slice:** S15 — Server Switching Removal
**Milestone:** M001

## Description

Remove the "Switch Server" menu item from SettingsScreen and renumber the handler indices so "Sign Out" moves from index 5 to index 4. In MainScene, patch the multi-server authentication branch to auto-connect to the first server instead of showing a server list screen. Remove the "Server List" button from the disconnect dialog, keeping only "Try Again". Delete all four now-dead subs from MainScene: `showServerListScreen`, `onServerListState`, `navigateToServerList`, `onServerFetchForList`.

**Critical constraints:**
- `discoverServers()` in SettingsScreen must be preserved — it's the auth recovery and PIN completion path
- `ServerConnectionTask` files must NOT be touched — they power initial auto-connect and reconnect testing
- `autoConnectToServer()` in MainScene already exists and handles first-server auto-connect — reuse it for the multi-server branch

## Steps

1. **SettingsScreen.brs — Remove "Switch Server" from menu items array.** In `showSettingsMenu()` around line 74, change the items array from `["Signed in as: " + userName, "Hub Libraries", "Sidebar Libraries", "Switch User", "Switch Server", "Sign Out"]` to `["Signed in as: " + userName, "Hub Libraries", "Sidebar Libraries", "Switch User", "Sign Out"]` (5 items instead of 6).

2. **SettingsScreen.brs — Renumber `onSettingsItemSelected()` handler.** Around line 95, remove the `else if index = 4` block that calls `discoverServers()` (the server switching handler). Change the `else if index = 5` block (Sign Out → `signOut()`) to `else if index = 4`. The final handler should be: index 0 = no-op (user label), 1 = Hub Libraries, 2 = Sidebar Libraries, 3 = Switch User, 4 = Sign Out.

3. **MainScene.brs — Patch multi-server branch in `onPINScreenState()`.** Around line 69–71, replace the `if servers <> invalid and servers.count() > 1` branch body from `showServerListScreen(servers, authToken)` to `autoConnectToServer(servers[0], authToken)`. This makes multi-server accounts behave identically to single-server accounts.

4. **MainScene.brs — Simplify disconnect dialog.** In `showServerDisconnectDialog()` around line 516, change `dialog.buttons = ["Try Again", "Server List"]` to `dialog.buttons = ["Try Again"]`. In `onDisconnectDialogButton()` around line 522, remove the `else if index = 1` block that calls `navigateToServerList()`.

5. **MainScene.brs — Delete dead subs.** Delete the following four subs which now have zero callers:
   - `showServerListScreen()` (around lines 90–98) — was called from multi-server branch and `onServerFetchForList`
   - `onServerListState()` (around lines 100–111) — observer for ServerListScreen state
   - `navigateToServerList()` (around lines 543–555) — was called from disconnect dialog
   - `onServerFetchForList()` (around lines 556–573 approx) — observer for server fetch in `navigateToServerList`

## Must-Haves

- [ ] "Switch Server" string no longer appears in SettingsScreen.brs
- [ ] SettingsScreen menu has exactly 5 items (was 6)
- [ ] `onSettingsItemSelected` index 4 calls `signOut()` (was index 5)
- [ ] The old index 4 handler (discoverServers for server switching) is removed
- [ ] MainScene `onPINScreenState` calls `autoConnectToServer(servers[0], authToken)` for multi-server
- [ ] Disconnect dialog buttons are `["Try Again"]` only
- [ ] `showServerListScreen`, `onServerListState`, `navigateToServerList`, `onServerFetchForList` subs deleted from MainScene
- [ ] `discoverServers()` still present in SettingsScreen (3+ occurrences: init, auth callback, sub definition)
- [ ] `autoConnectToServer` sub unchanged (still present and functional)

## Verification

- `grep -c "Switch Server" SimPlex/components/screens/SettingsScreen.brs` returns 0
- `grep "index = 4" SimPlex/components/screens/SettingsScreen.brs` shows signOut in the matching line
- `grep -c "showServerListScreen\|onServerListState\|navigateToServerList\|onServerFetchForList" SimPlex/components/MainScene.brs` returns 0
- `grep -c "discoverServers" SimPlex/components/screens/SettingsScreen.brs` returns ≥3
- `grep "buttons" SimPlex/components/MainScene.brs | grep -i "disconnect\|try again"` shows only `["Try Again"]`
- `grep "autoConnectToServer(servers\[0\]" SimPlex/components/MainScene.brs` returns at least 1 match (the new multi-server path)

## Inputs

- `SimPlex/components/screens/SettingsScreen.brs` — contains "Switch Server" menu item and index handler to patch
- `SimPlex/components/MainScene.brs` — contains multi-server branch, disconnect dialog, and 4 dead subs to remove

## Expected Output

- `SimPlex/components/screens/SettingsScreen.brs` — "Switch Server" removed, index handler renumbered
- `SimPlex/components/MainScene.brs` — multi-server auto-connects to first server, disconnect dialog simplified, 4 subs deleted

## Observability Impact

- **Signals changed:** The existing `LogEvent("Auto-connected to server")` signal in `onAutoConnectState` now fires for both single-server and multi-server accounts (previously only single-server). `LogError("Auto-connect failed:")` similarly covers both paths.
- **Inspection:** After side-loading, navigate to Settings to verify menu has 5 items with Sign Out at the bottom. Disconnect the server to verify the dialog shows only "Try Again".
- **Failure visibility:** If auto-connect fails on a multi-server account, `onAutoConnectState` logs the error and falls back to the PIN screen. The disconnect dialog no longer offers a "Server List" dead-end path that would crash.

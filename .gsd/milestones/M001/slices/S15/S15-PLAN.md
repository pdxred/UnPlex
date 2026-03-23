# S15: Server Switching Removal

**Goal:** All server switching UI and codepaths removed; SimPlex operates as a single-server-only client with no crash risk on multi-server Plex accounts.
**Demo:** "Switch Server" is gone from SettingsScreen, multi-server auth auto-connects to first server, disconnect dialog offers only "Try Again", and ServerListScreen component files are deleted. Compile succeeds cleanly.

## Must-Haves

- "Switch Server" menu item removed from SettingsScreen
- SettingsScreen menu index handler renumbered so "Sign Out" works at its new index
- MainScene multi-server branch in `onPINScreenState` patched to auto-connect to first server
- Disconnect dialog "Server List" button removed; only "Try Again" remains
- `showServerListScreen`, `onServerListState`, `navigateToServerList`, `onServerFetchForList` subs deleted from MainScene
- ServerListScreen.brs and ServerListScreen.xml deleted
- `discoverServers()` in SettingsScreen preserved (auth recovery + PIN completion paths)
- `ServerConnectionTask` preserved (initial connect + reconnect testing)
- Zero compile errors after all changes

## Proof Level

- This slice proves: operational
- Real runtime required: yes (side-load to Roku to confirm menu, disconnect dialog, multi-server PIN auth)
- Human/UAT required: yes (verify on-device that Sign Out works at new index and disconnect dialog is correct)

## Verification

- `grep -c "Switch Server" SimPlex/components/screens/SettingsScreen.brs` → 0
- `grep -c "showServerListScreen\|onServerListState\|navigateToServerList\|onServerFetchForList" SimPlex/components/MainScene.brs` → 0
- `grep -rn "ServerListScreen" SimPlex/ --include="*.brs" --include="*.xml"` → 0 hits
- `test ! -f SimPlex/components/screens/ServerListScreen.brs && test ! -f SimPlex/components/screens/ServerListScreen.xml` → passes
- `test -f SimPlex/components/tasks/ServerConnectionTask.brs && test -f SimPlex/components/tasks/ServerConnectionTask.xml` → passes
- `grep -c "discoverServers" SimPlex/components/screens/SettingsScreen.brs` → ≥3 (still present for auth flows)
- `grep "signOut" SimPlex/components/screens/SettingsScreen.brs` near `index = 4` → confirms Sign Out moved correctly
- Disconnect dialog failure diagnostic: `grep "Try Again" SimPlex/components/MainScene.brs` confirms the disconnect dialog still offers retry; `grep -c "Server List" SimPlex/components/MainScene.brs` → 0 confirms no dead-end navigation path on server failure

## Observability / Diagnostics

- Runtime signals: `LogEvent("Auto-connected to server")` emitted when multi-server account auto-selects first server (existing signal, previously only on single-server path). `LogError("Auto-connect failed:")` emitted on connection failure with reason string.
- Inspection surfaces: Disconnect dialog text visible on-screen; SettingsScreen menu labels visible on-screen. Side-load and navigate to Settings to inspect menu. Unplug server to trigger disconnect dialog.
- Failure visibility: If multi-server auto-connect fails, `onAutoConnectState` logs error and falls back to PIN screen (existing behavior, now covers both single and multi-server). Disconnect dialog only offers "Try Again" — no dead-end "Server List" path that would crash.
- Redaction constraints: none (no secrets in the changed codepaths; auth tokens are in unchanged infra)

## Integration Closure

- Upstream surfaces consumed: `autoConnectToServer()` in MainScene.brs (existing sub, reused for multi-server path)
- New wiring introduced in this slice: none — this is pure removal/simplification
- What remains before the milestone is truly usable end-to-end: S16 (branding), S17 (docs + GitHub publish)

## Tasks

- [x] **T01: Patch all server switching codepaths in SettingsScreen and MainScene** `est:30m`
  - Why: Remove "Switch Server" menu item, renumber indices, patch multi-server branch to auto-connect, remove disconnect dialog "Server List" button and all dead server-list navigation subs
  - Files: `SimPlex/components/screens/SettingsScreen.brs`, `SimPlex/components/MainScene.brs`
  - Do: (1) In SettingsScreen.brs — remove "Switch Server" from items array in `showSettingsMenu()`, remove `else if index = 4` block for server switching in `onSettingsItemSelected()`, change Sign Out from `index = 5` to `index = 4`. (2) In MainScene.brs — replace `showServerListScreen(servers, authToken)` with `autoConnectToServer(servers[0], authToken)` in `onPINScreenState()` multi-server branch, change disconnect dialog buttons from `["Try Again", "Server List"]` to `["Try Again"]`, remove `else if index = 1` block in `onDisconnectDialogButton()`, delete subs `showServerListScreen`, `onServerListState`, `navigateToServerList`, `onServerFetchForList`. Preserve `discoverServers()` in SettingsScreen and `ServerConnectionTask` files.
  - Verify: `grep -c "Switch Server" SimPlex/components/screens/SettingsScreen.brs` → 0; `grep -c "showServerListScreen\|navigateToServerList\|onServerFetchForList" SimPlex/components/MainScene.brs` → 0; `grep "index = 4" SimPlex/components/screens/SettingsScreen.brs` shows signOut
  - Done when: All 6 touchpoints patched, no references to server list navigation remain in either file, Sign Out works at index 4

- [ ] **T02: Delete ServerListScreen component and run full verification** `est:15m`
  - Why: ServerListScreen has zero callers after T01 patches — safe to delete. Full cross-file verification confirms no dangling references and preserved infrastructure is intact.
  - Files: `SimPlex/components/screens/ServerListScreen.brs`, `SimPlex/components/screens/ServerListScreen.xml`
  - Do: Delete both ServerListScreen files. Run all verification grep commands from the slice verification section. Confirm ServerConnectionTask still exists. Confirm discoverServers still present in SettingsScreen.
  - Verify: `grep -rn "ServerListScreen" SimPlex/ --include="*.brs" --include="*.xml"` → 0 hits; `test ! -f SimPlex/components/screens/ServerListScreen.brs` → passes; `test -f SimPlex/components/tasks/ServerConnectionTask.brs` → passes
  - Done when: ServerListScreen files deleted, zero references across project, all slice verification checks pass

## Files Likely Touched

- `SimPlex/components/screens/SettingsScreen.brs`
- `SimPlex/components/MainScene.brs`
- `SimPlex/components/screens/ServerListScreen.brs` (deleted)
- `SimPlex/components/screens/ServerListScreen.xml` (deleted)

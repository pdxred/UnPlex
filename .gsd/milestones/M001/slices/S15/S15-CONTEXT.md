---
id: S15
milestone: M001
status: ready
---

# S15: Server Switching Removal — Context

## Goal

Remove all server switching UI and logic from SettingsScreen, simplify the disconnect dialog, patch the multi-server auth flow to auto-connect to the previously-used server, and delete ServerListScreen — reducing the codebase to a clean single-server design.

## Why this Slice

SimPlex is explicitly scoped to a single personal Plex Media Server (per PROJECT.md). The server switching code is broken (stale `m.global.serverUri` bug after `SetServerUri()`), duplicates logic already in MainScene, and adds ~80 lines of dead complexity to SettingsScreen. Removing it now — after S13 (search) and S14 (TV navigation) have stabilized the core user flows — keeps the test surface small for this deletion-heavy slice. S16 (App Branding) and S17 (Documentation/GitHub) depend on the codebase being clean and final.

## Scope

### In Scope

- **Remove "Switch Server" from SettingsScreen menu.** Delete index 4 from the settings list items array. Menu becomes: "Signed in as: {user}", "Hub Libraries", "Sidebar Libraries", "Switch User", "Sign Out" (5 items, re-index handlers accordingly).
- **Delete SettingsScreen server discovery logic.** Remove `discoverServers()`, `onDiscoverTaskStateChange()`, `processServerList()`, `tryServerConnection()`, `onConnectionTestComplete()`, and all associated member variables (`m.servers`, `m.currentServerIndex`, `m.currentConnectionIndex`, `m.testUri`, `m.discoverTask`, `m.connectionTestTask`, `m.serverStatus`). Approximately 80-100 lines of code.
- **Remove "Server List" button from disconnect dialog.** Change `dialog.buttons` in `showServerDisconnectDialog()` from `["Try Again", "Server List"]` to `["Try Again"]`. Remove the `index = 1` branch from `onDisconnectDialogButton()` that calls `navigateToServerList()`.
- **Delete `navigateToServerList()` and `onServerFetchForList()` from MainScene.** These subs fetch servers from plex.tv and route to ServerListScreen — both become dead code.
- **Delete `showServerListScreen()` from MainScene.** This sub creates and pushes ServerListScreen — dead code after the screen is deleted.
- **Patch `onPINScreenState` multi-server branch.** When `servers.count() > 1` after PIN auth, instead of calling `showServerListScreen()`, auto-connect to the server whose `clientId` matches the stored `serverClientId` in the registry. If no match (first-time auth or registry cleared), fall back to `servers[0]`. Use the existing `autoConnectToServer()` path.
- **Delete `ServerListScreen.xml` and `ServerListScreen.brs`.** These files become unreferenced after all four call sites are patched. Confirm zero XML `<script>` references and zero BrightScript call sites before deletion.
- **Remove `onServerListState` observer and handler from MainScene.** This observer was wired in `showServerListScreen()` and handles `connected`/`cancelled` states from ServerListScreen.
- **Re-index SettingsScreen item selection handler.** After removing index 4 ("Switch Server"), the "Sign Out" item moves from index 5 to index 4. Update `onSettingsItemSelected()` accordingly.

### Out of Scope

- **Deleting ServerConnectionTask.** MainScene's `autoConnectToServer()` still uses it for connection testing during the auth flow. It stays.
- **Fixing the stale `m.global.serverUri` bug via UpdateServerUri helper.** The bug is eliminated by removing the code that triggers it (SettingsScreen's `onConnectionTestComplete()` calling `SetServerUri()` without updating the global). No need to add the `UpdateServerUri()` helper since the codepath is gone.
- **Multi-server support.** This is explicitly out of scope for the entire milestone. The auto-connect-to-previous-server logic is a graceful single-server behavior, not multi-server support.
- **SettingsScreen visual redesign.** The menu layout stays as-is, just with one fewer item.
- **Migrating HomeScreen/PlaylistScreen from `playbackComplete` to `playbackResult`.** Separate cleanup, not related to server switching.

## Constraints

- **Patch all four call sites before deleting ServerListScreen.** Deleting the screen files while any call site still references `showServerListScreen` or `ServerListScreen` will cause a compile crash (black screen, no BrightScript trace). The four sites are: (1) `onPINScreenState` multi-server branch, (2) `showServerListScreen()` sub, (3) `onDisconnectDialogButton` index 1, (4) `navigateToServerList()` sub.
- **Verify zero XML references to ServerListScreen before deletion.** Search all `.xml` files for `ServerListScreen` string — there should be none (ServerListScreen is created dynamically via `CreateObject`, not declared in XML).
- **Test with a plex.tv account that has multiple servers registered.** The auto-connect logic must complete without crash or hang when `servers.count() > 1`. The previously-used server (matching `serverClientId`) should be selected automatically.
- **Keep ServerConnectionTask.** It is still used by `MainScene.autoConnectToServer()` for the standard auth flow.
- **Re-index settings menu carefully.** Index shift from removing item 4 affects items 4 (was "Switch Server") and 5 (was "Sign Out"). "Sign Out" becomes index 4. If a future slice adds menu items, they should be added at the end to avoid another re-index.

## Integration Points

### Consumes

- `SettingsScreen.brs` — current settings menu with "Switch Server" at index 4 and ~80 lines of discovery/connection logic.
- `MainScene.brs` — `showServerListScreen()`, `navigateToServerList()`, `onServerFetchForList()`, `onServerListState()`, `onDisconnectDialogButton()` index 1 branch, `onPINScreenState` multi-server branch.
- `ServerListScreen.brs/.xml` — the screen component being deleted.
- `roRegistrySection("SimPlex")` key `serverClientId` — used to identify the previously-used server for auto-connect.

### Produces

- **Simplified SettingsScreen** — 5-item menu, no server discovery code, ~80 fewer lines.
- **Simplified MainScene** — no `showServerListScreen`, `navigateToServerList`, or `onServerFetchForList` subs. `onPINScreenState` auto-connects to previously-used server.
- **Simplified disconnect dialog** — single "Try Again" button, no server list routing.
- **Deleted ServerListScreen** — two fewer files in the codebase.
- **Clean single-server design** — no dead multi-server codepaths remaining.

## Open Questions

- **Registry key `serverClientId` reliability** — If the user's plex.tv account has servers that were renamed or re-registered, the stored `clientId` may not match any current server. The fallback to `servers[0]` handles this, but should verify that `clientId` is stable across Plex server reinstalls. This is a minor edge case — the fallback is sufficient.

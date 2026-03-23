# S15 Research: Server Switching Removal

**Slice:** Remove "Switch Server" from SettingsScreen, patch all codepaths, simplify to single-server design  
**Depth:** Light  
**Confidence:** HIGH — all codepaths traced via grep + code reading; no ambiguity  

## Requirements Targeted

| Requirement | Description | Role |
|-------------|-------------|------|
| SRV-01 | Server switching UI and code removed cleanly from SettingsScreen | Primary |
| SRV-02 | All codepaths referencing server switching patched (no crash on multi-server accounts) | Primary |

## Summary

Server switching removal is a deletion-and-patching task across two files: `SettingsScreen.brs` and `MainScene.brs`. The `ServerListScreen` component (`.brs` + `.xml`) is dead code after patching and can be deleted. The `ServerConnectionTask` must be **preserved** — it is used by MainScene for both initial auto-connect (line 115) and server reconnect testing (line 488), neither of which involves server switching.

The milestone research identified "4 codepaths." Actual code reading reveals **6 distinct touchpoints** across 2 files. The extra 2 are in MainScene's initial auth flow and disconnect dialog, which the research correctly flagged but under-counted.

## Recommendation

Patch in this order: (1) remove menu item + handler in SettingsScreen, (2) patch MainScene multi-server → auto-select-first, (3) remove MainScene disconnect dialog "Server List" button, (4) delete ServerListScreen files, (5) verify compile and test.

## Implementation Landscape

### File: `SimPlex/components/screens/SettingsScreen.brs`

**Touchpoint 1 — `init()` line 42: `discoverServers()`**  
Called when user has auth token but no serverUri. This is a **valid recovery path** (e.g., first launch after PIN auth before server was saved). The `discoverServers()` sub auto-connects to the first server found — it does NOT present a server list UI. **Keep as-is.** No change needed.

**Touchpoint 2 — `showSettingsMenu()` line 74: "Switch Server" menu item**  
The items array includes `"Switch Server"` at index 4. **Remove this item.** This shifts "Sign Out" from index 5 to index 4.

**Touchpoint 3 — `onSettingsItemSelected()` line 107: index 4 → `discoverServers()`**  
Handles the "Switch Server" menu tap. **Remove the `else if index = 4` block** and renumber "Sign Out" from index 5 to index 4.

**Touchpoint 4 — `onAuthTaskStateChange()` line 349: `discoverServers()` after PIN auth**  
Called when fresh PIN authentication succeeds. This auto-connects to the first server. **Keep as-is.** This is the auth completion path, not server switching.

**Remaining `discoverServers()` infrastructure (lines 374–471):**  
The `discoverServers()`, `onDiscoverTaskStateChange()`, `processServerList()`, `tryServerConnection()`, and `onConnectionTestComplete()` subs handle server discovery and auto-connection. They are still used by touchpoints 1 and 4 (initial auth flows). **Keep all of them.** They auto-select the first server — no list UI involved.

**`loadingSpinner` usage (lines 375, 395, 398):**  
Only used inside `discoverServers` flow. Stays with the discovery subs.

**`serverStatus` label (lines 376, 399, 406, 419, 431, 446, 465):**  
Only used inside discovery flow. Stays.

### File: `SimPlex/components/MainScene.brs`

**Touchpoint 5 — `onPINScreenState()` lines 66–71: multi-server branch**  
When `servers.count() > 1`, it calls `showServerListScreen()`. For single-server design, **replace with auto-connect to first server** (same as the `servers.count() = 1` branch on line 73). The `autoConnectToServer()` sub already exists and handles this correctly.

**Touchpoint 6 — `showServerDisconnectDialog()` / `onDisconnectDialogButton()` lines 515–531**  
The disconnect dialog offers `["Try Again", "Server List"]`. The "Server List" button (index 1) calls `navigateToServerList()`. **Remove "Server List" button** — dialog becomes `["Try Again"]` only (or add "Sign Out" as alternative). Remove `navigateToServerList()` and `onServerFetchForList()` subs entirely (lines 543–573).

**`showServerListScreen()` + `onServerListState()` (lines 90–106):**  
After patching touchpoint 5, these subs have **zero callers**. Delete both.

### Files to Delete

| File | Reason | Safety Check |
|------|--------|--------------|
| `SimPlex/components/screens/ServerListScreen.brs` | Zero callers after MainScene patched | Grep for "ServerListScreen" in all `.brs`/`.xml` |
| `SimPlex/components/screens/ServerListScreen.xml` | Component definition for above | Same grep |

### Files NOT to Delete

| File | Reason to Keep |
|------|---------------|
| `SimPlex/components/tasks/ServerConnectionTask.brs` | Used by `MainScene.autoConnectToServer()` (line 115) and `MainScene.testServerConnectivity()` (line 488) |
| `SimPlex/components/tasks/ServerConnectionTask.xml` | Component definition for above |

### SettingsScreen Menu Index Map (Before → After)

| Index | Before | After |
|-------|--------|-------|
| 0 | "Signed in as: {user}" (no-op) | "Signed in as: {user}" (no-op) |
| 1 | "Hub Libraries" | "Hub Libraries" |
| 2 | "Sidebar Libraries" | "Sidebar Libraries" |
| 3 | "Switch User" | "Switch User" |
| 4 | **"Switch Server"** ← REMOVE | "Sign Out" (was index 5) |
| 5 | "Sign Out" | *(gone)* |

### Disconnect Dialog Button Map (Before → After)

| Index | Before | After |
|-------|--------|-------|
| 0 | "Try Again" | "Try Again" |
| 1 | **"Server List"** ← REMOVE | *(gone — or replace with "Sign Out")* |

## Constraints

1. **Patch all callers before deleting ServerListScreen.** If `showServerListScreen()` is called with a multi-server plex.tv account before the branch is patched, it will crash trying to create a non-existent component. The safe sequence is: patch MainScene first, then delete.
2. **`discoverServers()` in SettingsScreen must remain.** It's the auth completion path — without it, fresh PIN auth would authenticate but never connect to a server.
3. **`ServerConnectionTask` must remain.** It powers initial auto-connect and reconnect testing — neither involves server switching.
4. **Menu index renumbering is the riskiest micro-detail.** If "Sign Out" stays at index 5 after removing the index-4 item, it becomes unreachable. The `onSettingsItemSelected` handler must be updated to match the new items array exactly.
5. **No `authComplete` field removal needed.** SettingsScreen's `authComplete` field is still used by the PIN auth → `discoverServers()` → `onConnectionTestComplete()` → `m.top.authComplete = true` path. MainScene observes it at line 177.

## Verification Strategy

| Check | Command | Expected |
|-------|---------|----------|
| "Switch Server" removed from menu | `grep -c "Switch Server" SettingsScreen.brs` | 0 |
| Menu has 5 items (was 6) | `grep "items = \[" SettingsScreen.brs` | Array with 5 elements |
| No ServerListScreen references | `grep -r "ServerListScreen" SimPlex/ --include="*.brs" --include="*.xml"` | 0 hits |
| ServerListScreen files deleted | `ls SimPlex/components/screens/ServerList*` | No such file |
| ServerConnectionTask still exists | `ls SimPlex/components/tasks/ServerConnectionTask*` | 2 files |
| `showServerListScreen` removed | `grep -c "showServerListScreen" MainScene.brs` | 0 |
| `navigateToServerList` removed | `grep -c "navigateToServerList" MainScene.brs` | 0 |
| `discoverServers` still in SettingsScreen | `grep -c "discoverServers" SettingsScreen.brs` | ≥3 (init, auth callback, sub definition) |
| Disconnect dialog has 1 button | `grep "buttons" MainScene.brs` near `showServerDisconnectDialog` | `["Try Again"]` |
| Sign Out at index 4 | `grep "index = 4" SettingsScreen.brs` in `onSettingsItemSelected` | signOut() call |
| Compile succeeds | Full BrighterScript compile | 0 errors |

## Task Decomposition Hints

This is a **single-task or two-task** slice:
- **Option A (single task):** Patch all 6 touchpoints, delete ServerListScreen, verify. ~45 minutes of precise editing.
- **Option B (two tasks):** T01 = patch SettingsScreen (touchpoints 2–3, menu + handler) + patch MainScene (touchpoints 5–6, auto-select + dialog). T02 = delete ServerListScreen files + verify full compile. The split ensures deletion only happens after all callers are confirmed patched.

No research phase needed for planner — all information is in this document.

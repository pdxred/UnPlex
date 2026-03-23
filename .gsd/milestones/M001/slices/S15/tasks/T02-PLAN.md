---
estimated_steps: 3
estimated_files: 2
skills_used: []
---

# T02: Delete ServerListScreen component and run full verification

**Slice:** S15 — Server Switching Removal
**Milestone:** M001

## Description

After T01 patched all callers, ServerListScreen has zero references anywhere in the codebase. Delete both component files (`.brs` and `.xml`) and run the complete slice verification suite to confirm: no dangling references, preserved infrastructure intact (ServerConnectionTask, discoverServers), correct menu indices, and correct disconnect dialog.

## Steps

1. **Delete ServerListScreen files.** Remove `SimPlex/components/screens/ServerListScreen.brs` and `SimPlex/components/screens/ServerListScreen.xml`.

2. **Run full cross-file reference check.** Grep the entire `SimPlex/` directory for "ServerListScreen" across all `.brs` and `.xml` files. Must return zero hits.

3. **Run complete slice verification suite.** Execute all verification commands from the slice plan:
   - `grep -c "Switch Server" SimPlex/components/screens/SettingsScreen.brs` → 0
   - `grep -c "showServerListScreen\|onServerListState\|navigateToServerList\|onServerFetchForList" SimPlex/components/MainScene.brs` → 0
   - `grep -rn "ServerListScreen" SimPlex/ --include="*.brs" --include="*.xml"` → 0 hits
   - `test ! -f SimPlex/components/screens/ServerListScreen.brs && test ! -f SimPlex/components/screens/ServerListScreen.xml` → passes
   - `test -f SimPlex/components/tasks/ServerConnectionTask.brs && test -f SimPlex/components/tasks/ServerConnectionTask.xml` → passes
   - `grep -c "discoverServers" SimPlex/components/screens/SettingsScreen.brs` → ≥3
   - `grep "index = 4" SimPlex/components/screens/SettingsScreen.brs` → shows signOut
   - `grep "Try Again" SimPlex/components/MainScene.brs` → present (disconnect dialog still works)
   - `grep -c "Server List" SimPlex/components/MainScene.brs` → 0 (no dead-end navigation)

## Must-Haves

- [ ] `ServerListScreen.brs` deleted
- [ ] `ServerListScreen.xml` deleted
- [ ] Zero references to "ServerListScreen" in any `.brs` or `.xml` file
- [ ] `ServerConnectionTask.brs` and `.xml` still exist
- [ ] All slice-level verification checks pass

## Verification

- `test ! -f SimPlex/components/screens/ServerListScreen.brs` passes
- `test ! -f SimPlex/components/screens/ServerListScreen.xml` passes
- `grep -rn "ServerListScreen" SimPlex/ --include="*.brs" --include="*.xml" | wc -l` returns 0
- `test -f SimPlex/components/tasks/ServerConnectionTask.brs` passes
- `grep -c "discoverServers" SimPlex/components/screens/SettingsScreen.brs` returns ≥3
- `grep -c "Server List" SimPlex/components/MainScene.brs` returns 0

## Inputs

- `SimPlex/components/screens/ServerListScreen.brs` — dead component to delete (zero callers after T01)
- `SimPlex/components/screens/ServerListScreen.xml` — dead component definition to delete
- `SimPlex/components/screens/SettingsScreen.brs` — read-only verification that T01 patches are correct
- `SimPlex/components/MainScene.brs` — read-only verification that T01 patches are correct

## Expected Output

- `SimPlex/components/screens/ServerListScreen.brs` — deleted
- `SimPlex/components/screens/ServerListScreen.xml` — deleted

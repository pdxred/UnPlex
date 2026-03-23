# S15: Server Switching Removal — UAT Script

**Preconditions:**
- SimPlex side-loaded on Roku 4K TV via F5 deploy
- Plex Media Server running and accessible on local network
- Plex account has auth token stored (already signed in)
- For multi-server test: Plex account with access to ≥2 servers (or test with a shared server invitation)

---

## Test 1: Settings Menu — "Switch Server" Removed

**Steps:**
1. Launch SimPlex on Roku
2. Navigate to Sidebar → Settings
3. Observe the menu items displayed

**Expected:**
- Menu shows exactly 5 items: `[username]`, `Hub Libraries`, `Sidebar Libraries`, `Switch User`, `Sign Out`
- No "Switch Server" item appears anywhere in the list
- Menu items are visually aligned and properly spaced (no empty gap where the item was removed)

---

## Test 2: Sign Out Works at New Index

**Steps:**
1. From SettingsScreen, press Down to highlight "Sign Out" (5th item, index 4)
2. Press OK to select it

**Expected:**
- Sign Out triggers correctly — app clears auth token and returns to PIN auth screen
- No crash, no navigation to a server list, no unresponsive state

**Recovery:** Re-authenticate via plex.tv/link to continue testing

---

## Test 3: Disconnect Dialog — "Server List" Button Removed

**Steps:**
1. Launch SimPlex and wait for it to connect to the server
2. Disconnect the Plex server (stop PMS service, unplug ethernet, or block the port)
3. Wait for the disconnect dialog to appear

**Expected:**
- Dialog shows a message about server connection failure
- Only one button: "Try Again"
- No "Server List" button present
- Pressing OK on "Try Again" re-attempts the server connection

**Recovery:** Restart PMS, press "Try Again" to reconnect

---

## Test 4: Disconnect Dialog — "Try Again" Reconnects

**Steps:**
1. Trigger disconnect dialog (as in Test 3)
2. Restart the Plex server while the dialog is visible
3. Press OK on "Try Again"

**Expected:**
- App re-tests connectivity to the server
- On success: dialog dismisses, app resumes normal operation (HomeScreen with hub rows)
- On failure: dialog reappears with "Try Again" option again (no dead-end)

---

## Test 5: Multi-Server Account Auto-Connect

**Precondition:** Sign out first, then authenticate with a Plex account that has access to multiple servers.

**Steps:**
1. From the PIN auth screen, complete authentication at plex.tv/link
2. Wait for server discovery to complete

**Expected:**
- App auto-connects to the first server in the list without showing a server selection screen
- HomeScreen loads with hub rows and library content from that server
- Console log shows `LogEvent("Auto-connected to server")` (check via Roku developer console at `http://{roku-ip}:8085`)
- No ServerListScreen appears at any point

---

## Test 6: Multi-Server Auto-Connect Failure

**Precondition:** Sign out, stop the first/primary Plex server, keep a secondary server running.

**Steps:**
1. Complete PIN authentication with a multi-server account
2. Observe behavior when auto-connect to first server fails

**Expected:**
- Console log shows `LogError("Auto-connect failed:")` with a reason string
- App falls back to PIN screen (existing error recovery behavior)
- No crash, no ServerListScreen, no unhandled state

**Recovery:** Start primary server, re-authenticate

---

## Test 7: Other Settings Items Unaffected

**Steps:**
1. Navigate to Settings
2. Select "Hub Libraries" (index 1) — configure hub row libraries
3. Go back, select "Sidebar Libraries" (index 2) — configure sidebar libraries
4. Go back, select "Switch User" (index 3) — switch managed user

**Expected:**
- Each setting navigates to the correct screen/dialog
- Back button returns to SettingsScreen
- No index mismatch (e.g., "Switch User" doesn't trigger Sign Out)

---

## Test 8: Compile Verification (Pre-Deploy)

**Steps:**
1. Run BrighterScript compile via F5 deploy in VSCode
2. Observe build output

**Expected:**
- Zero compile errors
- No warnings about missing references to ServerListScreen
- Side-load completes successfully

---

## Edge Cases

### E1: Rapid Settings Navigation
Navigate in/out of Settings menu quickly 5+ times. No crash, no stuck states.

### E2: Back Button from Settings
Press Back from SettingsScreen. Should return to previous screen (HomeScreen), not navigate to a deleted ServerListScreen.

### E3: Single-Server Account Still Works
Sign in with a single-server Plex account. Should auto-connect as before — behavior is unchanged.

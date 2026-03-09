---
status: complete
phase: 02-authentication
source: [02-01-SUMMARY.md, 02-02-SUMMARY.md, 02-03-SUMMARY.md]
started: 2026-03-08T12:00:00Z
updated: 2026-03-08T12:01:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. PIN Screen Display
expected: On fresh launch (or after signing out), a full-screen PIN screen appears showing a large 4-digit PIN code in gold text, with "plex.tv/link" URL displayed prominently, and a spinning indicator with status text.
result: skipped
reason: Unable to test at this time

### 2. PIN Authentication Completes
expected: After entering the PIN code at plex.tv/link on another device, the app detects authentication automatically (within a few seconds) and proceeds to server selection or home screen without any manual action.
result: skipped
reason: Unable to test at this time

### 3. PIN Auto-Refresh on Expiration
expected: If you wait long enough for the PIN to expire (or if it gets close to expiration), a new PIN code is automatically generated and displayed without needing to restart the flow.
result: skipped
reason: Unable to test at this time

### 4. Back Button Cancels Auth
expected: Pressing the Back button on the remote while on the PIN screen cancels the authentication flow.
result: skipped
reason: Unable to test at this time

### 5. Single Server Auto-Connect
expected: If your Plex account has only one server, the app automatically connects to it after authentication without showing a server selection screen.
result: skipped
reason: Unable to test at this time

### 6. Multiple Server Selection
expected: If your Plex account has multiple servers, a "Select a Server" list appears after authentication showing all server names. Selecting one initiates connection.
result: skipped
reason: Unable to test at this time

### 7. Unreachable Server Feedback
expected: If a selected server cannot be reached, the server name in the list updates to show "(unreachable)" and an error message appears, allowing you to try another server.
result: skipped
reason: Unable to test at this time

### 8. Persistent Login on Relaunch
expected: After successfully authenticating and connecting to a server, closing and reopening the app takes you directly to the home screen without requiring re-authentication.
result: skipped
reason: Unable to test at this time

### 9. 401 Token Expiration Recovery
expected: If your auth token expires (or becomes invalid), the app automatically redirects you back to the PIN screen to re-authenticate when the next API call fails.
result: skipped
reason: Unable to test at this time

### 10. Sign Out
expected: Triggering Sign Out from Settings clears all stored credentials and returns you to the PIN screen.
result: skipped
reason: Unable to test at this time

## Summary

total: 10
passed: 0
issues: 0
pending: 0
skipped: 10

## Gaps

[none yet]

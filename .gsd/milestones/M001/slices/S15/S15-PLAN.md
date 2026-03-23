# S15: Server Switching Removal

**Goal:** Remove "Switch Server" UI and discovery logic from SettingsScreen, patch all 4 codepaths referencing server switching to prevent crashes on multi-server plex.tv accounts.
**Demo:** Settings screen no longer shows server switching option; app works correctly with multi-server plex.tv accounts (auto-connects to first available server); ~80 lines of duplicate discovery logic removed.

## Must-Haves


## Tasks


## Files Likely Touched


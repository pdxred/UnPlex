# Plan 10-01 Summary: Managed Users

**Completed:** 2026-03-10
**Duration:** 4 min

## What was built

### Task 1: Admin token management in utils.brs
- Added `GetAdminToken()` / `SetAdminToken()` for preserving the admin (owner) token
- Added `GetActiveUserName()` / `SetActiveUserName()` for current user display
- Updated `ClearAuthData()` to clear adminToken and activeUserName on sign out

### Task 2: UserAvatarItem component
- Created `UserAvatarItem.xml/.brs` with avatar image, initials fallback, lock badge, and name label
- Lock badge shows "PIN" in accent gold for PIN-protected users
- Initials fallback shows first letter of name when no avatar URL

### Task 3: UserPickerScreen
- Created `UserPickerScreen.xml/.brs` with "Who's watching?" title and MarkupGrid of avatars
- Fetches managed users from `https://plex.tv/api/v2/home/users` using admin token
- PIN entry via `StandardKeyboardDialog` for protected users
- Calls switch endpoint `POST /api/v2/home/users/{id}/switch` with admin token
- On success: updates active auth token and signals `userSwitched`
- On wrong PIN (401): shows error and re-prompts for PIN
- Empty state for no managed users, error handling with silent retry

### Task 4: Settings and MainScene integration
- SettingsScreen now shows: "Signed in as: {userName}", "Switch User", "Switch Server", "Sign Out"
- Switch User routes to UserPickerScreen via MainScene
- `onUserSwitched()` handler calls `clearScreenStack()` + `showHomeScreen()` to reset app
- MainScene `popScreen()` handles UserPickerScreen subtype
- Sign out uses `ClearAuthData()` (clears admin token and user name)

### Additional: PlexApiTask enhancements
- Added `authTokenOverride` field to specify a different token per-request (used for admin token)
- Added `suppress401` flag to prevent auth redirect on wrong PIN (401 = wrong PIN, not expired token)

## Verification
- BrighterScript compilation: zero errors
- All 4 new files created, 5 files modified

## Files changed
- **New:** `SimPlex/components/screens/UserPickerScreen.xml`, `SimPlex/components/screens/UserPickerScreen.brs`
- **New:** `SimPlex/components/widgets/UserAvatarItem.xml`, `SimPlex/components/widgets/UserAvatarItem.brs`
- **Modified:** `SimPlex/source/utils.brs`, `SimPlex/components/screens/SettingsScreen.brs`, `SimPlex/components/MainScene.brs`
- **Modified:** `SimPlex/components/tasks/PlexApiTask.xml`, `SimPlex/components/tasks/PlexApiTask.brs`

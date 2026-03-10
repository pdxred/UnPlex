# Phase 10: Managed Users - Research

**Researched:** 2026-03-10
**Focus:** Plex Home API for managed users, user switching flow, PIN verification, codebase integration points

## Plex API: Managed Users

### Listing Home Users
- **Endpoint:** `GET https://plex.tv/api/v2/home/users`
- **Auth:** Admin account's auth token (X-Plex-Token)
- **Response:** Array of user objects with `id`, `title` (display name), `thumb` (avatar URL), `protected` (boolean, has PIN), `admin` (boolean), `restricted` (boolean)
- **Headers:** Standard X-Plex-* headers required

### Switching to a Managed User
- **Endpoint:** `POST https://plex.tv/api/v2/home/users/{userId}/switch`
- **Auth:** Admin account's auth token
- **Params:** `pin` (string, required if user is protected)
- **Response:** User object with `authToken` field — this is the managed user's token for API calls
- **Error on wrong PIN:** 401 Unauthorized

### PIN Verification
- PIN is passed as a parameter to the switch endpoint, not a separate API call
- If PIN is wrong, the switch fails with 401
- No separate PIN validation endpoint needed

## Codebase Architecture Patterns

### Token Management (utils.brs)
- `GetAuthToken()` reads from `roRegistrySection("SimPlex")` key "authToken"
- `SetAuthToken(token)` writes to registry and flushes
- `GetServerUri()` / `SetServerUri(uri)` same pattern
- `ClearAuthData()` deletes authToken, serverUri, serverClientId
- All API calls use `GetAuthToken()` — changing the stored token changes all subsequent API behavior
- `BuildPlexUrl()` and `BuildPosterUrl()` both use `GetAuthToken()` inline

### Screen Navigation (MainScene.brs)
- `pushScreen(screen)` / `popScreen()` manages screen stack
- `clearScreenStack()` removes all screens, cleans up observers
- `showHomeScreen()` creates fresh HomeScreen and pushes it
- After user switch: `clearScreenStack()` + `showHomeScreen()` resets everything

### SettingsScreen Pattern
- Currently shows: "Switch Server", "Sign Out" in a LabelList
- `onSettingsItemSelected()` routes by index
- Adding "Switch User" means inserting a new item and shifting indices
- SettingsScreen has `authComplete` and `navigateBack` interface fields
- Settings currently doesn't show who is logged in — need to add current user display

### PINScreen Pattern (reference for PIN modal)
- Full-screen component with centered PIN display and polling
- Handles: pinReady, authenticated, error states
- **Not directly reusable for managed user PIN** — PINScreen is for plex.tv/link OAuth, not numeric PIN entry
- Managed user PIN entry needs a different UX: numeric keypad or digit input, not a display code

### PlexAuthTask (tasks/PlexAuthTask.brs)
- Handles: requestPin, checkPin, fetchResources
- Uses plex.tv API endpoints
- Could be extended with new actions: "fetchHomeUsers", "switchUser"
- OR: Use PlexApiTask with `isPlexTvRequest = true` for simpler integration

### PlexApiTask (tasks/PlexApiTask.brs)
- Has `isPlexTvRequest` flag for plex.tv endpoints (vs PMS endpoints)
- Has `method` field for PUT/POST (used in track persistence)
- Can handle managed user API calls with `isPlexTvRequest = true`

## Key Implementation Insights

### User Picker Screen Design
- New UserPickerScreen component with grid of avatar items
- Use MarkupGrid with custom UserAvatarItem component
- Each avatar: 200x200 rounded image + name label below + lock badge if protected
- Center the grid on screen for the "Who's watching?" feel
- Title "Who's watching?" at top

### Admin Token Separation
- When app first authenticates, the token is the admin token
- Need to store admin token separately: `SetAdminToken()` / `GetAdminToken()`
- When switching to managed user: save admin token if not saved, set managed user token as active
- When switching back to admin: restore admin token from saved copy
- Registry keys: "adminToken" (preserved), "authToken" (active user's token)

### User Switch Flow
1. User opens Settings → selects "Switch User"
2. MainScene pushes UserPickerScreen
3. UserPickerScreen fetches home users from plex.tv using admin token
4. User selects an avatar
5. If protected: show PIN entry dialog
6. Call switch endpoint with admin token (+ PIN if needed)
7. On success: SetAuthToken(newToken), clearScreenStack, showHomeScreen
8. On failure: show error, stay on picker

### PIN Entry Component
- Simple numeric input (4 digits typically)
- Not the same as PINScreen (which is for OAuth codes)
- Could be a dialog overlay or inline component
- 4 dot indicators + number pad grid, or simpler: StandardKeyboardDialog with type=PIN
- Roku has `PinEntryDialog` node type for this exact use case — investigate availability
- Fallback: use StandardKeyboardDialog or custom 4-digit input

### File Impact Analysis
- **New files (4):** UserPickerScreen.xml/.brs, UserAvatarItem.xml/.brs
- **Modified files (3):** SettingsScreen.brs, MainScene.brs, utils.brs
- UserPickerScreen handles: user list fetch, avatar grid display, selection, PIN entry, token switch

### Dependency Analysis
- Single plan is sufficient — all work is interdependent (can't test user picker without token switching)
- No wave parallelization needed

## Risks and Mitigations

1. **Admin token loss:** If admin token is not saved before first switch, user can't switch back. Mitigation: Save admin token on first managed user switch, never overwrite it.
2. **Token scope:** Managed user tokens may have restricted access. Mitigation: Test that all existing API calls work with managed user token (library, hubs, playback, scrobble).
3. **No Plex Home:** Account may not have Plex Home enabled (no managed users). Mitigation: Handle empty user list gracefully with message.
4. **PIN dialog on Roku:** Need to verify if Roku has a built-in PinEntryDialog or if custom input is needed. Fallback to StandardKeyboardDialog with numeric mode.

---
*Phase: 10-managed-users*
*Researched: 2026-03-10*

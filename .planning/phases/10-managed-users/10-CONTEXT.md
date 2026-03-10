# Phase 10: Managed Users - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can switch between managed Plex Home users without re-authenticating. A user picker screen shows available users, selecting one switches the active session and reloads content. PIN-protected users require PIN entry before switching. User creation, editing, and profile management are out of scope.

</domain>

<decisions>
## Implementation Decisions

### User picker screen layout
- Grid of user avatars with names below each, similar to Netflix/Plex profile picker
- Each user shows: avatar thumbnail (from Plex API), display name
- PIN-protected users show a lock icon badge on their avatar
- Screen accessible from Settings screen (not sidebar, to keep sidebar clean)
- "Switch User" option in SettingsScreen triggers user picker

### User switching behavior
- Selecting a user replaces the current auth token with the managed user's token
- All screens are cleared (clearScreenStack) and HomeScreen is re-created fresh
- Hub rows, library data, and watch states reload for the new user context
- Current user's display name shown in SettingsScreen for identification
- No confirmation dialog — selecting a user immediately switches (fast flow)

### PIN entry for protected users
- Reuse existing PINScreen component pattern for PIN entry (numeric pad)
- PIN dialog appears as a modal overlay (not a full screen push)
- Incorrect PIN shows error message, allows retry
- No lockout after failed attempts (Plex API handles rate limiting if any)

### Token management
- Admin account token stored separately from active user token
- Admin token used to fetch managed users list (GET /api/v2/home/users)
- Managed user token obtained via POST /api/v2/home/users/{id}/switch with admin token
- Active user token stored in registry for API calls
- Switching back to admin restores the original admin token

### Claude's Discretion
- Exact avatar grid sizing and spacing
- Animation transitions between user picker and home screen
- How to handle users with no avatar (initials fallback vs default icon)
- Whether to show "Who's watching?" on app launch vs only from settings

</decisions>

<specifics>
## Specific Ideas

- User picker should feel like the Plex or Netflix "Who's watching?" screen — simple grid of avatars
- The existing PINScreen already handles numeric PIN entry with the Plex visual style, so reuse that pattern for managed user PIN verification
- Keep it simple: switch user, reload everything, done

</specifics>

<deferred>
## Deferred Ideas

- User-specific settings/preferences per managed user — future enhancement
- Parental controls and content restrictions — separate feature
- Auto-switch to last used user on app launch — future enhancement
- Profile avatar customization — out of scope (managed by Plex server)

</deferred>

---

*Phase: 10-managed-users*
*Context gathered: 2026-03-10*

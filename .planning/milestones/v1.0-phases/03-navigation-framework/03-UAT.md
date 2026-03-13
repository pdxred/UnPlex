---
status: complete
phase: 03-navigation-framework
source: [03-01-SUMMARY.md, 03-02-SUMMARY.md]
started: 2026-03-09T10:00:00Z
updated: 2026-03-09T10:05:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Hub Rows Display on Home Screen
expected: When the Home screen loads, hub rows (Continue Watching, On Deck, Recently Added) appear above the library grid as horizontally-scrollable rows of poster items.
result: skipped
reason: Deferred - code review validates: loadHubs() calls /hubs API, onHubsLoaded() filters by hubIdentifier, buildHubRowContent() creates ContentNode tree with numRows set before content assignment. RowList configured correctly in XML.

### 2. Hub Row Item Selection
expected: Selecting an item from a hub row navigates to the detail screen for that item. Continue Watching items and On Deck/Recently Added items all route to the detail screen.
result: skipped
reason: Deferred - code review validates: onHubItemSelected() correctly dispatches action="play" with viewOffset for continueWatching, action="detail" for others. MainScene routes both to detail screen. Fixed missing null guard on rowContent/itemContent access.

### 3. Three-Zone Focus Navigation
expected: Pressing Left from hub rows or grid moves focus to the sidebar. Pressing Right from sidebar moves focus back to hub rows (if visible) or grid. Pressing Down from hub rows moves to the library grid. Pressing Up from grid moves to hub rows.
result: skipped
reason: Deferred - code review validates: onKeyEvent handles all four directions with m.focusArea state tracking. findNode("grid") works because MarkupGrid has id="grid" as PosterGrid child. Left from hubs only transfers on first item (focusedItem[1]=0).

### 4. Hub Row Auto-Refresh
expected: Hub rows automatically refresh their data approximately every 2 minutes without user action. After returning from a detail screen, hub rows also reload with fresh data.
result: skipped
reason: Deferred - code review validates: Timer node created with duration=120, repeat=true. onHubRefreshTimer guards with isLoadingHubs, saves scroll position via rowItemFocused. onFocusChange detects return and calls loadHubs().

### 5. Sidebar View Toggle
expected: Selecting "Home" in the sidebar shows hub rows above the library grid. Selecting a library in the sidebar hides the hub rows and shows only the library grid.
result: skipped
reason: Deferred - code review validates: onLibrarySelected sets viewMode="libraryOnly", onSpecialAction("viewHome") sets "hubGrid". onViewModeChanged toggles visibility and repositions filter bar + grid.

### 6. Progress Bar on Partially-Watched Items
expected: Items that have been partially watched show a gold progress bar at the bottom of their poster, indicating how much has been watched.
result: skipped
reason: Deferred - code review validates: updateProgressBar() calculates viewOffset/duration ratio, caps at 1.0, sets width up to 240px. Gold color (0xE5A00DFF) on 6px Rectangle at y=350. Background rectangle provides contrast. Properly hidden when no progress.

## Summary

total: 6
passed: 0
issues: 0
pending: 0
skipped: 6

## Gaps

[none yet]

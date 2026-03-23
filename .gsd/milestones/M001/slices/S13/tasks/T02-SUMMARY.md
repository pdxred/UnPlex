---
id: T02
parent: S13
milestone: M001
provides:
  - Sidebar exposes loaded libraries via interface field for cross-component access
  - Collections navigation auto-selects first library when none previously selected
key_files:
  - SimPlex/components/widgets/Sidebar.xml
  - SimPlex/components/widgets/Sidebar.brs
  - SimPlex/components/screens/HomeScreen.brs
key_decisions:
  - Libraries exposed as assocarray with items array (not ContentNode) for simplicity and cross-component readability
  - Guard remains on m.currentSectionId after auto-select — if libraries haven't loaded yet, tap is a no-op (safe default)
patterns_established:
  - Sidebar.libraries interface field pattern — any parent component can read loaded library metadata without reaching into Sidebar internals
observability_surfaces:
  - m.sidebar.libraries in SceneGraph inspector shows loaded library list (invalid if fetch pending, empty items if no supported libraries)
  - Roku debug console prints "Collections auto-selected library: {title} (section {key})" when fallback fires
duration: 8m
verification_result: passed
completed_at: 2026-03-23
blocker_discovered: false
---

# T02: Fix collections navigation — auto-select first library when none active

**Sidebar now exposes libraries via interface field; HomeScreen auto-selects first library for Collections when no library previously selected (FIX-04)**

## What Happened

Implemented three changes across three files to fix FIX-04 (Collections silently does nothing from Home hub):

1. **Sidebar.xml** — Added `libraries` assocarray interface field with `alwaysNotify="true"` so HomeScreen can read the loaded library list.

2. **Sidebar.brs** — In `processLibraries()`, after building `m.libraries` and setting `m.libraryCount`, added a loop that serializes library metadata (key, type, title) into `m.top.libraries = { items: libList }`. This makes the library list accessible across component boundaries without requiring SceneGraph node traversal.

3. **HomeScreen.brs** — In `onSpecialAction("viewCollections")`, added an auto-select block before the existing guard: when `m.currentSectionId` is empty, reads `m.sidebar.libraries`, extracts the first library's key/type, and sets `m.currentSectionId` and `m.currentSectionType`. The existing `if m.currentSectionId <> ""` guard remains as a safety check — if libraries haven't loaded yet (sidebar fetch in progress), the tap is still a no-op. Added a diagnostic `print` statement for the Roku debug console when auto-selection fires.

## Verification

All task-level verification checks pass:

- `grep -c "libraries" Sidebar.xml` → 1 (≥1 required) ✓
- `grep -c "m.top.libraries" Sidebar.brs` → 1 (≥1 required) ✓
- `grep -c "m.sidebar.libraries" HomeScreen.brs` → 1 (≥1 required) ✓
- The `viewCollections` block now handles empty `m.currentSectionId` via auto-select before the guard ✓
- Guard against `sidebarLibs = invalid` and empty items array present ✓

Slice-level check 3 (Collections from Home with no library selected) is code-verified — the handler now auto-selects the first library. Sideload verification deferred to device testing. All slice-level code review checks also pass.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `grep -c "libraries" SimPlex/components/widgets/Sidebar.xml` | 0 | ✅ pass (1 ≥ 1) | <1s |
| 2 | `grep -c "m.top.libraries" SimPlex/components/widgets/Sidebar.brs` | 0 | ✅ pass (1 ≥ 1) | <1s |
| 3 | `grep -c "m.sidebar.libraries" SimPlex/components/screens/HomeScreen.brs` | 0 | ✅ pass (1 ≥ 1) | <1s |
| 4 | `grep -n "m.sidebar.libraries\|m.top.libraries" Sidebar.brs HomeScreen.brs` | 0 | ✅ pass (wiring confirmed) | <1s |
| 5 | `grep -n "libraries" SimPlex/components/widgets/Sidebar.xml` | 0 | ✅ pass (interface field at line 6) | <1s |

## Diagnostics

- **Libraries field:** Inspect `m.sidebar.libraries` in the SceneGraph inspector. If `invalid`, the library fetch hasn't completed yet. If `.items` is an empty array, the server returned no supported (movie/show) libraries.
- **Auto-select trace:** When Collections is tapped with no library selected, the Roku debug console will print `"Collections auto-selected library: {title} (section {key})"` confirming which library was chosen.
- **Failure path:** If libraries haven't loaded when Collections is tapped, `m.sidebar.libraries` will be `invalid` and the handler remains a no-op. No error dialog is shown — this matches prior behavior and is acceptable since the user can retry once the sidebar finishes loading.

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `SimPlex/components/widgets/Sidebar.xml` — Added `libraries` assocarray interface field
- `SimPlex/components/widgets/Sidebar.brs` — Set `m.top.libraries` with serialized library list after processLibraries()
- `SimPlex/components/screens/HomeScreen.brs` — Auto-select first library in viewCollections handler when m.currentSectionId is empty
- `.gsd/milestones/M001/slices/S13/tasks/T02-PLAN.md` — Added Observability Impact section (pre-flight fix)
- `.gsd/milestones/M001/slices/S13/S13-PLAN.md` — Marked T02 as complete

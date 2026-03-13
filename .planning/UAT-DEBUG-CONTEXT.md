# UAT Debug Context - HomeScreen SIGSEGV Crash

## Status: RESOLVED - Root cause confirmed, fix applied

## Root Cause (Confirmed)

**BusySpinner native component causes SIGSEGV ~3s after init on Roku hardware.**

- The `BusySpinner` SceneGraph node type triggers a firmware-level crash (SIGSEGV, signal 11) approximately 3 seconds after it is added to the scene graph.
- Animation nodes (`<Animation>`, `<FloatFieldInterpolator>`) are **safe** — confirmed by 5 days of production use since v1.0 shipped 2026-03-08.
- The fix: replace every `<BusySpinner>` with `<Label>` + `<Rectangle>` overlay in the `LoadingSpinner` widget and `VideoPlayer` widget.

## Crash Bisection Results

| Test | Components | Result |
|------|-----------|--------|
| TEST1 | Rectangle + Label only | PASS |
| TEST2 | + Sidebar | PASS |
| TEST2b | + Sidebar + FilterBar + PosterGrid | PASS |
| TEST3 | + ALL UI (spinner, animations, empty/retry states) | CRASH (3s after init) |
| TEST4a | All UI EXCEPT LoadingSpinner and fade animations | PASS |
| **TEST4b** | TEST4a + fade animations (no spinner) | **PASS** (confirmed by 5 days production use) |

## What's Been Fixed (committed)

1. **PINScreen auth flow** - Fresh PlexAuthTask for resource fetch (task reuse unreliable on Roku)
2. **PlexAuthTask** - Async HTTP with 15s timeout for server discovery
3. **ServerConnectionTask** - Direct IP fallback when plex.direct DNS fails
4. **VideoPlayer** - `pos` renamed to `currentPos` (BrightScript reserved word conflict)
5. **visible field shadowing** - LoadingSpinner, FilterBottomSheet, TrackSelectionPanel all had `<field id="visible" onChange="...">` in their interface, which shadows the built-in Node.visible field. Renamed to `showSpinner`, `showSheet`, `showPanel` respectively. All 37 references across 7 screen files updated.
6. **LoadingSpinner widget** (Phase 11, Plan 01) - Replaced `<BusySpinner>` with safe `<Label>` + `<Rectangle>` overlay with 300ms delay threshold. All 7 screens re-enabled to use LoadingSpinner.
7. **VideoPlayer transcodingSpinner** (Phase 11, Plan 01) - Replaced `<BusySpinner id="transcodingSpinner">` with safe `<Label>` alternative.

## Current State (post Phase 11-01)

- `HomeScreen.brs` and `HomeScreen.xml` are fully restored with LoadingSpinner re-enabled
- `HomeScreen.brs.bak` and `HomeScreen.xml.bak` deleted (no longer needed)
- `LoadingSpinner.xml` — uses `<Label>` + `<Rectangle>` overlay (no BusySpinner anywhere)
- `VideoPlayer.xml` — uses `<Label>` for transcodingSpinner (no BusySpinner anywhere)
- All 7 screens have `<LoadingSpinner id="loadingSpinner" />` in XML and wire it in init()

## Build Command

```powershell
cd "C:/Users/TobyHorton/OneDrive - Owlfarm/Dev/SimPlex"
Remove-Item 'SimPlex.zip' -ErrorAction SilentlyContinue
Compress-Archive -Path 'SimPlex/manifest','SimPlex/source','SimPlex/components','SimPlex/images' -DestinationPath 'SimPlex.zip' -Force
```

## Roku Debug Console

Telnet to Roku IP on port 8085 for crash logs.

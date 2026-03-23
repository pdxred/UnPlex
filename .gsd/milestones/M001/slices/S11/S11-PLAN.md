# S11: Crash Safety And Foundation

**Goal:** Confirm BusySpinner SIGSEGV root cause, replace the crashed component with a safe loading indicator, assess VideoPlayer's transcodingSpinner, and delete confirmed orphaned files.
**Demo:** Confirm BusySpinner SIGSEGV root cause, replace the crashed component with a safe loading indicator, assess VideoPlayer's transcodingSpinner, and delete confirmed orphaned files.

## Must-Haves


## Tasks

- [x] **T01: 11-crash-safety-and-foundation 01** `est:18min`
  - Confirm BusySpinner SIGSEGV root cause, replace the crashed component with a safe loading indicator, assess VideoPlayer's transcodingSpinner, and delete confirmed orphaned files.

Purpose: This is the crash safety gate for all v1.1 work. No screen changes are safe until the SIGSEGV root cause is confirmed and a safe loading pattern is established.
Output: Safe LoadingSpinner widget, crash root cause documented, orphaned files deleted.
- [x] **T02: 11-crash-safety-and-foundation 02** `est:8min`
  - Extract GetRatingKeyStr() to utils.brs, replace all 13+ inline duplicates across 6 files, and fix the hardcoded progress bar width in PosterGridItem.

Purpose: Eliminate duplicated utility code and use constants instead of magic numbers, making the codebase maintainable for v1.1 screen work.
Output: Single GetRatingKeyStr() in utils.brs, all inline blocks replaced, progress bar using POSTER_WIDTH constant.

## Files Likely Touched

- `SimPlex/components/widgets/LoadingSpinner.xml`
- `SimPlex/components/widgets/LoadingSpinner.brs`
- `SimPlex/components/screens/HomeScreen.xml`
- `SimPlex/components/screens/HomeScreen.brs`
- `SimPlex/components/screens/DetailScreen.brs`
- `SimPlex/components/screens/EpisodeScreen.brs`
- `SimPlex/components/screens/PlaylistScreen.brs`
- `SimPlex/components/screens/SearchScreen.brs`
- `SimPlex/components/screens/SettingsScreen.brs`
- `SimPlex/components/screens/UserPickerScreen.brs`
- `SimPlex/components/widgets/VideoPlayer.xml`
- `SimPlex/components/widgets/VideoPlayer.brs`
- `SimPlex/source/normalizers.brs`
- `SimPlex/source/capabilities.brs`
- `SimPlex/source/utils.brs`
- `SimPlex/components/screens/DetailScreen.brs`
- `SimPlex/components/screens/EpisodeScreen.brs`
- `SimPlex/components/screens/HomeScreen.brs`
- `SimPlex/components/screens/PlaylistScreen.brs`
- `SimPlex/components/screens/SearchScreen.brs`
- `SimPlex/components/widgets/VideoPlayer.brs`
- `SimPlex/components/widgets/PosterGridItem.brs`

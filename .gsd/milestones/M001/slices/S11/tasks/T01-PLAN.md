# T01: 11-crash-safety-and-foundation 01

**Slice:** S11 — **Milestone:** M001

## Description

Confirm BusySpinner SIGSEGV root cause, replace the crashed component with a safe loading indicator, assess VideoPlayer's transcodingSpinner, and delete confirmed orphaned files.

Purpose: This is the crash safety gate for all v1.1 work. No screen changes are safe until the SIGSEGV root cause is confirmed and a safe loading pattern is established.
Output: Safe LoadingSpinner widget, crash root cause documented, orphaned files deleted.

## Must-Haves

- [ ] "BusySpinner SIGSEGV root cause is confirmed and documented"
- [ ] "All screens use a safe loading indicator (no BusySpinner in scene graph)"
- [ ] "The app compiles and sideloads cleanly with normalizers.brs and capabilities.brs deleted"
- [ ] "VideoPlayer transcodingSpinner is assessed and replaced if it also crashes"

## Files

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

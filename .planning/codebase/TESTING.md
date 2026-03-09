# Testing Patterns

**Analysis Date:** 2026-03-08

## Test Framework

**Runner:**
- None detected. No test framework is configured or present in this project.

**Assertion Library:**
- None

**Run Commands:**
```bash
# No test commands available
# No package.json, Makefile, or test configuration files exist
```

## Test File Organization

**Location:**
- No test files exist anywhere in the codebase
- No `*.test.*`, `*.spec.*`, or `*_test.*` files found
- No `tests/`, `test/`, `__tests__/`, or `spec/` directories exist

**Naming:**
- Not established

## Test Structure

**No tests exist.** The project has zero automated test coverage.

## BrightScript Testing Options

BrightScript/Roku testing is a specialized domain. The primary testing frameworks available for this platform are:

**Unit Testing:**
- [roku-test-automation](https://github.com/nicholasgasior/roku-test-automation) - Roku unit test framework
- [rooibos](https://github.com/georgejecook/rooibos) - BrightScript testing framework (most popular)
  - Provides `@describe`, `@it`, `@expect` annotations
  - Supports mocking, stubbing, parameterized tests
  - Integrates with VS Code via BrighterScript

**Integration/E2E Testing:**
- [Roku Automated Channel Testing](https://developer.roku.com/docs/developer-program/dev-tools/automated-channel-testing.md) - Official Roku tool
  - Uses Roku's External Control Protocol (ECP)
  - Controls device remotely for UI testing
  - Robot Framework based

## What Should Be Tested

**Priority areas if tests are added:**

**High Priority - Pure logic functions (unit-testable):**
- `SafeGet()` and `SafeGetMetadata()` in `SimPlex/source/utils.brs` - null safety logic
- `FormatTime()` and `PadZero()` in `SimPlex/source/utils.brs` - time formatting
- `BuildPlexUrl()` and `BuildPosterUrl()` in `SimPlex/source/utils.brs` - URL construction
- `GetPlexHeaders()` in `SimPlex/source/utils.brs` - header building
- `ParseServerCapabilities()`, `HasCapability()`, `MeetsMinVersion()` in `SimPlex/source/capabilities.brs` - version parsing and comparison
- All normalizer functions in `SimPlex/source/normalizers.brs` - JSON to ContentNode conversion

**Medium Priority - Component logic:**
- `checkDirectPlay()` in `SimPlex/components/widgets/VideoPlayer.brs` - codec compatibility detection
- `getStreamFormat()` in `SimPlex/components/widgets/VideoPlayer.brs` - container format mapping
- `parseServerList()` and `parseConnections()` in `SimPlex/components/tasks/PlexAuthTask.brs` - server discovery parsing
- ratingKey type coercion logic (duplicated across multiple files)

**Lower Priority - Integration/E2E:**
- Screen navigation flow (push/pop screen stack)
- Authentication flow (PIN request, polling, server discovery)
- Library browsing with pagination
- Search with debounce
- Playback start/stop/resume

## Mocking

**Framework:** Not applicable (no tests exist)

**What Would Need Mocking:**
- `roUrlTransfer` - HTTP requests (all API calls)
- `roRegistrySection` - Persistent storage (auth tokens, server URI)
- `roDeviceInfo` - Device information (model, OS version, UUID)
- `CreateObject("roSGNode", ...)` - SceneGraph node creation
- `m.global` - Global node state

## Coverage

**Requirements:** None enforced
**Current Coverage:** 0% - no tests exist

## Recommended Test Setup

If adding tests to this project, use **rooibos** (the standard BrightScript test framework):

**Installation:**
- Requires BrighterScript compiler (`npm install brighterscript`)
- Add rooibos via `npm install rooibos-roku`
- Configure in `bsconfig.json`

**Example test pattern (rooibos style):**
```brightscript
'@describe SafeGet utility
'@it returns default when obj is invalid
function test_SafeGet_invalid_obj()
    result = SafeGet(invalid, "field", "default")
    m.assertEqual(result, "default")
end function

'@it returns field value when present
function test_SafeGet_valid_field()
    obj = { name: "test" }
    result = SafeGet(obj, "name", "default")
    m.assertEqual(result, "test")
end function

'@it returns default when field missing
function test_SafeGet_missing_field()
    obj = { name: "test" }
    result = SafeGet(obj, "missing", "fallback")
    m.assertEqual(result, "fallback")
end function
```

**Example for FormatTime:**
```brightscript
'@describe FormatTime
'@it formats milliseconds to MM:SS
function test_FormatTime_minutes()
    result = FormatTime(125000)
    m.assertEqual(result, "2:05")
end function

'@it formats milliseconds to HH:MM:SS when over an hour
function test_FormatTime_hours()
    result = FormatTime(3725000)
    m.assertEqual(result, "1:02:05")
end function
```

## Manual Testing

**Current testing approach is entirely manual:**

1. Side-load to Roku device in developer mode:
   ```bash
   cd SimPlex && zip -r ../SimPlex.zip manifest source components images
   # Upload to http://{roku-ip}:8060
   ```

2. Use Roku developer console for debug output:
   - `telnet {roku-ip} 8085` for BrightScript debug console
   - `print` statements (via `LogEvent`/`LogError`) visible in console

3. No CI/CD pipeline exists - no automated build or test steps

---

*Testing analysis: 2026-03-08*

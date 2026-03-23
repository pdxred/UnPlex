# Phase 11: Crash Safety and Foundation - Research

**Researched:** 2026-03-13
**Domain:** BrightScript / Roku SceneGraph — crash diagnosis, dead code removal, utility extraction
**Confidence:** HIGH — all findings based on direct codebase inspection

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Loading state pattern: Centered spinner, full screen center (overlaying sidebar and content area). Only show spinner if content takes longer than ~300ms to arrive (delay threshold — avoid flash on fast loads). Block user input while loading — no navigation allowed until load completes or fails.
- BusySpinner investigation: Full root cause investigation — find the exact SIGSEGV trigger condition. Critical: Validate all assumptions against the current codebase before making changes — the crash may already be fixed by prior work. If already fixed, reassess whether any additional changes are needed.
- Utility extraction: Validate that duplicates actually exist in current code before extracting anything. If obvious duplicates are found during investigation beyond GetRatingKeyStr(), OK to consolidate them. Orphaned files (normalizers.brs, capabilities.brs) must be verified unused via grep before deletion.

### Claude's Discretion
- Whether to document the BusySpinner root cause (depends on what's found during investigation)
- Where shared utilities live — keep in utils.brs or split by concern based on file size
- Exact spinner visual style and animation
- Compression algorithm for delay threshold timing

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SAFE-01 | BusySpinner SIGSEGV root cause confirmed and resolved (safe loading states across all screens) | BusySpinner removal is already done across all screens — TEST4b result must be confirmed; LoadingSpinner widget still exists and must be replaced or removed |
| SAFE-02 | Orphaned files deleted (normalizers.brs, capabilities.brs) | Grep confirms zero call-sites for any function in either file — safe to delete |
| SAFE-03 | Utility code cleanup (extract common helpers, remove dead code patterns) | getRatingKeyString exists locally in DetailScreen; identical 4-line inline pattern exists in EpisodeScreen (5x), HomeScreen (4x), PlaylistScreen (1x), SearchScreen (1x), VideoPlayer (1x) — extract to GetRatingKeyStr() in utils.brs |
| FIX-07 | Progress bar width uses constant instead of hardcoded 240px | PosterGridItem.brs line 57 uses Int(240 * progress) — replace with Int(m.constants.POSTER_WIDTH * progress) |
</phase_requirements>

---

## Summary

This phase is a stabilisation and cleanup pass with no new user-facing features. The research reveals that the BusySpinner workaround is already substantially implemented: every screen has `m.loadingSpinner = invalid` and no screen XML instantiates `LoadingSpinner`. The crash bisection left off at TEST4b (animations added, no spinner) which was marked "PENDING — ready to test". Phase 11 must confirm whether TEST4b passed on device, then document the confirmed root cause, and decide whether to restore a safe loading indicator.

The two orphaned files (`normalizers.brs`, `capabilities.brs`) are confirmed dead — grep finds no call-sites for any of their functions anywhere in the project. Deletion is safe after one final grep verification at task time. The utility duplication is significant: the ratingKey-to-string conversion pattern (5-line inline block with type check) appears in six different files with between one and five occurrences each. A single `GetRatingKeyStr()` in `utils.brs` replaces all of them. The progress bar constant fix is a one-line change in `PosterGridItem.brs`.

**Primary recommendation:** Run TEST4b device validation first (or confirm it already passed). If the app loads cleanly with the current HomeScreen.xml (animations present, no BusySpinner), document that as the confirmed fix and proceed to implement a safe replacement loading indicator per the locked decisions. Then delete the orphaned files, extract `GetRatingKeyStr()`, and fix the progress bar constant.

---

## Current Codebase State (Pre-Phase)

This section documents what ALREADY EXISTS vs what still needs doing, since the user's key instruction is "validate assumptions against the codebase before changing anything."

### SAFE-01: BusySpinner — Partially Done, Needs Confirmation

**What is already done:**
- All 7 screen `.brs` files set `m.loadingSpinner = invalid` and comment "BusySpinner causes firmware SIGSEGV crashes on Roku"
- No screen XML file instantiates `<LoadingSpinner>` (grep confirms zero matches in `components/screens/*.xml`)
- HomeScreen.xml is in TEST4b state: has `<Animation>` nodes (gridFadeIn/gridFadeOut) but no LoadingSpinner
- UAT-DEBUG-CONTEXT.md records the crash bisection: TEST4a (no spinner, no animations) PASSED; TEST4b (no spinner, with animations) was PENDING

**What still needs doing:**
- Confirm whether TEST4b passed on device (or run it now) — this settles whether Animation nodes are safe
- Document the confirmed root cause (BusySpinner specifically, not Animation nodes)
- Decide whether to restore a proper loading indicator using a safe replacement pattern
- `LoadingSpinner.xml` and `LoadingSpinner.brs` still exist in `components/widgets/` — their fate depends on whether a replacement safe spinner is built using them or they are removed

**Crash evidence summary:**
- TEST3 (ALL UI including spinner + animations): CRASH at 3 seconds after init
- TEST4a (no spinner, no animations): PASS
- TEST4b (no spinner, with animations): PENDING
- Conclusion pending device test: crash is BusySpinner (most likely) OR Animation nodes in combination

**VideoPlayer exception:** `VideoPlayer.xml` still contains a `<BusySpinner id="transcodingSpinner">` inside the transcode pivot overlay. This is a different usage — only shown during subtitle stream switching, not during initial load. Whether this also crashes is an open question for this phase.

### SAFE-02: Orphaned Files — Confirmed Deletable

**normalizers.brs** (132 lines): Defines `NormalizeMovieList`, `NormalizeShowList`, `NormalizeSeasonList`, `NormalizeEpisodeList`, `NormalizeOnDeck`. Grep confirms none of these functions are called anywhere in the project. The app does its own inline JSON-to-node conversion in each screen's API response handler.

**capabilities.brs** (97 lines): Defines `ParseServerCapabilities`, `HasCapability`, `GetMinVersionForFeature`, `MeetsMinVersion`. Grep confirms none of these are called anywhere. The app does not currently implement server capability gating.

**Verification command (run at task time):**
```bash
grep -r "NormalizeMovieList\|NormalizeShowList\|NormalizeSeasonList\|NormalizeEpisodeList\|NormalizeOnDeck\|ParseServerCapabilities\|HasCapability\|GetMinVersionForFeature\|MeetsMinVersion" SimPlex/
```
Expected result: zero matches outside the files themselves.

### SAFE-03: Utility Extraction — Duplicates Confirmed

**getRatingKeyString in DetailScreen.brs (lines 371–376):**
```brightscript
function getRatingKeyString(ratingKey as Dynamic) as String
    if ratingKey = invalid then return ""
    if type(ratingKey) = "roString" or type(ratingKey) = "String"
        return ratingKey
    end if
    return ratingKey.ToStr()
end function
```
This is the canonical version — already a named function, but local to DetailScreen.

**Inline 4-line version (appears 13 times across 5 files):**
```brightscript
ratingKeyStr = ""
if item.ratingKey <> invalid
    if type(item.ratingKey) = "roString" or type(item.ratingKey) = "String"
        ratingKeyStr = item.ratingKey
    else
        ratingKeyStr = item.ratingKey.ToStr()
    end if
end if
```

Occurrences by file:
| File | Count |
|------|-------|
| EpisodeScreen.brs | 5 (lines 179-183, 217-221, 273-277, 420-424, 447-451, 472-476) |
| HomeScreen.brs | 4 (lines 356-361, 650-656, 824-829, 965-970) |
| VideoPlayer.brs | 1 (lines 1120-1125) |
| PlaylistScreen.brs | 1 (lines 107-112) |
| SearchScreen.brs | 1 (lines 131-136) |

The function name in utils.brs should be `GetRatingKeyStr` (capitalised to match BrightScript shared function convention per CLAUDE.md).

### FIX-07: Progress Bar Hardcoded Width — Confirmed

**PosterGridItem.brs line 57:**
```brightscript
m.progressFill.width = Int(240 * progress)
```

**Fix:**
```brightscript
m.progressFill.width = Int(m.constants.POSTER_WIDTH * progress)
```

`m.constants` is already cached in `init()` at line 10 (`m.constants = m.global.constants`). The constant value is `POSTER_WIDTH: 240` in `constants.brs`. This is a one-line change.

---

## Architecture Patterns

### BrightScript Shared Function Convention
Functions in `utils.brs` are available to all SceneGraph components that include `<script type="text/brightscript" uri="pkg:/source/utils.brs" />`. All screen and widget XML files already include this tag. A function added to `utils.brs` is immediately available everywhere.

Naming convention in this codebase: CamelCase with capital first letter for shared utilities (e.g., `GetAuthToken`, `BuildPlexUrl`, `SafeGet`, `SafeGetMetadata`, `FormatTime`).

The new function should be:
```brightscript
' Convert a ratingKey value (string or integer from JSON) to a guaranteed String
' Plex API returns ratingKey as integer in some endpoints, string in others
function GetRatingKeyStr(ratingKey as Dynamic) as String
    if ratingKey = invalid then return ""
    if type(ratingKey) = "roString" or type(ratingKey) = "String"
        return ratingKey
    end if
    return ratingKey.ToStr()
end function
```

### Safe Loading Indicator Pattern
Per locked decisions: the replacement loading indicator must:
1. Only appear after ~300ms delay (avoid flash on fast loads)
2. Block user input while loading
3. Be positioned full-screen center (overlay sidebar and content area)

Because BusySpinner crashes, the safe options are:
- **Animated Poster**: A rotating image using `<Poster>` with CSS-like rotation via an Animation node (if TEST4b passes, Animation is safe)
- **Text-based indicator**: A `<Label>` with "..." or a dots-cycling animation in BrightScript (zero firmware risk)
- **Rectangle overlay + Label**: Dim the screen with a semi-transparent Rectangle, show status text

ServerListScreen already uses the text-based approach (`<Label id="spinner" text="...">` toggled visible). This pattern is proven safe.

The delay threshold can be implemented with a simple timer check: record the load start time, only set spinner visible if elapsed > 300ms when checking in the observer.

### SceneGraph Component Lifecycle
- `init()` runs when the component is created/attached to the scene graph
- `m.top.findNode("id")` returns `invalid` if the node doesn't exist in XML — this is why `if m.loadingSpinner <> invalid` guards work correctly
- The guard pattern `if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true` is already in place everywhere — any replacement just needs to be assigned to `m.loadingSpinner` in `init()` to activate

### BusySpinner Crash (SIGSEGV)
The crash is a native firmware crash (signal 11), not a BrightScript error. BusySpinner is a built-in Roku component (`roSGNode` type "BusySpinner") that wraps a native animation. The crash occurs approximately 3 seconds after init, suggesting the animation timer fires and hits a firmware bug. This is not reproducible in the Roku emulator — must be validated on device.

The workaround (removing BusySpinner from scene graph entirely) is proven by TEST4a passing. The question is whether Animation nodes are also implicated, which TEST4b resolves.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Loading animation | Custom frame-by-frame Poster swap | `<Animation>` node with `FloatFieldInterpolator` on opacity | Animation nodes handle the timing; already in use in HomeScreen.xml |
| Input blocking during load | Custom key intercept state machine | Set focus to an invisible intercept group while loading | Standard Roku pattern — focused node receives all keys |
| ratingKey type coercion | New type system | `GetRatingKeyStr()` in utils.brs | Already solved; just needs extracting |

---

## Common Pitfalls

### Pitfall 1: Assuming the BusySpinner crash is fully fixed
**What goes wrong:** Executor skips crash confirmation because screens are already guarded with `m.loadingSpinner = invalid`, and ships phase without validating TEST4b.
**Why it happens:** The workaround looks complete in code; the device test result isn't stored anywhere except UAT-DEBUG-CONTEXT.md which says "PENDING."
**How to avoid:** The first task in this phase must explicitly confirm TEST4b result on device (or acknowledge it was confirmed and document the outcome).
**Warning signs:** No test result documented in SAFE-01 success criteria.

### Pitfall 2: Deleting normalizers.brs/capabilities.brs without re-verifying grep
**What goes wrong:** Files are deleted, then someone adds a call to NormalizeMovieList in a later phase thinking it's available.
**Why it happens:** The functions are well-named and look useful — future developers may try to call them.
**How to avoid:** Verify grep at deletion time. After deletion, if future phases need normalization helpers, they should be added to utils.brs or a new file.

### Pitfall 3: GetRatingKeyStr naming inconsistency
**What goes wrong:** Existing calls to `getRatingKeyString` in DetailScreen.brs are NOT updated after adding `GetRatingKeyStr` to utils.brs, leaving two functions doing the same thing.
**Why it happens:** DetailScreen.brs has a local `getRatingKeyString` function (lowercase 'g') — it's easy to miss since it's local scope.
**How to avoid:** After adding `GetRatingKeyStr` to utils.brs, update all 6 call-sites in DetailScreen.brs and delete the local `getRatingKeyString` function.

### Pitfall 4: VideoPlayer BusySpinner left unexamined
**What goes wrong:** The `<BusySpinner id="transcodingSpinner">` in VideoPlayer.xml is not investigated. If it also crashes, subtitle switching will crash the app.
**Why it happens:** The crash investigation focused on HomeScreen; VideoPlayer's spinner is different (inside a transcode overlay, not the main loading path).
**How to avoid:** During SAFE-01 investigation, examine VideoPlayer.xml and assess whether the transcodingSpinner needs the same treatment.

### Pitfall 5: Hardcoded 240 in PosterGrid.xml not caught
**What goes wrong:** FIX-07 fixes the `.brs` line but misses the XML declarations `width="240"` in PosterGridItem.xml.
**Why it happens:** XML attributes can't use constants — they're hardcoded by design. The requirement is specifically about the BrightScript `.width` property assignment at runtime.
**How to avoid:** FIX-07 scope is the runtime width calculation in `updateProgressBar()` only. The XML attribute `width="240"` on the Poster and Label nodes is correct (those don't change dynamically).

---

## Code Examples

### GetRatingKeyStr — Canonical Implementation for utils.brs
```brightscript
' Convert a ratingKey value to a guaranteed non-invalid String.
' Plex API returns ratingKey as integer in some responses, string in others.
' Usage: ratingKeyStr = GetRatingKeyStr(item.ratingKey)
function GetRatingKeyStr(ratingKey as Dynamic) as String
    if ratingKey = invalid then return ""
    if type(ratingKey) = "roString" or type(ratingKey) = "String"
        return ratingKey
    end if
    return ratingKey.ToStr()
end function
```

### FIX-07 — PosterGridItem.brs updateProgressBar()
Before:
```brightscript
m.progressFill.width = Int(240 * progress)
```
After:
```brightscript
m.progressFill.width = Int(m.constants.POSTER_WIDTH * progress)
```

### Safe Loading Indicator — Text-Based Pattern (if BusySpinner not replaced)
In screen XML:
```xml
<Label
    id="loadingLabel"
    text="Loading..."
    translation="[960, 540]"
    horizAlign="center"
    vertAlign="center"
    font="font:MediumSystemFont"
    color="0xA0A0B0FF"
    visible="false"
/>
```
In screen .brs init():
```brightscript
m.loadingSpinner = m.top.findNode("loadingLabel")
```
The existing `if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true` guards won't work with a Label (wrong field name) — this pattern only works if the replacement implements a `showSpinner` field observer, OR if the call sites are updated. Since the LoadingSpinner widget wrapper already provides the `showSpinner` interface, the simplest path is to replace BusySpinner inside LoadingSpinner.xml with a safe alternative.

### LoadingSpinner Widget — Safe Replacement for BusySpinner
Replace `LoadingSpinner.xml` BusySpinner with a text label:
```xml
<component name="LoadingSpinner" extends="Group">
    <interface>
        <field id="showSpinner" type="boolean" value="false" onChange="onShowSpinnerChange" />
    </interface>
    <script type="text/brightscript" uri="LoadingSpinner.brs" />
    <children>
        <Rectangle
            id="overlay"
            width="1920"
            height="1080"
            color="0x00000066"
            visible="false"
        />
        <Label
            id="spinner"
            translation="[960, 530]"
            text="Loading..."
            horizAlign="center"
            font="font:MediumSystemFont"
            color="0xA0A0B0FF"
            visible="false"
        />
    </children>
</component>
```
The `.brs` file remains the same (it sets `m.spinner.visible` which works for both BusySpinner and Label). The `m.spinner.control = "start"/"stop"` lines become no-ops (Label ignores unknown field sets) — or remove them from the .brs.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| LoadingSpinner with BusySpinner in XML | m.loadingSpinner = invalid, no spinner instantiated | During v1.0 UAT (TEST4a) | App loads without crash; no loading feedback currently |
| Inline ratingKey type check (4 lines, repeated) | Still inline — not yet extracted | Phase 11 scope | SAFE-03 requires extracting to GetRatingKeyStr() |
| normalizers.brs / capabilities.brs in source/ | Still present, never called | Phase 11 scope | SAFE-02 requires deletion |

---

## Open Questions

1. **Did TEST4b pass on device?**
   - What we know: TEST4b zip was built with animations but no BusySpinner; UAT stopped before testing
   - What's unclear: Whether Animation nodes cause any crashes
   - Recommendation: First task confirms this. If TEST4b passes, Animation nodes are safe and a Poster-based animated spinner is viable. If it crashes, the safe path is text-only.

2. **Does VideoPlayer's transcodingSpinner crash on subtitle switch?**
   - What we know: VideoPlayer.xml has `<BusySpinner id="transcodingSpinner">` inside transcodingOverlay; this is only shown during PGS subtitle switching
   - What's unclear: Whether it also triggers SIGSEGV
   - Recommendation: Investigate during SAFE-01. If yes, replace with a label inside the overlay. If no (different context than load-time crash), document and defer.

3. **Should LoadingSpinner widget be restored after fixing root cause?**
   - What we know: All screens already have the guard pattern `if m.loadingSpinner <> invalid`; restoring is mechanical
   - What's unclear: Depends on TEST4b outcome and what safe replacement is chosen
   - Recommendation: Per locked decisions, yes — a safe loading indicator is required. Use the LoadingSpinner wrapper with BusySpinner replaced.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection — all findings are from reading actual source files
- `SimPlex/components/screens/*.brs` — LoadingSpinner removal already done
- `SimPlex/source/normalizers.brs`, `SimPlex/source/capabilities.brs` — confirmed no callers
- `SimPlex/components/widgets/PosterGridItem.brs:57` — confirmed hardcoded 240
- `SimPlex/components/screens/DetailScreen.brs:371-376` — getRatingKeyString local function
- `.planning/UAT-DEBUG-CONTEXT.md` — crash bisection history and TEST4b status

### Secondary (MEDIUM confidence)
- Roku SceneGraph BusySpinner crash behavior — based on TEST results documented in UAT-DEBUG-CONTEXT.md (SIGSEGV at ~3s after init)

### Tertiary (LOW confidence)
- Whether Animation nodes are crash-safe — TEST4b result unknown at research time

---

## Metadata

**Confidence breakdown:**
- Codebase state: HIGH — direct source inspection, not assumptions
- SAFE-02 (orphan deletion): HIGH — grep confirmed zero call-sites
- SAFE-03 (duplicate count): HIGH — all instances located and counted
- FIX-07 (constant fix): HIGH — single confirmed location
- SAFE-01 (crash root cause): MEDIUM — workaround is in place; final confirmation requires device test

**Research date:** 2026-03-13
**Valid until:** 2026-04-12 (stable codebase — 30 days)
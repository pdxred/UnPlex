# Phase 11: Crash Safety and Foundation - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish a crash-safe, clean codebase baseline before any screen changes. Confirm BusySpinner SIGSEGV root cause, delete verified orphaned files, extract shared utilities, and fix the progress bar constant. No new features — stability and cleanup only.

</domain>

<decisions>
## Implementation Decisions

### Loading state pattern
- Centered spinner, full screen center (overlaying sidebar and content area)
- Only show spinner if content takes longer than ~300ms to arrive (delay threshold — avoid flash on fast loads)
- Block user input while loading — no navigation allowed until load completes or fails

### BusySpinner investigation
- Full root cause investigation — find the exact SIGSEGV trigger condition
- **Critical:** Validate all assumptions against the current codebase before making changes — the crash may already be fixed by prior work
- If already fixed, reassess whether any additional changes are needed
- Other known instabilities (search, collections) are Phase 13 scope — don't touch here

### Utility extraction
- Validate that duplicates actually exist in current code before extracting anything
- If obvious duplicates are found during investigation beyond GetRatingKeyStr(), OK to consolidate them
- Orphaned files (normalizers.brs, capabilities.brs) must be verified unused via grep before deletion

### Claude's Discretion
- Whether to document the BusySpinner root cause (depends on what's found during investigation)
- Where shared utilities live — keep in utils.brs or split by concern based on file size
- Exact spinner visual style and animation
- Compression algorithm for delay threshold timing

</decisions>

<specifics>
## Specific Ideas

- "Reconcile your assumptions against the codebase and reassess any issues before making code changes" — this applies to ALL tasks in this phase, not just BusySpinner
- Current code is "pretty solid outside of the search function and collections browsing" — those are Phase 13

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-crash-safety-and-foundation*
*Context gathered: 2026-03-13*

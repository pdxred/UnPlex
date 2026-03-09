# Phase 1: Infrastructure - Context

**Gathered:** 2026-03-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Set up BrighterScript 0.70.x compiler, cache GetConstants() in m.global, fix API task collision pattern, and ensure F5 deploy from VSCode works end-to-end. No application features — pure build toolchain and runtime foundation.

</domain>

<decisions>
## Implementation Decisions

### BrighterScript Setup
- Install BrighterScript 0.70.x and roku-deploy as npm dev dependencies
- Create bsconfig.json with source paths pointing at SimPlex/ directory
- Existing .brs files must compile unchanged (BrighterScript is a superset)
- Add diagnosticFilters as needed to suppress false positives on existing code
- Do NOT rename .brs files to .bs — keep existing extensions for Phase 1
- Do NOT adopt BrighterScript v1.0.0-alpha (unstable, breaking changes)

### Constants Caching
- GetConstants() result cached in m.global at startup (MainScene.init)
- All components access constants via m.global instead of calling GetConstants()
- Eliminates per-call associative array allocation and GC pressure
- Pattern: m.global.addFields({ constants: GetConstants() }) in MainScene.init()

### API Task Collision Fix
- Current pattern reuses a single PlexApiTask instance — concurrent requests clobber each other
- Fix: create a new Task node instance per concurrent request
- Screens/widgets create task, observe response, then release reference
- Alternative: pool of pre-created task instances — Claude's discretion on approach

### F5 Deploy
- VSCode launch.json configured with roku-deploy for one-key sideload
- package.json with "deploy" script as backup
- Target: developer presses F5, app appears on Roku device

### Claude's Discretion
- Exact bsconfig.json diagnosticFilters needed for existing code
- Whether to use task instance pooling or create-per-request pattern
- roku-deploy configuration details (host, password placeholders)
- Any additional npm scripts (lint, clean, etc.)

</decisions>

<specifics>
## Specific Ideas

- Research confirmed BrighterScript 0.70.3 is current stable release
- roku-deploy 3.16.1 for automated zip-and-sideload
- Maestro MVVM is deprecated — do NOT adopt (this was in the original brief but research invalidated it)
- Existing codebase uses roRegistrySection("SimPlex") — no rename needed

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-infrastructure*
*Context gathered: 2026-03-08*

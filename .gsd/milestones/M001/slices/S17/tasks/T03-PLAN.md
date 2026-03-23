---
estimated_steps: 4
estimated_files: 2
skills_used: []
---

# T03: Write CONTRIBUTING.md and docs/ARCHITECTURE.md

**Slice:** S17 — Documentation and GitHub
**Milestone:** M001

## Description

Write the developer-facing documentation: a contributing guide and an architecture deep-dive. These documents enable future contributors (or the project owner returning after time away) to understand the codebase structure, development workflow, and architectural decisions.

This task directly delivers requirement DOCS-02 (developer/architecture documentation).

**Important context for the executor:** SimPlex is a Roku BrightScript app (NOT JavaScript/web). It uses Roku SceneGraph XML for UI layout and BrightScript (.brs) for logic. All HTTP requests must run in Task nodes (background threads). The app targets FHD 1920×1080.

### Content sources (read these from disk — they exist but are untracked after T01):
- `.planning/codebase/ARCHITECTURE.md` (242 lines) — full component architecture
- `.planning/codebase/STRUCTURE.md` (254 lines) — directory layout
- `.planning/codebase/CONVENTIONS.md` (277 lines) — coding standards
- `.planning/codebase/INTEGRATIONS.md` (183 lines) — Plex API integration details
- `.planning/codebase/STACK.md` (120 lines) — technology stack
- `.planning/codebase/TESTING.md` (358 lines) — build/test patterns
- `.planning/codebase/CONCERNS.md` (414 lines) — known limitations
- `CLAUDE.md` (125 lines) — build commands, architecture summary, key constants, critical rules

### Key codebase stats for the docs:
- ~8,978 lines of BrightScript, ~1,348 lines of XML
- 65 source files (33 .brs + 32 .xml) plus manifest, font, and images
- 10 screens, 15 widgets, 6 task nodes, 4 utility modules
- Build: BrighterScript compiler via `npm run build/deploy/lint`
- Deploy: side-load via `bsc --deploy` (configured in `bsconfig.json` with Roku IP/password)

### Architecture key points:
- **Component pattern:** Each SceneGraph component = .xml (layout + interface fields) + .brs (logic)
- **Task threading:** ALL HTTP via Task nodes (`PlexAuthTask`, `PlexApiTask`, `PlexSearchTask`, `PlexSessionTask`, `ImageCacheTask`, `ServerConnectionTask`). Using `roUrlTransfer` on render thread causes rendezvous crashes.
- **Observer pattern:** Task→UI via `observeField("state", "callback")` + `task.control = "run"`
- **Screen stack:** MainScene maintains array of screen nodes; back button pops; focus position preserved
- **Data flow:** Auth (PIN-based OAuth via plex.tv) → Server discovery → Library browsing → Playback
- **Key patterns:** ContentNode trees for lists/grids, `roRegistrySection` for persistence (always `.Flush()`), X-Plex-* headers on every API call, paginated library fetches, image transcoding for posters

## Steps

1. **Write CONTRIBUTING.md** with these sections:
   - `## Development Setup` — Prerequisites: Node.js (16+), a Roku device in developer mode. Clone repo, `npm install`, configure `bsconfig.json` with Roku IP and developer password.
   - `## Build & Deploy` — `npm run build` (compile BrighterScript → BrightScript), `npm run deploy` (compile + sideload to Roku), `npm run lint` (type-check without emit). Explain that `bsconfig.json` controls output dir and deploy target.
   - `## Code Conventions` — Component pattern (.xml + .brs pairs), naming conventions, critical rules (HTTP in Task nodes only, HTTPS certs required, X-Plex-* headers, `.Flush()` after registry writes, never use BusySpinner).
   - `## Project Structure` — Directory tree with purpose of each folder (`source/` = entry + utilities, `components/screens/` = full-screen views, `components/widgets/` = reusable UI, `components/tasks/` = background HTTP, `images/` = assets, `fonts/` = Inter Bold).
   - `## Known Limitations` — Brief list of known issues (accent color inconsistency, HomeScreen hub rows don't support auto-play, no multi-server support).

2. **Create `docs/` directory and write `docs/ARCHITECTURE.md`** with these sections:
   - `## System Overview` — Layer diagram (ASCII): Roku SceneGraph → Screens → Widgets → Task Nodes → Plex API
   - `## Screen Stack` — How MainScene manages screen array, push/pop, focus preservation, `onKeyEvent` routing
   - `## Task Threading Model` — Why all HTTP must be in Task nodes, how each task works, observer pattern for results
   - `## Data Flow` — Auth flow (PIN → poll → token → server discovery), library browsing (sections → items → metadata), playback (direct play vs. transcode, progress reporting, scrobble)
   - `## Key Patterns` — ContentNode trees, registry persistence, LoadingSpinner pattern, playbackResult signaling, watchStateUpdate propagation, PosterGrid dynamic resize
   - `## Component Inventory` — Table of all screens (10), widgets (15), tasks (6), utilities (4) with brief descriptions

3. **Security check** — Run `rg -i "authtoken|X-Plex-Token" CONTRIBUTING.md docs/ARCHITECTURE.md` to confirm zero credential leakage. API endpoint patterns (e.g. `/library/sections`) are fine; actual tokens or server URIs are not.

4. **Commit documentation** — Stage README.md, LICENSE, CONTRIBUTING.md, docs/ARCHITECTURE.md. Commit with message `docs: add README, LICENSE, contributing guide, and architecture docs`.

## Must-Haves

- [ ] CONTRIBUTING.md exists with sections: Development Setup, Build & Deploy, Code Conventions, Project Structure, Known Limitations
- [ ] docs/ARCHITECTURE.md exists with sections: System Overview, Screen Stack, Task Threading Model, Data Flow, Key Patterns, Component Inventory
- [ ] Both docs reference BrightScript/SceneGraph (not JavaScript/web frameworks)
- [ ] Critical rules documented: HTTP in Task nodes only, HTTPS certs, X-Plex-* headers, no BusySpinner
- [ ] Zero auth tokens or server URIs in any documentation file

## Verification

- `test -f CONTRIBUTING.md` succeeds
- `grep -c "^## " CONTRIBUTING.md` returns `>= 4` (at least 4 H2 sections)
- `grep -q "Task" CONTRIBUTING.md` succeeds (Task node rule documented)
- `test -f docs/ARCHITECTURE.md` succeeds
- `grep -c "^## " docs/ARCHITECTURE.md` returns `>= 4` (at least 4 H2 sections)
- `grep -q "Task\|threading\|Thread" docs/ARCHITECTURE.md` succeeds (threading model documented)
- `rg -i "authtoken|X-Plex-Token" CONTRIBUTING.md docs/ARCHITECTURE.md | wc -l` returns `0`

## Inputs

- `README.md` — created in T02, provides context for cross-references
- `LICENSE` — created in T02, referenced from CONTRIBUTING.md
- `.planning/codebase/ARCHITECTURE.md` — on disk (untracked), primary source for architecture content
- `.planning/codebase/STRUCTURE.md` — on disk (untracked), source for project structure
- `.planning/codebase/CONVENTIONS.md` — on disk (untracked), source for code conventions
- `.planning/codebase/INTEGRATIONS.md` — on disk (untracked), source for API integration details
- `.planning/codebase/CONCERNS.md` — on disk (untracked), source for known limitations
- `.planning/codebase/TESTING.md` — on disk (untracked), source for build/test patterns
- `CLAUDE.md` — on disk (untracked), source for build commands and critical rules

## Expected Output

- `CONTRIBUTING.md` — developer contributing guide with setup, build, conventions, structure
- `docs/ARCHITECTURE.md` — architecture deep-dive with threading model, screen stack, data flow, patterns

# S17: Documentation and GitHub — Research

**Slice:** S17 — Documentation and GitHub  
**Depth:** Light research  
**Confidence:** HIGH  
**Researched:** 2026-03-23

## Summary

S17 is pure documentation and repository hygiene — no code changes, no new components. The work is: write a README, write developer docs, fix .gitignore, and ensure the repository is publishable. All information needed already exists in the codebase and .planning docs. The only risk is accidentally publishing sensitive data (HAR files, auth tokens in planning docs, internal GSD/planning infrastructure).

## Requirements Owned

| Requirement | Description | Risk |
|-------------|-------------|------|
| **DOCS-01** | Full README with user guide (install, configure, use) | Low — all info exists |
| **DOCS-02** | Developer/architecture documentation (components, patterns, API) | Low — .planning/codebase/ has templates |
| **DOCS-03** | .gitignore updated (exclude HAR files, credentials, build artifacts) | Low — known gaps |
| **DOCS-04** | Repository published to GitHub | Medium — security audit needed first |

## Recommendation

Three tasks in sequence:

1. **T01: .gitignore cleanup and security audit** — Fix .gitignore first (before any commit). Add `*.har`, `*.bak`, `.planning/`, `.gsd/`, `scripts/` exclusions. Audit tracked files for sensitive data. This gates everything else.

2. **T02: README.md** — Write the public-facing README. Structure: project description, screenshot placeholder, features list, installation/sideloading guide, usage overview, tech stack, license, attribution (Inter font SIL OFL).

3. **T03: Developer docs (CONTRIBUTING.md + docs/ARCHITECTURE.md)** — Write developer-facing documentation. CONTRIBUTING.md covers dev environment setup, build/deploy commands, code conventions, project structure. docs/ARCHITECTURE.md covers the component architecture, task threading model, screen stack, data flow. Most content can be distilled from .planning/codebase/ files.

## Implementation Landscape

### What exists today

**Repository state:**
- GitHub remote: `https://github.com/pdxred/SimPlex.git` (origin)
- Branches: `master` (remote), `milestone/M001` (current worktree)
- 190 `.gsd/` and `.planning/` files are tracked in git — these are internal development infrastructure
- No README.md, no LICENSE, no CONTRIBUTING.md, no docs/ directory
- `CLAUDE.md` is tracked — this is an AI assistant config file, not user documentation

**Files that should NOT be in the public repo:**
- `.planning/` — internal planning docs (PROJECT.md, CONCERNS.md, ARCHITECTURE.md, etc.)
- `.gsd/` — GSD milestone management infrastructure (190 files)
- `.claude/` — Claude Code agent configuration (commands, agents, hooks, references)
- `.bg-shell/` — background shell session management
- `scripts/generate_branding.py` — asset generation script (useful for dev, could stay or go)
- `CLAUDE.md` — AI assistant guidance (not user-facing)
- `.vscode/launch.json` — IDE-specific config (currently tracked, should be in .gitignore)

**Files that MUST be excluded from .gitignore (currently missing):**
- `*.har` — HTTP archive files contain live Plex auth tokens (flagged in M001 research as critical)
- `*.bak` — backup files from debugging sessions
- `.planning/` — internal planning documentation
- `.gsd/` — GSD project management
- `.claude/` — Claude Code configuration
- `.bg-shell/` — shell session state

**.gitignore current state** — has standard patterns (node_modules, out/, .env, OS files, IDE) but is missing HAR, planning, GSD, Claude, and backup file patterns.

**Existing documentation sources** (content to distill into public docs):
- `.planning/PROJECT.md` — project overview, features, constraints, decisions
- `.planning/codebase/ARCHITECTURE.md` — full component architecture
- `.planning/codebase/STRUCTURE.md` — directory layout
- `.planning/codebase/CONVENTIONS.md` — coding standards
- `.planning/codebase/INTEGRATIONS.md` — Plex API integration details
- `.planning/codebase/STACK.md` — technology stack
- `.planning/codebase/TESTING.md` — build/test patterns
- `.planning/codebase/CONCERNS.md` — known limitations and issues
- `CLAUDE.md` — build/deploy commands, API reference, architecture summary
- `SimPlex/images/README.txt` — image asset documentation
- `SimPlex/manifest` — app metadata (version 1.0.1)

**Codebase stats:**
- ~8,978 lines of BrightScript across all .brs files
- ~1,348 lines of XML across all .xml files (estimated from total 10,326 - brs)
- 65 source files (33 .brs + 32 .xml) plus manifest, font, and images
- 10 screens, 15 widgets, 6 task nodes, 4 utility modules

**Security audit findings:**
- `utils.brs` stores/retrieves authToken and serverUri from registry — this is expected Roku behavior, documented in CONCERNS.md
- `logger.brs` only logs `[timestamp] [level] message` format — no token leakage found in LogEvent/LogError calls
- No `print` statements output token values
- No HAR files currently in working tree (were cleaned in earlier slice)
- `constants.brs` has `PLEX_TV_URL` and product metadata — not sensitive

**License status:**
- No LICENSE file exists
- Inter-Bold.ttf is SIL Open Font License (attribution needed)
- Project is personal use, sideloaded — license choice is up to the owner
- Recommendation: MIT License (simple, permissive, standard for personal projects) or keep unlicensed

### Natural task boundaries

1. **.gitignore + security** — must be done first, gates DOCS-04 (GitHub publish). Pure file edits, zero code.
2. **README.md** — standalone document, references features/install/usage. No dependency on other docs.
3. **CONTRIBUTING.md + docs/ARCHITECTURE.md** — developer-facing, can reference README. Natural to write together since they share audience.

### Patterns to follow

**README structure** (based on Jellyfin Roku, standard GitHub conventions):
```
# SimPlex
Brief description + screenshot

## Features
Bullet list of capabilities

## Installation
Step-by-step sideload guide

## Usage
Remote controls, navigation, key workflows

## Building from Source
Prerequisites, build, deploy

## Architecture
Brief overview (link to docs/ARCHITECTURE.md for detail)

## License
MIT + Inter font SIL OFL attribution

## Acknowledgments
Plex, Inter font, Roku developer community
```

**CONTRIBUTING.md structure:**
```
## Development Setup
Prerequisites (Node.js, BrighterScript, Roku in dev mode)
Clone, npm install, configure .vscode/launch.json

## Build & Deploy
npm run build / deploy / lint

## Code Conventions
Naming, patterns, dos/don'ts

## Project Structure
Directory layout with purpose of each folder

## Known Limitations
Link to CONCERNS items that affect contributors
```

**docs/ARCHITECTURE.md structure:**
```
## System Overview
Diagram (ASCII) of layers

## Screen Stack
How navigation works

## Task Threading
Why all HTTP is in Task nodes

## Data Flow
Auth → server discovery → library browsing → playback

## Key Patterns
Observer pattern, ContentNode trees, registry persistence
```

### What the planner needs to know

- **Task ordering matters:** .gitignore MUST be updated before any new files are committed. If README.md is committed while `.planning/` is still tracked, the git history permanently contains internal planning docs.
- **The .gitignore task should also add patterns but NOT remove tracked files** — removing `.planning/` and `.gsd/` from tracking requires `git rm --cached -r .planning/ .gsd/ .claude/ .bg-shell/` which is a separate step. The planner should decide whether to untrack these files in this slice or defer to a separate cleanup.
- **CLAUDE.md decision:** Currently tracked. It's useful for AI-assisted development but confusing in a public repo. Could be kept (it's becoming a convention) or moved to `.claude/` where it would be gitignored.
- **scripts/ directory:** `generate_branding.py` is the only file. Useful for reproducibility but requires Pillow. Could stay in repo (documented in CONTRIBUTING.md) or be gitignored.
- **manifest version:** Currently shows `1.0.1` — the README should document what version the docs describe.
- **No screenshots available:** The app runs on a Roku device. Screenshots require HDMI capture or Roku developer tools. README can use placeholder text or describe the UI textually. Do not fabricate screenshots.
- **Inter font attribution:** SIL OFL requires attribution if redistributing. Since the TTF is in the repo, LICENSE or README must include attribution.

### Verification approach

| Check | Method |
|-------|--------|
| DOCS-01: README exists and has install guide | File exists, contains "## Installation" or similar |
| DOCS-02: Dev docs exist | `CONTRIBUTING.md` and `docs/ARCHITECTURE.md` exist with content |
| DOCS-03: .gitignore has HAR/planning exclusions | `grep "\.har" .gitignore` succeeds; `grep "\.planning" .gitignore` succeeds |
| DOCS-04: Repo publishable | No sensitive files in tracked tree; `git ls-files` shows no .har, no tokens in tracked content |
| Security: No token leakage | `rg -i "authtoken|X-Plex-Token" README.md CONTRIBUTING.md docs/` returns zero matches |

---
*Research completed: 2026-03-23*
*Depth: Light — documentation slice with known patterns, no technology uncertainty*

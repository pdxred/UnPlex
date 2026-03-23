---
estimated_steps: 3
estimated_files: 2
skills_used: []
---

# T02: Write README.md and LICENSE

**Slice:** S17 — Documentation and GitHub
**Milestone:** M001

## Description

Write the primary user-facing documentation: a comprehensive README.md and MIT LICENSE file. The README serves as the entry point for anyone discovering SimPlex on GitHub — it explains what the project is, how to install/sideload it, how to use it, and how to build from source. The LICENSE file establishes MIT licensing with attribution for the bundled Inter Bold font (SIL Open Font License).

This task directly delivers requirement DOCS-01 (full README with user guide).

**Important context for the executor:** SimPlex is a Roku BrightScript app (NOT JavaScript/web). It runs on Roku devices and is side-loaded in developer mode. The app is a custom Plex Media Server client. All content information below comes from the project's internal docs and manifest.

### Content sources (read these from disk to distill content — they are untracked but still exist on disk):
- `CLAUDE.md` (on disk, untracked) — contains build/deploy commands, API reference, architecture summary, key constants
- `.planning/PROJECT.md` (on disk, untracked) — project overview, features, constraints
- `.planning/codebase/STACK.md` (on disk, untracked) — technology stack details
- `.planning/codebase/INTEGRATIONS.md` (on disk, untracked) — Plex API integration details
- `SimPlex/manifest` (tracked) — app version info (v1.0.1, title "SimPlex", subtitle "Custom Plex Client")

### Key facts for README content:
- **App name:** SimPlex
- **What it is:** Side-loadable Roku channel — custom Plex Media Server client replacing the official Plex Roku app
- **UI style:** Clean, fast, grid-based UI inspired by "Plex Classic" Roku client
- **Tech:** BrightScript + Roku SceneGraph (FHD 1920×1080)
- **Version:** 1.0.1
- **Features:** Library browsing (movies/TV/music), search, playback (direct + transcode), resume/progress, watched badges, audio/subtitle selection, skip intro/credits, auto-play next episode, collections, playlists, managed user switching, sidebar navigation, hub rows (Continue Watching, Recently Added, On Deck), filter/sort
- **Install:** Enable Roku dev mode (Home 3×, Up 2×, Right Left Right Left Right), zip the project (`cd SimPlex && zip -r ../SimPlex.zip manifest source components images fonts`), upload via browser to `http://{roku-ip}:8060`
- **Build prerequisites:** Node.js, `npm install` (installs BrighterScript + roku-deploy), npm scripts: `build`, `deploy`, `lint`
- **No screenshots available** — do NOT fabricate or use placeholder image URLs
- **Font attribution:** Inter Bold font (SIL Open Font License) by Rasmus Andersson
- **License:** MIT

## Steps

1. **Write README.md** with the following sections:
   - `# SimPlex` — brief description (custom Plex client for Roku, side-loaded)
   - `## Features` — bullet list of all capabilities (see key facts above)
   - `## Installation` — step-by-step sideloading guide for Roku developer mode
   - `## Usage` — remote control keys, sidebar navigation, key workflows (browsing, playback, search)
   - `## Building from Source` — prerequisites, clone, npm install, npm scripts
   - `## Architecture` — brief overview (SceneGraph components, Task nodes for HTTP, screen stack) with link to `docs/ARCHITECTURE.md`
   - `## License` — MIT license note + Inter font SIL OFL attribution
   - `## Acknowledgments` — Plex, Inter font/Rasmus Andersson, Roku developer platform

2. **Write LICENSE** — MIT License (year 2026, copyright holder from git config or "SimPlex Contributors"). Append a section noting Inter-Bold.ttf is included under SIL Open Font License 1.1 with link to the OFL.

3. **Security check** — Run `rg -i "authtoken|X-Plex-Token" README.md LICENSE` to confirm zero credential leakage. Verify README does not contain any actual server URIs or tokens.

## Must-Haves

- [ ] README.md exists with sections: Features, Installation, Usage, Building from Source, Architecture, License, Acknowledgments
- [ ] Installation section includes complete sideloading steps (dev mode activation, zip command, upload URL pattern)
- [ ] LICENSE file exists with MIT terms
- [ ] Inter font SIL OFL attribution present in LICENSE or README
- [ ] Zero auth tokens or server URIs in any documentation file

## Verification

- `test -f README.md` succeeds
- `grep -c "^## " README.md` returns `>= 5` (at least 5 H2 sections)
- `grep -q "Installation\|Sideload\|sideload" README.md` succeeds (install guide present)
- `grep -q "developer mode\|dev mode\|Developer Mode" README.md` succeeds (Roku dev mode documented)
- `test -f LICENSE` succeeds
- `grep -q "MIT" LICENSE` succeeds
- `grep -qi "Inter\|SIL Open Font" LICENSE README.md` succeeds (font attribution present)
- `rg -i "authtoken|X-Plex-Token" README.md LICENSE | wc -l` returns `0`

## Inputs

- `.gitignore` — updated in T01, confirms internal files are excluded
- `CLAUDE.md` — on disk (untracked after T01), source for build commands and API reference
- `.planning/PROJECT.md` — on disk (untracked), source for project overview and features
- `.planning/codebase/STACK.md` — on disk (untracked), source for tech stack details
- `.planning/codebase/INTEGRATIONS.md` — on disk (untracked), source for Plex API details
- `SimPlex/manifest` — app version and metadata

## Expected Output

- `README.md` — comprehensive user-facing documentation with install guide, features, usage
- `LICENSE` — MIT license with SIL OFL attribution for Inter font

---
id: S17
milestone: M001
status: ready
---

# S17: Documentation and GitHub — Context

## Goal

Write README.md, CONTRIBUTING.md, docs/ARCHITECTURE.md, docs/USER_GUIDE.md, and MIT LICENSE; clean up .gitignore to exclude all internal artifacts; audit LogEvent calls for credential leakage; and leave the repo publish-ready for eventual public release.

## Why this Slice

This is the final slice of M001. All code (S13–S15) and branding (S16, which renames the app to "UnPlex") are complete. Documentation describes what was actually built. The repo must be clean, professional, and free of internal planning artifacts before it can be shared — even as a private repo now, the goal is to make it immediately publishable when the app is production-tested.

## Scope

### In Scope

- **README.md** — project overview, what it is and what it is NOT (Plex required, sideload only, single server), feature list reflecting v1.1 state, prerequisites (Roku in developer mode, Plex Media Server, BrighterScript for dev), installation with two paths (download release .zip and sideload, or clone + build from source), screenshots or placeholders for screenshots, license badge.
- **docs/ARCHITECTURE.md** — component map (screen stack, widget layer, task layer, persistence layer), task node pattern, screen stack push/pop model, data flow for key user journeys (playback, search, watch state propagation). Can draw from existing `.planning/codebase/ARCHITECTURE.md` but rewritten for a public audience.
- **docs/USER_GUIDE.md** — remote control button map, navigation flows (home → library → detail → play, home → show → episodes → play), settings screen overview, known limitations.
- **CONTRIBUTING.md** — dev environment (VSCode + BrighterScript extension + Roku VSCode extension), F5 deploy workflow, project directory structure, code conventions (commit format, BrightScript patterns, no roUrlTransfer on render thread, no BusySpinner), known limitations and out-of-scope features.
- **LICENSE** — MIT License file with current year and copyright holder.
- **.gitignore cleanup** — add entries for: `.planning/`, `.gsd/`, `.claude/`, `CLAUDE.md`, `simplex-project-brief.md`, `*.zip.old`, `.bg-shell/`. Ensure `*.har`, `*.zip`, `out/`, `node_modules/`, `.env` are already covered (they are).
- **LogEvent/LogError security audit** — review all 70 LogEvent/LogError calls across the codebase. Redact or remove any that log: auth tokens, full server URIs with query parameters containing tokens, PIN codes, or X-Plex-Token values. Keep debug-safe logging (screen names, state transitions, error messages without credentials). Specifically flag: `ServerListScreen.brs` logging `"Server URI saved: " + serverUri`, `PINScreen.brs` logging PIN codes.
- **Remove loose files** — delete or gitignore `SimPlex.zip.old`, `simplex-project-brief.md` (internal planning brief, not for public repo).
- **All documentation uses "UnPlex"** — the app name was changed from "SimPlex" to "UnPlex" in S16. All docs must use the new name consistently. The project directory remains `SimPlex/` (internal build artifact per S16 context).
- **Manifest version confirmation** — verify manifest shows version 1.1.0 (set in S16). If not, update here.

### Out of Scope

- **GitHub Actions / CI** — no automated build or test pipeline. Manual sideload workflow only.
- **GitHub Releases with tagged .zip** — nice to have but not in scope for this slice. Can be done manually after publish.
- **Screenshots** — the README should have placeholder sections for screenshots. Actual screenshots require sideloading the final build on the Roku and capturing from the TV. The user will provide these before public publish.
- **Docusaurus / MkDocs / any documentation generator** — plain Markdown only. No build step for docs.
- **Renaming the `SimPlex/` directory** — per S16 context, the build directory stays as `SimPlex/` for now. Docs should explain this (the channel is called "UnPlex" but the source directory is `SimPlex/` for historical reasons).
- **Removing `.planning/` or `.gsd/` from disk** — these are gitignored, not deleted. They remain useful for development.

## Constraints

- **All documentation must use "UnPlex" as the app name.** S16 renames the app. The manifest title, constants, and user-visible strings will say "UnPlex" by the time S17 executes.
- **The `SimPlex/` directory name stays.** Documentation should note this briefly: "The source directory is named `SimPlex/` for historical reasons. The channel is called UnPlex."
- **No auth tokens in any committed file.** The LogEvent audit must confirm zero credential leakage in the codebase. This includes: X-Plex-Token values, full `BuildPosterUrl` results (which embed tokens in query strings), server URIs with auth parameters, and PIN codes.
- **`.planning/`, `.gsd/`, `.claude/`, `CLAUDE.md` must be gitignored**, not deleted. They remain locally useful but must never appear in `git status` as tracked or untracked.
- **README must be accurate to the final v1.1 feature set.** Don't document features that were deferred (music, photos, live TV, multi-server). Do document what was built: library browsing, playback with direct play/transcode, auto-play, search, collections, playlists, managed users, skip intro/credits, audio/subtitle track selection.

## Integration Points

### Consumes

- `SimPlex/manifest` — version number, app title ("UnPlex"), icon/splash file references for install instructions.
- `CLAUDE.md` — architecture constraints and code conventions (source material for CONTRIBUTING.md and docs/ARCHITECTURE.md, but CLAUDE.md itself gets gitignored).
- `.planning/codebase/ARCHITECTURE.md` — existing internal architecture doc (source material for public docs/ARCHITECTURE.md).
- `.planning/PROJECT.md` — feature scope and known limitations (source material for README features list and known limitations).
- `bsconfig.json` — build configuration for developer setup instructions.
- All `SimPlex/components/` and `SimPlex/source/` BRS files — LogEvent audit targets.

### Produces

- `README.md` — project overview, features, install guide, developer setup summary, license.
- `CONTRIBUTING.md` — dev environment, F5 deploy, code conventions, known limitations.
- `docs/ARCHITECTURE.md` — component map, data flow, patterns for contributors.
- `docs/USER_GUIDE.md` — remote control map, navigation flows, settings.
- `LICENSE` — MIT license text.
- Updated `.gitignore` — excludes `.planning/`, `.gsd/`, `.claude/`, `CLAUDE.md`, loose files.
- Audited `SimPlex/` BRS files — any LogEvent calls that logged credentials are redacted or removed.

## Open Questions

- **Screenshot placeholders vs. real screenshots** — README needs visual context but actual screenshots require the final build sideloaded on the Roku. Current thinking: add `<!-- TODO: Add screenshot -->` placeholders with descriptive alt text. The user provides real screenshots before going public.
- **Copyright holder for LICENSE** — MIT License needs a name. Use the git user name or a project name? Current thinking: use the git config `user.name` value, or ask during execution if it's not set.

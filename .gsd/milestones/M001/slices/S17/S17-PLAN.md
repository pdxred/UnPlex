# S17: Documentation and GitHub

**Goal:** Repository has comprehensive public documentation (README, contributing guide, architecture docs) and is clean for GitHub publication — no internal tooling, credentials, or planning files in the tracked tree.
**Demo:** `git ls-files` shows only app source, docs, config, and license — zero `.planning/`, `.gsd/`, `.claude/`, `.bg-shell/` files. README.md, CONTRIBUTING.md, docs/ARCHITECTURE.md, and LICENSE all exist with substantive content.

## Must-Haves

- .gitignore excludes `*.har`, `*.bak`, `.planning/`, `.gsd/`, `.claude/`, `.bg-shell/`, `CLAUDE.md`
- Internal tooling files (317 files across `.planning/`, `.gsd/`, `.claude/`, `.bg-shell/`) untracked via `git rm --cached`
- README.md with project description, features, installation/sideloading guide, usage, build instructions, license
- CONTRIBUTING.md with dev setup, build/deploy commands, code conventions, project structure
- docs/ARCHITECTURE.md with component architecture, task threading, screen stack, data flow
- LICENSE file (MIT) with Inter font SIL OFL attribution
- Zero credential/token leakage in any tracked documentation file

## Proof Level

- This slice proves: final-assembly (documentation completes the repository for publication)
- Real runtime required: no
- Human/UAT required: yes — owner must decide to push to GitHub and verify public repo appearance

## Verification

- `grep -q "\.har" .gitignore` — HAR file exclusion present
- `grep -q "\.planning" .gitignore` — planning exclusion present
- `grep -q "\.gsd" .gitignore` — GSD exclusion present
- `git ls-files | grep -c -E '^\.(planning|claude|bg-shell|gsd)/'` returns `0` — all internal files untracked
- `git ls-files | grep -c -E '\.har$'` returns `0` — no HAR files tracked
- `test -f README.md && grep -c "^## " README.md` returns `>= 5` — README exists with 5+ sections
- `test -f CONTRIBUTING.md && grep -c "^## " CONTRIBUTING.md` returns `>= 4` — contributing guide exists
- `test -f docs/ARCHITECTURE.md && grep -c "^## " docs/ARCHITECTURE.md` returns `>= 4` — architecture doc exists
- `test -f LICENSE` — license file exists
- Security audit: `rg -i "authtoken|X-Plex-Token|\.har" README.md CONTRIBUTING.md docs/ LICENSE 2>/dev/null | grep -v -E "^(README|CONTRIBUTING|docs/)" | wc -l` returns `0` — no token values leaked (grep hits are section references, not actual tokens)
- Failure-path check: `git diff --cached --name-only | grep -c -E '\.(har|bak)$'` returns `0` after staging — no sensitive files accidentally staged

## Observability / Diagnostics

- Runtime signals: none (documentation-only slice, no runtime components)
- Inspection surfaces: `git ls-files` to audit tracked files; `rg -i "authtoken|X-Plex-Token" <file>` to scan for credential leakage in any doc
- Failure visibility: if internal files remain tracked after T01, `git ls-files | grep -E '^\.(planning|gsd|claude|bg-shell)/' | wc -l` will return non-zero — immediate detection
- Redaction constraints: no auth tokens, server URIs, or HAR file contents may appear in any documentation file; `.planning/` content is internal and must not be copy-pasted verbatim into public docs

## Integration Closure

- Upstream surfaces consumed: `.planning/codebase/*.md` (architecture, structure, conventions, integrations, stack — content distilled into public docs), `CLAUDE.md` (build commands, API reference), `SimPlex/manifest` (version info)
- New wiring introduced in this slice: none — pure documentation, no code changes
- What remains before the milestone is truly usable end-to-end: owner runs `git push` to publish; UAT visual verification of Roku sideload (documented in S16 as pending)

## Tasks

- [ ] **T01: Update .gitignore and untrack internal tooling files** `est:15m`
  - Why: Gates all other work — .gitignore must exclude sensitive/internal patterns before new docs are committed. DOCS-03 and DOCS-04 depend on this. Currently 317 internal files are tracked across `.planning/`, `.gsd/`, `.claude/`, `.bg-shell/`.
  - Files: `.gitignore`, `CLAUDE.md` (untrack only), `.vscode/launch.json` (untrack only)
  - Do: Add exclusion patterns for `*.har`, `*.bak`, `.planning/`, `.gsd/`, `.claude/`, `.bg-shell/`, `CLAUDE.md`, `scripts/`. Run `git rm --cached -r` to untrack internal files without deleting them from disk. Verify zero internal files remain in `git ls-files`.
  - Verify: `git ls-files | grep -c -E '^\.(planning|claude|bg-shell|gsd)/'` returns `0`; `grep -q "\.har" .gitignore` succeeds
  - Done when: .gitignore has all required exclusions and `git ls-files` shows only app source + config files

- [ ] **T02: Write README.md and LICENSE** `est:25m`
  - Why: DOCS-01 — the primary user-facing documentation. README covers install, configure, use. LICENSE provides MIT terms with Inter font SIL OFL attribution.
  - Files: `README.md`, `LICENSE`
  - Do: Write README with sections: project description, features list, installation/sideloading guide (enable dev mode, zip, upload), usage (remote controls, navigation, key workflows), building from source (prerequisites, npm commands), architecture overview (brief, linking to docs/ARCHITECTURE.md), license, acknowledgments. Write MIT LICENSE file with SIL OFL attribution for Inter font. Source content from CLAUDE.md and `.planning/` docs (which are still on disk, just untracked). Do NOT include screenshots (no capture available) or actual auth tokens.
  - Verify: `test -f README.md && grep -c "^## " README.md` returns `>= 5`; `test -f LICENSE`; `rg -i "authtoken|X-Plex-Token" README.md LICENSE | wc -l` returns `0`
  - Done when: README.md has installation guide, features, usage, build instructions; LICENSE exists with MIT + SIL OFL

- [ ] **T03: Write CONTRIBUTING.md and docs/ARCHITECTURE.md** `est:25m`
  - Why: DOCS-02 — developer/architecture documentation. Enables future contributors to understand the codebase, build, and deploy.
  - Files: `CONTRIBUTING.md`, `docs/ARCHITECTURE.md`
  - Do: Write CONTRIBUTING.md with sections: dev environment setup (Node.js, BrighterScript, Roku dev mode), build/deploy commands (`npm run build/deploy/lint`), code conventions (naming, patterns, BrightScript rules), project structure (directory layout with purposes), known limitations. Write docs/ARCHITECTURE.md with sections: system overview, screen stack navigation, task threading model (why all HTTP in Task nodes), data flow (auth → discovery → browsing → playback), key patterns (observer, ContentNode trees, registry persistence), component inventory. Distill from `.planning/codebase/` files on disk. Do NOT copy-paste internal planning docs verbatim.
  - Verify: `test -f CONTRIBUTING.md && grep -c "^## " CONTRIBUTING.md` returns `>= 4`; `test -f docs/ARCHITECTURE.md && grep -c "^## " docs/ARCHITECTURE.md` returns `>= 4`
  - Done when: CONTRIBUTING.md and docs/ARCHITECTURE.md exist with substantive content covering dev setup, architecture, and patterns

## Files Likely Touched

- `.gitignore`
- `README.md`
- `LICENSE`
- `CONTRIBUTING.md`
- `docs/ARCHITECTURE.md`

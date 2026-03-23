---
estimated_steps: 4
estimated_files: 3
skills_used:
  - review
---

# T01: Update .gitignore and untrack internal tooling files

**Slice:** S17 — Documentation and GitHub
**Milestone:** M001

## Description

The repository currently tracks 317 internal development files across `.planning/`, `.gsd/`, `.claude/`, and `.bg-shell/` directories, plus `CLAUDE.md` (AI assistant config) and `.vscode/launch.json` (IDE-specific). These must be excluded from the public repository before any documentation is committed. This task adds comprehensive .gitignore patterns and uses `git rm --cached` to untrack internal files without deleting them from disk.

This task directly delivers requirements DOCS-03 (.gitignore updated) and gates DOCS-04 (repository publishable to GitHub).

## Steps

1. **Add exclusion patterns to `.gitignore`** — Append the following patterns to the existing `.gitignore`:
   - `*.har` — HTTP archive files (contain live Plex auth tokens)
   - `*.bak` — backup files from debugging sessions
   - `.planning/` — internal planning documentation
   - `.gsd/` — GSD project management infrastructure
   - `.claude/` — Claude Code agent configuration
   - `.bg-shell/` — background shell session state
   - `CLAUDE.md` — AI assistant guidance file
   - `scripts/` — asset generation scripts (require Pillow, not needed by users)
   - `.vscode/` — remove the existing `!.vscode/launch.json` exception so ALL .vscode files are excluded (the current .gitignore already has `.vscode/` but then un-ignores `launch.json`)

2. **Untrack internal files** — Run `git rm --cached -r .planning/ .gsd/ .claude/ .bg-shell/ CLAUDE.md .vscode/launch.json scripts/` to remove from git index without deleting from disk.

3. **Verify clean tracked file list** — Run `git ls-files | grep -E '^\.(planning|claude|bg-shell|gsd)/'` to confirm zero internal files remain tracked. Run `git ls-files` to review the complete tracked file list — it should contain only `SimPlex/` app files, `.gitignore`, `bsconfig.json`, `package.json`, and `package-lock.json`.

4. **Commit the cleanup** — Stage `.gitignore` changes and the untracked file removals. Commit with message `chore: update .gitignore and untrack internal files`.

## Must-Haves

- [ ] `.gitignore` contains patterns for `*.har`, `*.bak`, `.planning/`, `.gsd/`, `.claude/`, `.bg-shell/`, `CLAUDE.md`, `scripts/`
- [ ] `git ls-files | grep -c -E '^\.(planning|claude|bg-shell|gsd)/'` returns `0`
- [ ] `git ls-files` shows no `CLAUDE.md`, no `.vscode/launch.json`, no `scripts/` files
- [ ] No HAR files in tracked tree: `git ls-files | grep -c '\.har$'` returns `0`

## Verification

- `grep -q "\.har" .gitignore` succeeds
- `grep -q "\.planning" .gitignore` succeeds
- `grep -q "\.gsd" .gitignore` succeeds
- `grep -q "CLAUDE.md" .gitignore` succeeds
- `git ls-files | grep -c -E '^\.(planning|claude|bg-shell|gsd)/'` returns `0`
- `git ls-files | grep -c 'CLAUDE.md'` returns `0`
- `git ls-files | grep -c 'launch.json'` returns `0`
- `git ls-files | grep -c 'scripts/'` returns `0`
- Full tracked file list contains only: `.gitignore`, `SimPlex/**`, `bsconfig.json`, `package.json`, `package-lock.json`

## Inputs

- `.gitignore` — current gitignore file, needs additional exclusion patterns
- `.planning/` — 317+ internal files that need to be untracked (directory still on disk)
- `.gsd/` — GSD infrastructure files that need to be untracked
- `.claude/` — Claude Code agent config files that need to be untracked
- `.bg-shell/` — background shell state that needs to be untracked
- `CLAUDE.md` — AI assistant config file that needs to be untracked
- `.vscode/launch.json` — IDE config that needs to be untracked
- `scripts/generate_branding.py` — asset script that needs to be untracked

## Expected Output

- `.gitignore` — updated with comprehensive exclusion patterns for internal/sensitive files

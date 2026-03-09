# Technology Stack

**Project:** SimPlex (Roku Plex Client)
**Researched:** 2026-03-08

## Critical Finding: Maestro Is Deprecated -- Do NOT Adopt

The project brief specifies Maestro MVVM v0.72.0 as a target framework. **This recommendation is now obsolete.** Tantawowa Ltd officially deprecated Maestro in late 2023. No maintenance, no updates, no new features. Critical fixes are available only to existing enterprise clients on a case-by-case basis.

Tantawowa announced a replacement cross-platform TV framework "coming later in 2024" but as of March 2026, no public release has materialized. Adopting a deprecated framework with no successor would be reckless.

**Confidence: HIGH** -- Verified via official GitHub README and release history.

## Recommendation: BrighterScript Without Maestro

Use BrighterScript as a build-time compiler for the existing plain BrightScript codebase. Do NOT adopt Maestro or any MVVM framework. The app is a single-developer, single-purpose Plex client -- MVVM abstraction adds complexity without proportional benefit.

### Why BrighterScript (Without a Framework)

1. **Zero-cost migration**: BrighterScript is a strict superset of BrightScript. Every existing `.brs` file is already valid BrighterScript. You adopt it by adding a build step, not by rewriting code.
2. **Compile-time error checking**: Catches null references, type mismatches, and missing fields before sideloading. Currently these only surface at runtime on the Roku device.
3. **Namespaces and classes**: Reduce global scope pollution as the codebase grows (e.g., normalizers, utilities, constants can be namespaced).
4. **Better IDE experience**: The BrightScript Language VSCode extension uses BrighterScript's language server for intellisense, go-to-definition, and diagnostics -- even on plain `.brs` files.
5. **Ecosystem standard**: Jellyfin-Roku, and many professional Roku shops use BrighterScript as their compiler. It is the de facto standard for serious Roku development.
6. **Gradual adoption**: New files can use `.bs` extension with classes/namespaces. Existing `.brs` files work unchanged. No big-bang migration required.

### Why NOT Maestro

1. **Deprecated** -- No maintenance, no roadmap, no community support.
2. **Heavy abstraction** -- MVVM with IOC containers, node classes, and annotation-driven XML generation is overengineered for a single-developer sideloaded channel.
3. **Build complexity** -- Requires `maestro-cli-roku`, a post-install hook (`maestro-ropm-hook.js`), and the `ropm` package manager. Adds fragile toolchain dependencies.
4. **No replacement** -- Tantawowa's promised successor hasn't shipped. Betting on vaporware is worse than betting on deprecated software.
5. **Existing architecture is sound** -- The current observer + task node + screen stack pattern is the canonical Roku architecture. It does not need an MVVM overlay.

## Recommended Stack

### Core Language & Compiler

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| BrighterScript | ^0.70.3 (stable) | Compiler / transpiler | Superset of BrightScript; compile-time checking, namespaces, classes. Transpiles to standard BrightScript for Roku. Stable branch actively maintained. | HIGH |
| BrightScript | Roku OS native | Runtime language | What actually runs on the device. BrighterScript compiles down to this. | HIGH |
| SceneGraph XML | RSG 1.3 | UI framework | Roku's native component framework. No alternative exists. | HIGH |

**Do NOT use BrighterScript v1.0.0-alpha.x** -- As of v1.0.0-alpha.50 (Jan 2025), the alpha branch has breaking changes and is not production-ready. Stick with the 0.70.x stable line. The project brief's target of ^0.69.x is fine but 0.70.3 is the current stable release; use that.

### Build & Deploy Tools

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| roku-deploy | ^3.16.1 | Package & sideload | Zips the app and deploys to Roku device over HTTP. Integrates with VSCode extension. | HIGH |
| BrightScript Language VSCode Extension | Latest | IDE support | Debugging, intellisense, deploy-on-save. Uses BrighterScript language server internally. | HIGH |

### Testing (Deferred -- Phase 19 Stretch Goal)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Rooibos | Latest via ropm | Unit testing | The only serious BrightScript testing framework. Supports mocking, code coverage. Used in production by Jellyfin, enterprise Roku shops. | MEDIUM |

Rooibos requires BrighterScript as a compiler (it's a BSC plugin). Adopting BrighterScript now means testing is available when needed later.

### Package Management (Optional)

| Technology | Version | Purpose | When to Use | Confidence |
|------------|---------|---------|-------------|------------|
| ropm | Latest | Roku package manager | Only if you need third-party packages (e.g., Rooibos for testing). Not needed for the core app since it has no third-party dependencies. | MEDIUM |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Language | BrighterScript 0.70.x | Plain BrightScript (status quo) | Loses compile-time checking, namespaces, classes. IDE intellisense is worse. Migration cost is near-zero since BS is a superset. |
| Language | BrighterScript 0.70.x | BrighterScript 1.0.0-alpha | Unstable, breaking changes between alphas. Not ready for production. PROJECT.md already lists this as out of scope. |
| Framework | None (plain SceneGraph) | Maestro MVVM 0.72.0 | **Deprecated.** Adds complexity without proportional benefit for a single-developer app. |
| Framework | None (plain SceneGraph) | Tantawowa's successor | Does not exist publicly. Vaporware as of March 2026. |
| Testing | Rooibos (deferred) | Roku's unit-testing-framework | Less capable, less maintained, no mocking support. Rooibos is the community standard. |
| Build | roku-deploy + bsc CLI | Manual zip + HTTP upload | Slower iteration. roku-deploy automates the zip-and-upload cycle. |

## Migration Path: Plain BrightScript to BrighterScript

This is a LOW-RISK migration because BrighterScript is a superset -- no code changes required to start.

### Step 1: Add BrighterScript to the project (1-2 hours)

```bash
npm init -y
npm install brighterscript roku-deploy
```

### Step 2: Create bsconfig.json

```json
{
  "rootDir": "SimPlex",
  "files": [
    "manifest",
    "source/**/*",
    "components/**/*",
    "images/**/*"
  ],
  "stagingDir": "build",
  "createPackage": true,
  "autoImportComponentScript": true,
  "diagnosticFilters": [
    { "src": "**/*.brs", "codes": [1001] }
  ]
}
```

### Step 3: Build and deploy

```bash
npx bsc --project bsconfig.json
```

Or integrate with VSCode launch.json for F5 deploy:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "brightscript",
      "request": "launch",
      "name": "SimPlex",
      "rootDir": "${workspaceFolder}/SimPlex",
      "host": "${env:ROKU_IP}",
      "password": "${env:ROKU_DEV_PASSWORD}",
      "files": [
        "manifest",
        "source/**/*",
        "components/**/*",
        "images/**/*"
      ]
    }
  ]
}
```

### Step 4: Gradual adoption of BrighterScript features (ongoing)

- New files: use `.bs` extension, leverage classes and namespaces
- Existing files: rename to `.bs` only when actively refactoring
- No big-bang rewrite needed

### Migration Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| BrighterScript compiler bug | Low | Medium | Pin to 0.70.3, update cautiously |
| Transpiled output differs from hand-written BS | Very Low | Low | BrighterScript is mature (5+ years). Output is predictable. |
| Build step slows iteration | Low | Low | Compilation is fast (seconds). VSCode extension handles it transparently. |
| npm/Node.js dependency on dev machine | N/A | N/A | Already required if using VSCode BrightScript extension for debugging |

## What NOT to Use

| Technology | Why Not |
|------------|---------|
| Maestro MVVM | Deprecated. No maintenance. Overengineered for this project. |
| BrighterScript 1.0.0-alpha | Unstable. Breaking changes between releases. |
| ropm (for app dependencies) | The app has no third-party runtime dependencies. All code is first-party. Adding ropm for its own sake adds toolchain complexity. |
| React Native for TV | Does not support Roku. Roku requires native BrightScript. |
| Direct Publisher | For MRSS-based linear channels, not custom interactive apps. |
| Roku's built-in unit-testing-framework | Inferior to Rooibos in every way. Use Rooibos when testing is needed. |

## Installation

```bash
# Initialize Node project (for build tooling only -- nothing runs on Roku via Node)
npm init -y

# Core build tools
npm install -D brighterscript@^0.70.3 roku-deploy@^3.16.1

# Later, when adding tests (Phase 19):
# npm install -D rooibos-roku
```

## Project Structure After Migration

```
SimPlex/                    # rootDir for bsconfig.json
  manifest
  source/
    main.brs               # Keep as .brs (entry point, rarely changes)
    constants.brs           # Keep as .brs or migrate to .bs with namespace
    utils.brs               # Keep as .brs or migrate to .bs with namespace
    ...
  components/
    ...                     # All existing files work unchanged
  images/
    ...
build/                      # stagingDir -- transpiled output (gitignore this)
bsconfig.json               # BrighterScript configuration
package.json                # Node.js package for dev dependencies
node_modules/               # gitignore this
```

## Sources

- [BrighterScript GitHub - rokucommunity/brighterscript](https://github.com/rokucommunity/brighterscript) -- Confirmed v0.70.3 stable, v1.0.0-alpha.50 latest alpha (HIGH confidence)
- [BrighterScript Releases](https://github.com/rokucommunity/brighterscript/releases) -- Version history and dates verified
- [Maestro-Roku GitHub - georgejecook/maestro-roku](https://github.com/georgejecook/maestro-roku) -- Confirmed deprecated by Tantawowa Ltd (HIGH confidence)
- [Maestro-Roku Releases](https://github.com/georgejecook/maestro-roku/releases) -- v0.72.0 confirmed as final release, Nov 2023
- [roku-deploy npm](https://www.npmjs.com/package/roku-deploy) -- v3.16.1 confirmed current (HIGH confidence)
- [Rooibos GitHub - rokucommunity/rooibos](https://github.com/rokucommunity/rooibos) -- Community standard testing framework
- [BrighterScript bsconfig.json docs](https://github.com/rokucommunity/BrighterScript/blob/master/docs/bsconfig.md) -- Configuration reference
- [Jellyfin-Roku BrighterScript updates](https://github.com/jellyfin/jellyfin-roku/pull/232) -- Real-world production usage of BrighterScript 0.69.x-0.70.x
- [BrightScript VSCode Extension](https://marketplace.visualstudio.com/items?itemName=RokuCommunity.brightscript) -- IDE tooling
- [RokuCommunity](https://rokucommunity.github.io/) -- Ecosystem hub

---

*Stack research: 2026-03-08*

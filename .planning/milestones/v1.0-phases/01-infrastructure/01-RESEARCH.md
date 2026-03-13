# Phase 1: Infrastructure - Research

**Researched:** 2026-03-08
**Domain:** Roku BrighterScript build toolchain, runtime constants, SceneGraph task concurrency
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Install BrighterScript 0.70.x and roku-deploy as npm dev dependencies
- Create bsconfig.json with source paths pointing at SimPlex/ directory
- Existing .brs files must compile unchanged (BrighterScript is a superset)
- Add diagnosticFilters as needed to suppress false positives on existing code
- Do NOT rename .brs files to .bs -- keep existing extensions for Phase 1
- Do NOT adopt BrighterScript v1.0.0-alpha (unstable, breaking changes)
- GetConstants() result cached in m.global at startup (MainScene.init)
- All components access constants via m.global instead of calling GetConstants()
- Pattern: m.global.addFields({ constants: GetConstants() }) in MainScene.init()
- Fix API task collision: create a new Task node instance per concurrent request
- VSCode launch.json configured with roku-deploy for one-key sideload
- package.json with "deploy" script as backup

### Claude's Discretion
- Exact bsconfig.json diagnosticFilters needed for existing code
- Whether to use task instance pooling or create-per-request pattern
- roku-deploy configuration details (host, password placeholders)
- Any additional npm scripts (lint, clean, etc.)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INFRA-01 | BrighterScript 0.70.x compiler set up with bsconfig.json and roku-deploy | Standard Stack section covers exact versions, bsconfig.json structure, and installation. Code Examples section provides bsconfig.json template. |
| INFRA-02 | GetConstants() cached in m.global to eliminate per-call GC pressure | Architecture Patterns section covers the m.global caching pattern. Code Examples section shows the exact init() code and component access pattern. |
| INFRA-03 | API task collision pattern fixed (one task instance per concurrent request) | Architecture Patterns section covers create-per-request vs pooling tradeoffs. Code Examples section shows the refactored pattern. |
| INFRA-04 | F5 deploy from VSCode works with zero manual steps | Standard Stack section covers the VSCode extension. Code Examples section provides launch.json and .env templates. |
</phase_requirements>

## Summary

This phase establishes the build toolchain and runtime foundation for SimPlex. The core deliverables are: (1) BrighterScript 0.70.x compilation of existing .brs files, (2) constants caching in m.global, (3) fixing the API task collision pattern where a single shared PlexApiTask instance gets clobbered by concurrent requests, and (4) F5 deploy from VSCode.

The existing codebase is straightforward BrightScript with SceneGraph components. The current `GetConstants()` function in `source/constants.brs` returns a fresh associative array on every call -- this is called from `GetPlexHeaders()` in `utils.brs` and from `loadLibrary()`/`processApiResponse()` in `HomeScreen.brs`, meaning every API request and every grid render allocates a new constants object. The collision pattern is visible in HomeScreen.brs where a single `m.apiTask` is stored at line 14 and reused for all requests -- if a user navigates quickly, the second request overwrites the first's endpoint/params before it completes.

**Primary recommendation:** Install brighterscript 0.70.3 and roku-deploy 3.16.1 as npm devDependencies, configure bsconfig.json with rootDir pointing to SimPlex/, use create-per-request pattern for API tasks (simpler than pooling, well within Roku's 100-thread limit), and set up VSCode launch.json with .env file for device credentials.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| brighterscript | 0.70.3 | BrightScript superset compiler and language server | Official RokuCommunity compiler; used by the VSCode extension for intellisense; transpiles to standard BrightScript |
| roku-deploy | 3.16.1 | Zip and sideload to Roku device | Official RokuCommunity deploy tool; integrates with bsconfig.json; used by VSCode extension under the hood |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @rokucommunity/bslint | latest | BrightScript/BrighterScript linter | Optional -- add after compilation works; can be added as BrighterScript plugin |

### VSCode Extension (not npm)
| Extension | ID | Purpose |
|-----------|-----|---------|
| BrightScript Language | RokuCommunity.brightscript | Syntax highlighting, F5 deploy, debug protocol, language server |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Create-per-request tasks | Task instance pool | Pool adds complexity (lifecycle management, pool sizing) for minimal benefit; Roku allows 100 concurrent threads, SimPlex will use 2-5 max |
| brighterscript 1.0.0-alpha | brighterscript 0.70.x | 1.0 has breaking changes between alpha releases; locked decision to avoid |

**Installation:**
```bash
npm init -y
npm install --save-dev brighterscript@0.70.3 roku-deploy@3.16.1
```

## Architecture Patterns

### Recommended Project Structure (after Phase 1)
```
SimPlex/                     # Git repo root
├── package.json             # npm project with devDependencies
├── bsconfig.json            # BrighterScript compiler config
├── .vscode/
│   └── launch.json          # F5 deploy config
├── .env                     # Roku device credentials (gitignored)
├── SimPlex/                 # Roku app root (rootDir for bsconfig)
│   ├── manifest
│   ├── source/
│   │   ├── main.brs
│   │   ├── utils.brs
│   │   ├── constants.brs
│   │   ├── logger.brs
│   │   ├── normalizers.brs
│   │   └── capabilities.brs
│   ├── components/
│   │   ├── MainScene.xml/.brs
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── tasks/
│   └── images/
└── .gitignore               # Add: node_modules/, .env, out/
```

### Pattern 1: Constants Caching via m.global
**What:** Cache GetConstants() result in m.global once at app startup, access from all components via m.global.constants
**When to use:** Always -- eliminates per-call allocation of the constants associative array
**Current problem:** GetConstants() is called in GetPlexHeaders() (every API request), loadLibrary(), and processApiResponse(). Each call allocates a new roAssociativeArray.
**Migration path:**
1. Add `m.global.addFields({ constants: GetConstants() })` in MainScene.init()
2. Replace `c = GetConstants()` with `c = m.global.constants` in all component .brs files
3. Replace `c = GetConstants()` with `c = m.global.constants` in utils.brs GetPlexHeaders()
4. Task nodes access m.global directly (they receive a clone of the global node)

**Important note about Task nodes:** Task node threads receive a clone of the SceneGraph node tree at launch. They CAN read m.global fields. The constants will be available in task threads without any special handling.

### Pattern 2: Create-Per-Request API Tasks
**What:** Create a fresh PlexApiTask node for each API request instead of reusing a single instance
**When to use:** Whenever a screen needs to make an API call
**Why create-per-request over pooling:**
- Simpler code -- no pool lifecycle management
- Roku allows up to 100 concurrent task threads (warning at 50)
- SimPlex will realistically have 2-5 concurrent requests max (sidebar libraries + grid content + maybe a background refresh)
- Task nodes are lightweight SceneGraph nodes, creation cost is negligible
- Old reference gets garbage collected when the screen/component releases it

**Migration impact:** Each screen currently stores `m.apiTask` as a single instance created in init(). The fix requires:
1. Remove `m.apiTask = CreateObject("roSGNode", "PlexApiTask")` from init()
2. Create a helper function that creates a new task, sets endpoint/params, observes status, and runs it
3. In the observer callback, read response from the specific task instance (passed via event source)

### Pattern 3: VSCode F5 Deploy with .env Credentials
**What:** Press F5 in VSCode to compile BrighterScript, zip, and sideload to Roku
**How it works:** The BrightScript VSCode extension reads launch.json, uses BrighterScript to compile, uses roku-deploy to package and upload
**Credentials:** Use .env file (gitignored) referenced via envFile in launch.json

### Anti-Patterns to Avoid
- **Reusing a single Task node for sequential requests:** This is the exact bug being fixed. Setting new endpoint/params on a running task causes race conditions. Always create a new task instance.
- **Calling GetConstants() in loops or hot paths:** After this phase, all constants access should go through m.global.constants. No new GetConstants() calls should appear in component code.
- **Storing Roku device credentials in launch.json:** Use .env file and ${env:VAR} syntax instead. launch.json is committed; .env is gitignored.
- **Using autoImportComponentScript: true with existing code:** This option auto-links .bs files to same-named .xml components. Since we keep .brs extensions in Phase 1, this should be false or omitted.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BrightScript compilation | Custom build scripts | brighterscript CLI (`bsc`) | Handles transpilation, validation, source maps |
| Roku sideloading | Manual zip + curl to device | roku-deploy (via VSCode extension) | Handles zip creation, multipart upload, device communication |
| Device credential management | Hardcoded IPs/passwords | .env file + VSCode envFile | Keeps secrets out of version control |
| BrightScript language server | N/A | BrighterScript language server (via VSCode extension) | Provides intellisense, error checking, go-to-definition |

**Key insight:** The RokuCommunity toolchain (BrighterScript + roku-deploy + VSCode extension) is tightly integrated. Using all three together means F5 deploy works out of the box. Fighting the toolchain by using individual pieces separately creates unnecessary friction.

## Common Pitfalls

### Pitfall 1: bsconfig.json rootDir vs launch.json rootDir confusion
**What goes wrong:** BrighterScript compiles from the wrong directory, or roku-deploy packages the wrong files
**Why it happens:** The project has a nested structure: repo root contains `SimPlex/` subdirectory which contains the actual Roku app (with manifest). Both bsconfig.json and launch.json have rootDir settings that must point to `SimPlex/`.
**How to avoid:** Set `"rootDir": "SimPlex"` in bsconfig.json (relative to where bsconfig.json lives at repo root). Set `"rootDir": "${workspaceFolder}/SimPlex"` in launch.json.
**Warning signs:** "manifest file not found" errors during build/deploy.

### Pitfall 2: BrighterScript false positives on dynamic BrightScript patterns
**What goes wrong:** BrighterScript reports errors on valid BrightScript code that uses dynamic typing patterns
**Why it happens:** BrighterScript's type system is stricter than raw BrightScript. Patterns like `event.getData()` returning Dynamic, or associative array field access with mixed types, can trigger warnings.
**How to avoid:** Use `diagnosticFilters` in bsconfig.json to suppress specific error codes. Start with compilation, note which codes appear, add them to filters.
**Warning signs:** Hundreds of warnings/errors on first compile of existing code. Common codes to expect: 1001 (cannot find name), 1067 (type mismatch).

### Pitfall 3: Task node field observation after re-run
**What goes wrong:** Observer fires with stale data from previous task run
**Why it happens:** When you set `task.control = "run"` on an already-completed task, the status field might still hold the old value. The observer only fires on change.
**How to avoid:** With create-per-request pattern, this is eliminated entirely -- each task is fresh. This is another reason to prefer create-per-request.
**Warning signs:** Callbacks receiving unexpected/stale response data.

### Pitfall 4: Forgetting to update GetPlexHeaders() in utils.brs
**What goes wrong:** GetPlexHeaders() still calls GetConstants() directly even after caching, negating the optimization
**Why it happens:** utils.brs functions run in both render thread and task threads. Easy to forget during migration.
**How to avoid:** Search for ALL occurrences of `GetConstants()` across the codebase and replace with `m.global.constants`.
**Warning signs:** GetConstants() still appearing in grep results after migration.

### Pitfall 5: m.global.constants not available in source/ utility functions
**What goes wrong:** Functions in `source/utils.brs` like `GetPlexHeaders()` try to access `m.global.constants` but m.global may not exist in all execution contexts
**Why it happens:** `m.global` is a SceneGraph concept. In Task node threads, m.global IS available (it's cloned). In the render thread, m.global IS available. But if any utility function were called before SceneGraph initialization, m.global would be invalid.
**How to avoid:** In practice this is not an issue because all code paths in SimPlex run within SceneGraph context (either render thread or task thread). But add a safety check: `if m.global <> invalid and m.global.constants <> invalid` as defensive coding.
**Warning signs:** "member does not exist" crash on app startup (would only happen if startup order is wrong).

## Code Examples

### bsconfig.json Template
```json
{
    "$schema": "https://raw.githubusercontent.com/rokucommunity/brighterscript/master/bsconfig.schema.json",
    "rootDir": "SimPlex",
    "stagingDir": "out/staging",
    "retainStagingDir": false,
    "sourceMap": true,
    "files": [
        "manifest",
        "source/**/*.brs",
        "components/**/*.brs",
        "components/**/*.xml",
        "images/**/*"
    ],
    "diagnosticFilters": [
        {
            "src": "**/*.brs",
            "codes": []
        }
    ],
    "deploy": {
        "host": "${env:ROKU_HOST}",
        "password": "${env:ROKU_PASSWORD}"
    }
}
```
Note: The `diagnosticFilters.codes` array should be populated after first compilation reveals which codes need suppressing. Do NOT pre-emptively suppress everything.

### .env File Template
```bash
# Roku device credentials -- DO NOT commit this file
ROKU_HOST=192.168.1.xxx
ROKU_PASSWORD=your-roku-dev-password
ROKU_USERNAME=rokudev
```

### .vscode/launch.json Template
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "brightscript",
            "request": "launch",
            "name": "SimPlex: Deploy to Roku",
            "envFile": "${workspaceFolder}/.env",
            "host": "${env:ROKU_HOST}",
            "password": "${env:ROKU_PASSWORD}",
            "rootDir": "${workspaceFolder}/SimPlex",
            "files": [
                "manifest",
                "source/**/*.brs",
                "components/**/*.brs",
                "components/**/*.xml",
                "images/**/*"
            ]
        }
    ]
}
```

### Constants Caching in MainScene.init()
```brightscript
' In MainScene.brs init()
sub init()
    ' Cache constants in m.global FIRST, before anything else
    m.global.addFields({ constants: GetConstants() })

    m.screenContainer = m.top.findNode("screenContainer")
    m.screenStack = []
    m.focusStack = []

    ' ... rest of existing init code ...
end sub
```

### Component Access Pattern (replacing GetConstants() calls)
```brightscript
' BEFORE (allocates new AA each call):
c = GetConstants()
endpoint = "/library/sections/" + m.currentSectionId + "/all"
params["X-Plex-Container-Size"] = c.PAGE_SIZE.ToStr()

' AFTER (reads cached global):
c = m.global.constants
endpoint = "/library/sections/" + m.currentSectionId + "/all"
params["X-Plex-Container-Size"] = c.PAGE_SIZE.ToStr()
```

### GetPlexHeaders() Update in utils.brs
```brightscript
' BEFORE:
function GetPlexHeaders() as Object
    di = CreateObject("roDeviceInfo")
    c = GetConstants()
    return { ... }
end function

' AFTER:
function GetPlexHeaders() as Object
    di = CreateObject("roDeviceInfo")
    c = m.global.constants
    return { ... }
end function
```

### Create-Per-Request API Task Pattern
```brightscript
' Helper function to create and fire an API request
' Returns the task node so caller can store reference if needed
function makeApiRequest(endpoint as String, params as Object, callback as String) as Object
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = endpoint
    task.params = params
    task.observeField("status", callback)
    task.control = "run"
    return task
end function

' Usage in a screen (e.g., HomeScreen.brs):
sub loadLibrary()
    if m.isLoading then return
    m.isLoading = true
    m.loadingSpinner.visible = true

    c = m.global.constants
    endpoint = "/library/sections/" + m.currentSectionId + "/all"
    params = {
        "sort": "titleSort:asc"
        "X-Plex-Container-Start": m.currentOffset.ToStr()
        "X-Plex-Container-Size": c.PAGE_SIZE.ToStr()
    }

    ' Create fresh task for this request
    m.currentApiTask = makeApiRequest(endpoint, params, "onLibraryLoaded")
end sub

sub onLibraryLoaded(event as Object)
    task = event.getRoSGNode()  ' Get the specific task that completed
    status = event.getData()
    if status = "completed"
        response = task.response
        ' Process response...
    else if status = "error"
        ' Handle error from task.error
    end if
    m.isLoading = false
    m.loadingSpinner.visible = false
end sub
```

### package.json Scripts
```json
{
    "name": "simplex",
    "version": "1.0.0",
    "private": true,
    "scripts": {
        "build": "bsc",
        "deploy": "bsc --deploy",
        "lint": "bsc --noEmit"
    },
    "devDependencies": {
        "brighterscript": "^0.70.3",
        "roku-deploy": "^3.16.1"
    }
}
```

### .gitignore Additions
```
node_modules/
out/
.env
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual zip + curl sideload | roku-deploy + VSCode F5 | ~2020 | One-key deploy from IDE |
| Raw BrightScript only | BrighterScript superset | ~2019 | Type checking, namespaces, classes (opt-in) |
| Maestro MVVM framework | Plain BrightScript + SceneGraph | Maestro deprecated Nov 2023 | No framework overhead; stick with idiomatic SceneGraph |
| Single shared task instance | Create-per-request pattern | Best practice since SceneGraph introduction | Eliminates race conditions in concurrent requests |

**Deprecated/outdated:**
- Maestro MVVM: Deprecated November 2023; do not adopt (confirmed in project requirements)
- BrighterScript v1.0.0-alpha: Unstable, breaking changes between releases; locked decision to avoid

## Open Questions

1. **Exact diagnosticFilters codes needed**
   - What we know: BrighterScript will likely report false positives on dynamic BrightScript patterns in existing code
   - What's unclear: Which specific diagnostic codes will fire on this codebase
   - Recommendation: Compile first, note codes, add to filters iteratively. This is explicitly listed as Claude's discretion.

2. **Whether bsconfig.json deploy section supports ${env:VAR} syntax**
   - What we know: launch.json supports ${env:VAR} via the VSCode extension's envFile feature. bsconfig.json is read by the brighterscript CLI directly.
   - What's unclear: Whether the CLI supports env var interpolation in bsconfig.json
   - Recommendation: Use launch.json for F5 deploy (confirmed working with env vars). Use `npm run deploy` with env vars passed via CLI flags or dotenv as backup. The bsconfig.json deploy section may need literal values or a wrapper script.

3. **event.getRoSGNode() availability for task callback pattern**
   - What we know: In SceneGraph observer callbacks, the event object provides `getRoSGNode()` to get the node that triggered the event
   - What's unclear: Whether this returns the task node itself or its parent; need to verify during implementation
   - Recommendation: Test during implementation. If getRoSGNode() does not return the task, store task reference in m scope variable (e.g., m.currentApiTask) and read response from it in callback.

## Sources

### Primary (HIGH confidence)
- [BrighterScript GitHub](https://github.com/rokucommunity/brighterscript) - versions, bsconfig.json structure, compiler features
- [roku-deploy GitHub](https://github.com/rokucommunity/roku-deploy) - version 3.16.1, configuration options
- [VSCode BrightScript Extension docs](https://rokucommunity.github.io/vscode-brightscript-language/Debugging/index.html) - launch.json configuration
- [VSCode BrightScript .env docs](https://rokucommunity.github.io/vscode-brightscript-language/Debugging/env-file.html) - environment variable support
- [Roku Task node docs](https://developer.roku.com/docs/references/scenegraph/control-nodes/task.md) - thread limits, task lifecycle

### Secondary (MEDIUM confidence)
- [BrighterScript bsconfig.md](https://github.com/rokucommunity/BrighterScript/blob/master/docs/bsconfig.md) - diagnosticFilters syntax
- [BrighterScript suppressing-compiler-messages.md](https://github.com/rokucommunity/BrighterScript/blob/master/docs/suppressing-compiler-messages.md) - filter configuration
- Existing codebase analysis (HomeScreen.brs, PlexApiTask.brs, utils.brs, constants.brs) - collision pattern, constants usage

### Tertiary (LOW confidence)
- bsconfig.json ${env:VAR} interpolation support -- not confirmed in official docs; needs validation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions confirmed via npm, tools well-documented
- Architecture: HIGH - patterns derived from Roku official docs and existing codebase analysis
- Pitfalls: HIGH - based on direct codebase inspection and known SceneGraph behaviors

**Research date:** 2026-03-08
**Valid until:** 2026-04-08 (stable ecosystem, slow-moving)

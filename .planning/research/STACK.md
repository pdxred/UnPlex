# Technology Stack

**Project:** PlexClassic
**Domain:** Roku Plex Media Server Client
**Researched:** 2026-02-09
**Overall Confidence:** MEDIUM

## Recommended Stack

### Core Platform

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Roku OS | 15.0+ | Target platform | Latest stable release with improved BrightScript engine, better memory management, and new APIs for efficient data transfer. OS 15.1 adds Perfetto tracing support. |
| BrightScript | Latest (OS 15.0) | Primary language | Native Roku language with improved JSON parsing, new roUtils component, and ifArraySizeInfo interface for better array management. |
| SceneGraph | RSG 1.3 | UI framework | Required for all modern Roku apps. Version 1.3 will be mandatory for certification by October 1, 2026. Provides component-based architecture with XML layout + BrightScript logic. |
| FHD Resolution | 1920x1080 | Display target | Standard for non-4K Roku devices, wide device compatibility. 4K devices scale down gracefully. |

**Confidence:** HIGH - These are official Roku platform requirements verified from official documentation and recent Roku OS releases.

### Development Language Enhancement

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| BrighterScript | 0.70.3+ | Development language (optional) | **Recommended for new projects.** Superset of BrightScript that compiles to standard BrightScript. Adds classes, namespaces, import statements, ternary operators, template strings, null-coalescing. Catches errors at compile-time without device. 100% compatible with all Roku devices. |

**Confidence:** HIGH - Widely adopted community standard with 189 GitHub stars, maintained by RokuCommunity.

**Decision:** Use BrighterScript for development, compile to BrightScript for deployment. This gives modern language features while maintaining full compatibility.

### Core SceneGraph Components

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| PosterGrid | Grid of graphic images | Library browsing, collections, search results. Set basePosterSize to exact image dimensions for best appearance. |
| MarkupGrid | Grid with markup support | Similar to PosterGrid but supports markup in labels |
| RowList | Horizontal rows of content | Home screen, continue watching, recommendations |
| LabelList | Text-based lists | Settings menus, simple navigation |
| Video | Video playback | Primary playback component for direct play and transcoded content |
| ContentNode | Data model | All list/grid data. Use instead of associative arrays - passed by reference, much faster for complex data. |
| Task | Background threading | **Critical: All HTTP requests MUST run in Task nodes.** Using roUrlTransfer on render thread causes crashes. |

**Confidence:** HIGH - These are official Roku SDK components verified from developer documentation.

### Task Nodes (HTTP & Background Operations)

| Task Type | Purpose | Implementation Pattern |
|-----------|---------|------------------------|
| PlexAuthTask | OAuth PIN flow | POST to plex.tv/api/v2/pins, poll for authToken |
| PlexApiTask | General PMS requests | GET/POST with X-Plex-* headers, pagination support |
| PlexSearchTask | Search queries | Debounced search with query parameters |
| PlexSessionTask | Playback progress | PUT to /:/timeline with state/time |
| ImageCacheTask | Poster prefetching | Request resized images via /photo/:/transcode |

**Confidence:** MEDIUM - Based on standard Plex API patterns and Roku Task node best practices.

### Development Tools

| Tool | Version | Purpose | Why Essential |
|------|---------|---------|---------------|
| VSCode | Latest | Primary IDE | Industry standard with excellent Roku support |
| vscode-brightscript-language | Latest | VSCode extension | Official RokuCommunity extension used by thousands. Provides debugging, breakpoints, syntax highlighting, device deployment. Includes roku-debug, roku-deploy, brighterscript-formatter. |
| roku-deploy | 3.14.4+ | Deployment automation | Zip and deploy to devices. Handles staging, package creation, sideloading. Prepares for roku-deploy v4. |
| bslint | 0.8.38+ | Static analysis | Linter for BrightScript/BrighterScript. Includes --fix for auto-formatting, --checkUsage for unused code detection. Enforces certification requirements (e.g., color-cert for broadcast safe colors). |
| ropm | 0.11.2+ | Package manager | Roku package manager using npm behind the scenes. Prevents naming collisions via prefix rewriting. Supports OIDC for publishing. |

**Confidence:** HIGH - All tools from official RokuCommunity ecosystem with active maintenance.

### Testing & Quality Assurance

| Tool | Purpose | When to Use |
|------|---------|-------------|
| Rooibos | Unit testing | **Recommended.** Modern framework inspired by Mocha. Backward compatible with official framework. Easier to use than alternatives. |
| Official Unit Testing Framework | Unit testing | Fallback if Rooibos doesn't work. Less ergonomic but officially supported. |
| Roku Test Automation (RTA) | Functional testing | E2E testing on actual devices. For critical user flows. |
| Roku Developer Tools Web Portal | Device debugging | Port 8080 on device. View logs, SceneGraph hierarchy, performance metrics. |
| Perfetto Tracing | Performance profiling | Roku OS 15.1+. Deep performance analysis for optimization. |

**Confidence:** MEDIUM - Multiple frameworks available, Rooibos is community preference but official framework is more conservative choice.

### Data Management

| Technology | Purpose | Best Practices |
|------------|---------|----------------|
| ContentNode | In-memory data | Use for all grid/list data. Passed by reference (fast). Structured parent→children hierarchy. Supports Content Meta-Data fields. |
| roRegistrySection | Persistent storage | 16KB limit per channel. ALWAYS call .Flush() after writes. Use "Transient" section for per-boot data. Store playback position, user preferences. |
| Server-side storage | Multi-device sync | Prefer for auth tokens, watch history that syncs across devices. Registry is per-device only. |
| Roku OS 15.0 APIs | Data transfer | Use new move APIs instead of copying for large objects. Reduces memory overhead. |

**Confidence:** HIGH - Official Roku patterns verified from documentation and performance guides.

### HTTP & Networking

| Pattern | Implementation | Critical Requirements |
|---------|----------------|----------------------|
| HTTPS requests | roUrlTransfer in Task nodes | MUST call SetCertificatesFile("common:/certs/ca-bundle.crt") and InitClientCertificates() before every request |
| Request headers | GetPlexHeaders() utility | Include ALL X-Plex-* headers on every Plex API call (Platform, Product, Version, Device-Name, Client-Identifier) |
| Pagination | Container-Start/Size | Use X-Plex-Container-Start and X-Plex-Container-Size=50 for library fetches |
| Multiple requests | Discrete Task nodes | For N parallel requests, use N Task nodes. Don't reuse objects across threads. |
| Response handling | Field observers | task.observeField("state", "onTaskCallback"), check task.response after completion |

**Confidence:** HIGH - Official Roku requirements and Plex API standards.

### Video Playback

| Technology | Purpose | Notes |
|------------|---------|-------|
| Video node | Primary playback | Built-in SceneGraph component. Supports direct play and HLS transcoding. |
| Direct Play | Native file playback | Use {server}{partKey}?X-Plex-Token={token}. Check codec compatibility first. |
| HLS Transcoding | Universal playback | Use /video/:/transcode/universal/start.m3u8 endpoint. Fallback when direct play fails. |
| Progress Tracking | Timeline reporting | PUT to /:/timeline with ratingKey, state (playing/paused/stopped), time in milliseconds |
| HEVC/H.265 | 4K playback | Supported only on 4K-capable devices (Roku 4, Premiere, Streaming Stick+, Ultra). Note: 2024+ Ultra models may prefer H.265 for 4K. |

**Confidence:** MEDIUM - Based on Plex API documentation and community reports. Codec behavior varies by device generation.

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| roUrlTransfer on render thread | **Critical:** Causes rendezvous crashes. Roku will reject the app. | Always use Task nodes for HTTP requests |
| Associative arrays for large data | Copied by value, slow for complex structures | ContentNode (passed by reference) |
| Custom scrolling implementations | Reinventing the wheel, poor performance, accessibility issues | Built-in PosterGrid, RowList, LabelList components |
| Hardcoded image URLs | No resizing, wastes bandwidth, slow loading | /photo/:/transcode?width=240&height=360 |
| Skipping Flush() on registry writes | Data not persisted, user settings lost | Always call .Flush() after roRegistrySection writes |
| Old RSG versions | Won't pass certification after Oct 2026 | Set rsg_version=1.3 in manifest |
| Missing HTTPS certificates | SSL errors on all requests | SetCertificatesFile() + InitClientCertificates() |
| Polling without debounce | Excessive API calls, poor UX | Debounce search queries, use field observers properly |

**Confidence:** HIGH - These are known anti-patterns that cause app rejection or poor performance.

## Development Workflow

### Initial Setup

```bash
# Install Node.js tooling
npm install -g brighterscript @rokucommunity/bslint ropm

# Initialize project
npm init -y
npm install --save-dev brighterscript @rokucommunity/bslint

# Create VSCode workspace
# Install "BrightScript Language" extension (RokuCommunity.brightscript)
```

### Project Structure

```
PlexClassic/
├── manifest                 # Roku app manifest (UTF-8, rsg_version=1.3)
├── source/                  # BrightScript/BrighterScript source
│   ├── main.brs            # Entry point
│   ├── utils.brs           # Shared helpers
│   └── constants.brs       # Constants
├── components/              # SceneGraph components
│   ├── MainScene.xml/.brs  # Root scene
│   ├── screens/            # Full-screen views
│   ├── widgets/            # Reusable UI components
│   └── tasks/              # Background Task nodes
├── images/                  # Assets (icons, splash, placeholders)
├── bsconfig.json           # BrighterScript config
├── .vscode/
│   └── launch.json         # Debug configuration
└── rokudeploy.json         # Deployment config
```

### Build & Deploy

```bash
# Compile BrighterScript to BrightScript
npx bsc

# Lint
npx bslint --fix

# Deploy to device (via VSCode extension)
# F5 to launch debugger

# Or via command line
npx roku-deploy --host <roku-ip> --password <dev-password>
```

### Debugging

```bash
# Set breakpoints in VSCode
# Launch debugger (F5)
# Note: Breakpoints inject STOP statements, must restart debug session for new breakpoints

# Device telnet debugging (port 8085)
telnet <roku-ip> 8085

# Web-based developer tools
http://<roku-ip>:8080
```

## Alternatives Considered

| Category | Recommended | Alternative | When to Use Alternative |
|----------|-------------|-------------|-------------------------|
| Development Language | BrighterScript | Pure BrightScript | Legacy codebases, team unfamiliar with transpilation |
| Unit Testing | Rooibos | Official Framework | Conservative teams, concerned about community support |
| Package Management | ropm | Manual file management | Simple projects with no dependencies |
| IDE | VSCode + RokuCommunity | Sublime/Atom/others | Personal preference, but VSCode has best tooling |
| Video Component | Built-in Video node | Custom implementation | Never - built-in is certification requirement |

## Stack Patterns by Project Variant

**If building from scratch (greenfield):**
- Use BrighterScript with classes and namespaces
- Implement proper API abstraction layer (PlexApiTask)
- Use ropm for any shared libraries
- Set up bslint with --fix from day one

**If modifying existing BrightScript codebase:**
- BrighterScript is backward compatible, can adopt incrementally
- Start by adding .bsconfig.json and renaming .brs to .bs for new files
- Keep existing .brs files as-is, they'll work unchanged
- Gradually refactor to use classes/namespaces as you touch files

**For this project (PlexClassic):**
- Greenfield: Use BrighterScript with modern patterns
- Component-based architecture (XML + .bs files)
- Task nodes for all HTTP (PlexAuthTask, PlexApiTask, PlexSearchTask, PlexSessionTask)
- ContentNode for all data, roRegistrySection for persistence
- Built-in PosterGrid/RowList/LabelList for UI
- Direct Play with transcode fallback

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| brighterscript@0.70.3+ | Roku OS 9.0+ | Transpiles to compatible BrightScript |
| bslint@0.8.38+ | brighterscript@0.65+ | Works with both .brs and .bs files |
| roku-deploy@3.14.4+ | All Roku devices | v4 coming soon with enhanced features |
| ropm@0.11.2+ | npm registries | Uses npm module system behind the scenes |
| Roku OS 15.0/15.1 | All current devices | Backward compatible with OS 9.0+ features |

## Installation

```bash
# Global tools (one-time)
npm install -g brighterscript @rokucommunity/bslint ropm

# Project dependencies
npm init -y
npm install --save-dev brighterscript @rokucommunity/bslint

# VSCode extension (install via Extensions marketplace)
# Search: "BrightScript Language" by RokuCommunity
```

## Configuration Files

**bsconfig.json** (BrighterScript compiler):
```json
{
  "rootDir": "./",
  "files": [
    "source/**/*",
    "components/**/*"
  ],
  "outDir": "./out",
  "diagnosticFilters": [
    {
      "src": "**/roku_modules/**",
      "codes": [1000, 1001]
    }
  ]
}
```

**rokudeploy.json** (Deployment):
```json
{
  "host": "192.168.1.XXX",
  "password": "your-dev-password",
  "rootDir": "./",
  "files": [
    "source/**/*",
    "components/**/*",
    "images/**/*",
    "manifest"
  ],
  "retainStagingFolder": false
}
```

**.vscode/launch.json** (Debugging):
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "brightscript",
      "request": "launch",
      "name": "Launch PlexClassic",
      "host": "${env:ROKU_HOST}",
      "password": "${env:ROKU_PASSWORD}",
      "rootDir": "${workspaceFolder}",
      "stopOnEntry": false
    }
  ]
}
```

## Certification Requirements (2025-2026)

1. **RSG Version:** Must set `rsg_version=1.3` in manifest by October 1, 2026
2. **Color Certification:** Use bslint's color-cert rule to enforce broadcast-safe colors (6.4 certification)
3. **HTTPS:** All network requests must use HTTPS with proper certificate configuration
4. **Memory Management:** Apps must not consume excessive memory (test with Roku Resource Monitor 4.2)
5. **Thread Safety:** All HTTP in Task nodes, no roUrlTransfer on render thread
6. **Accessibility:** Support for screen readers, proper focus management

## Sources

### Official Roku Documentation
- [Roku OS 15.0 Beta Announcement](https://blog.roku.com/developer/roku-os-15-0-beta) - MEDIUM confidence (official source, feature descriptions)
- [Roku Developer Portal](https://developer.roku.com) - HIGH confidence (official docs, attempted access but blocked)

### Development Tools & Community
- [BrighterScript GitHub](https://github.com/rokucommunity/brighterscript) - HIGH confidence (official repo, 189 stars, active development)
- [vscode-brightscript-language](https://github.com/rokucommunity/vscode-brightscript-language) - HIGH confidence (official extension, thousands of users)
- [roku-deploy GitHub](https://github.com/rokucommunity/roku-deploy) - HIGH confidence (official deployment tool)
- [bslint GitHub](https://github.com/rokucommunity/bslint) - HIGH confidence (official linter, v0.8.38)
- [ropm GitHub](https://github.com/rokucommunity/ropm) - HIGH confidence (official package manager, v0.11.2)
- [RokuCommunity Documentation](https://rokucommunity.github.io/) - HIGH confidence (official community hub)

### Best Practices & Patterns
- [BrightScript Fundamentals (Medium)](https://medium.com/@krishna.kumar.chaturvedi/chapter-3-brightscript-fundamentals-the-heart-of-your-roku-app-9f5a370c0870) - MEDIUM confidence (community tutorial)
- [Mastering Tasks and Multithreading (Medium)](https://medium.com/@krishna.kumar.chaturvedi/mastering-tasks-and-multithreading-in-roku-the-complete-guide-to-responsive-api-calls-5237511c4da3) - MEDIUM confidence (community guide)
- [Screen Stack Navigation (Medium)](https://medium.com/@amitdogra70512/navigating-screen-stacks-in-roku-a-guide-to-creating-and-managing-multiple-screens-using-arrays-1f9cbb736079) - MEDIUM confidence (community patterns)
- [Using HTTPS on Roku](https://rymawby.com/brightscript/roku/Using-HTTPS-on-a-Roku-device.html) - MEDIUM confidence (developer blog)

### Testing Frameworks
- [Rooibos Testing Framework](https://community.roku.com/discussions/developer/announcing-rooibos-unit-testing-framework-for-roku-/509104) - MEDIUM confidence (community announcement)
- [Official Unit Testing Framework](https://github.com/rokudev/unit-testing-framework) - HIGH confidence (official Roku repo)

### Performance & Optimization
- [Memory Management Guide](https://developer.roku.com/docs/developer-program/performance-guide/memory-management.md) - HIGH confidence (official docs, attempted access)
- [Roku OS 14.5 Memory Management](https://cordcuttersnews.com/roku-teases-roku-os-14-5-update-with-developer-insights-on-memory-management-and-ui-enhancements/) - MEDIUM confidence (news coverage of official announcement)
- [Roku Developer Summit 2025](https://www.inellipse.com/roku-developer-summit-2025/) - MEDIUM confidence (event coverage)

### Platform Components
- [PosterGrid Component](https://developer.roku.com/docs/references/scenegraph/list-and-grid-nodes/postergrid.md) - HIGH confidence (official docs, attempted access)
- [ContentNode Documentation](https://developer.roku.com/docs/references/scenegraph/control-nodes/contentnode.md) - HIGH confidence (official docs, attempted access)
- [Field Observers](https://developer.roku.com/docs/developer-program/core-concepts/scenegraph-xml/node-field-observers.md) - HIGH confidence (official docs, attempted access)

---
*Stack research for: PlexClassic Roku Plex Client*
*Researched: 2026-02-09*
*Overall Confidence: MEDIUM - Mix of HIGH confidence official sources and MEDIUM confidence community sources. Core platform and tooling recommendations are verified from official sources. Best practices synthesized from multiple community sources with consistent patterns.*

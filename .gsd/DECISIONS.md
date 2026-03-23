# Decisions Register

<!-- Append-only. Never edit or remove existing rows.
     To reverse a decision, add a new row that supersedes it.
     Read this file at the start of any planning or research phase. -->

| # | When | Scope | Decision | Choice | Rationale | Revisable? | Made By |
|---|------|-------|----------|--------|-----------|------------|---------|
| D001 | M001/S13 | architecture | Sidebar library data exposure format | Assocarray with items array (not ContentNode) via Sidebar.libraries interface field | Simpler cross-component readability than ContentNode trees. Any parent component can read library metadata (key, title, type) without reaching into Sidebar internals. Read-only, populated after API response. | Yes | agent |
| D002 | M001/S14 | navigation | TV show navigation flow — grid/hub tap target | TV shows route to EpisodeScreen directly; DetailScreen accessible via options key "Show Info" from both HomeScreen and EpisodeScreen | Reduces navigation hops for the most common TV show interaction (browsing episodes). DetailScreen remains one options-key press away for users who want full show metadata. Safe degradation: items without itemType="show" fall through to the default DetailScreen path. | Yes | agent |
| D003 | M001/S15 | architecture | Server switching removal strategy — how to handle multi-server Plex accounts | Auto-connect to first server (servers[0]) via existing autoConnectToServer() sub; no server selection UI | SimPlex is a single-server personal-use client. Multi-server selection adds complexity with no benefit for the target use case. Reusing autoConnectToServer() for both single and multi-server paths eliminates code duplication and crash risk from the now-deleted ServerListScreen. | Yes | agent |

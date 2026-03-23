# Decisions Register

<!-- Append-only. Never edit or remove existing rows.
     To reverse a decision, add a new row that supersedes it.
     Read this file at the start of any planning or research phase. -->

| # | When | Scope | Decision | Choice | Rationale | Revisable? | Made By |
|---|------|-------|----------|--------|-----------|------------|---------|
| D001 | M001/S13 | architecture | Sidebar library data exposure format | Assocarray with items array (not ContentNode) via Sidebar.libraries interface field | Simpler cross-component readability than ContentNode trees. Any parent component can read library metadata (key, title, type) without reaching into Sidebar internals. Read-only, populated after API response. | Yes | agent |

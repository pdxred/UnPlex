---
estimated_steps: 3
estimated_files: 3
skills_used: []
---

# T02: Fix collections navigation — auto-select first library when none active

**Slice:** S13 — Search, Collections, and Thumbnails
**Milestone:** M001

## Description

Fix FIX-04: tapping "Collections" in the sidebar when no library has been previously selected silently does nothing. The root cause is that HomeScreen's `onSpecialAction("viewCollections")` guards with `if m.currentSectionId <> ""` — which is empty string on fresh launch until a user taps a specific library.

The fix: expose Sidebar's loaded libraries via a new interface field, then in HomeScreen's viewCollections handler, auto-select the first library when `m.currentSectionId` is empty.

## Steps

1. **Sidebar.xml — add `libraries` interface field.** Add to the `<interface>` block:
   ```xml
   <field id="libraries" type="assocarray" />
   ```
   This field will hold an array-like assocarray (Roku assocarray with numeric keys is awkward — use a node field of type `node` or just an assocarray with a `list` key containing the array). Actually, the simplest approach on Roku: use `type="node"` and create a ContentNode with children. But that's overkill for this. The cleanest approach: use `type="assocarray"` with `alwaysNotify="true"` and set it to an AA like `{ items: [{ key: "1", type: "movie", title: "Movies" }, ...] }`.

2. **Sidebar.brs — set m.top.libraries in processLibraries().** After the existing line `m.libraryCount = m.libraries.count()` (near the end of processLibraries), add:
   ```brightscript
   ' Expose libraries for HomeScreen collections fallback
   libList = []
   for each lib in m.libraries
       libList.push({ key: lib.key, type: lib.type, title: lib.title })
   end for
   m.top.libraries = { items: libList }
   ```
   This serializes the library metadata into a simple assocarray that can be read across component boundaries.

3. **HomeScreen.brs — auto-select library in onSpecialAction("viewCollections").** Replace the current block:
   ```brightscript
   else if action = "viewCollections"
       if m.currentSectionId <> ""
           m.isCollectionsView = true
           ...
           loadCollections()
       end if
   ```
   With logic that also handles empty currentSectionId:
   ```brightscript
   else if action = "viewCollections"
       ' Auto-select first library if none active
       if m.currentSectionId = ""
           sidebarLibs = m.sidebar.libraries
           if sidebarLibs <> invalid and sidebarLibs.items <> invalid and sidebarLibs.items.count() > 0
               firstLib = sidebarLibs.items[0]
               m.currentSectionId = firstLib.key
               m.currentSectionType = firstLib.type
           end if
       end if
       if m.currentSectionId <> ""
           m.isCollectionsView = true
           m.collectionRatingKey = ""
           m.isPlaylistsView = false
           m.currentOffset = 0
           m.viewMode = "libraryOnly"
           onViewModeChanged()
           m.filterBar.visible = false
           m.alphaNav.visible = false
           loadCollections()
       end if
   ```
   The guard `if m.currentSectionId <> ""` remains as a safety check — if libraries haven't loaded yet (sidebar fetch in progress), the tap is still a no-op, which matches existing behavior and is acceptable.

## Must-Haves

- [ ] Sidebar.xml has a `libraries` field in its interface
- [ ] Sidebar.brs sets `m.top.libraries` after processing library data
- [ ] HomeScreen.brs reads sidebar libraries and auto-selects first one when currentSectionId is empty
- [ ] Existing behavior unchanged when a library is already selected (m.currentSectionId non-empty)
- [ ] Guard against libraries not yet loaded (sidebarLibs = invalid)

## Verification

- `grep -c "libraries" SimPlex/components/widgets/Sidebar.xml` returns ≥1
- `grep -c "m.top.libraries" SimPlex/components/widgets/Sidebar.brs` returns ≥1
- `grep -c "m.sidebar.libraries" SimPlex/components/screens/HomeScreen.brs` returns ≥1
- The `viewCollections` block in HomeScreen.brs no longer silently exits when `m.currentSectionId = ""`

## Inputs

- `SimPlex/components/widgets/Sidebar.xml` — current interface (no libraries field)
- `SimPlex/components/widgets/Sidebar.brs` — processLibraries() builds m.libraries array
- `SimPlex/components/screens/HomeScreen.brs` — onSpecialAction with viewCollections guard on m.currentSectionId

## Expected Output

- `SimPlex/components/widgets/Sidebar.xml` — new `libraries` interface field
- `SimPlex/components/widgets/Sidebar.brs` — sets m.top.libraries after library fetch
- `SimPlex/components/screens/HomeScreen.brs` — auto-select first library for collections when none active

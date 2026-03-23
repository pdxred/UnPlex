# T02: 11-crash-safety-and-foundation 02

**Slice:** S11 — **Milestone:** M001

## Description

Extract GetRatingKeyStr() to utils.brs, replace all 13+ inline duplicates across 6 files, and fix the hardcoded progress bar width in PosterGridItem.

Purpose: Eliminate duplicated utility code and use constants instead of magic numbers, making the codebase maintainable for v1.1 screen work.
Output: Single GetRatingKeyStr() in utils.brs, all inline blocks replaced, progress bar using POSTER_WIDTH constant.

## Must-Haves

- [ ] "GetRatingKeyStr() exists as a single shared helper in utils.brs"
- [ ] "No inline ratingKey type-check blocks remain in any screen file"
- [ ] "The local getRatingKeyString function in DetailScreen.brs is deleted"
- [ ] "Progress bar width in PosterGridItem uses POSTER_WIDTH constant"

## Files

- `SimPlex/source/utils.brs`
- `SimPlex/components/screens/DetailScreen.brs`
- `SimPlex/components/screens/EpisodeScreen.brs`
- `SimPlex/components/screens/HomeScreen.brs`
- `SimPlex/components/screens/PlaylistScreen.brs`
- `SimPlex/components/screens/SearchScreen.brs`
- `SimPlex/components/widgets/VideoPlayer.brs`
- `SimPlex/components/widgets/PosterGridItem.brs`

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-03-25

### Added

- Delete button on DetailScreen (movies & episodes) with confirmation dialog
- Get Info button showing MediaInfoScreen with file path, container, codecs, resolution, bitrate, channels, and file size
- About section in Settings showing app version
- Export Logs button in Settings writing debug log buffer to tmp:/
- GitHub Issue template (bug report) and PR template
- CHANGELOG.md with retroactive entries for all versions
- Debug log collection guide in CONTRIBUTING.md
- MIT license headers on all source files

### Changed

- README rewritten with clear positioning as a lightweight general-purpose Plex client
- ARCHITECTURE.md and CONTRIBUTING.md updated for current codebase
- Build output now produces versioned zip (UnPlex-v1.3.0.zip)

### Removed

- "Go to Season" button from episode DetailScreen

## [1.2.0] - 2026-03-25

### Added

- Custom EpisodeGrid component with manual key handling
- ShowScreen season picker with episode grid
- Detailed episode metadata display

### Changed

- TV show detail architecture completely reworked
- Episode navigation overhauled

### Fixed

- EpisodeGrid focus handling
- ShowScreen focus navigation
- Episode selection routing

## [1.1.0] - 2026-03-24

### Added

- SearchScreen rewrite with custom keyboard grid, filter row, and horizontal results

### Changed

- SimPlex renamed to UnPlex across entire codebase
- Remote updated to pdxred/UnPlex

### Fixed

- Sidebar library pinning duplicates
- SearchScreen crash on init
- Various focus and navigation bugs

## [1.0.0] - 2026-03-13

### Added

- Sidebar navigation with library hub rows
- Poster grids with filtering and sorting
- Movie and TV show playback with resume support
- Progress bars and watch status
- Audio and subtitle track selection
- Intro and credits skip detection
- Collections and playlists support
- Managed user switching with PIN support
- HD and FHD resolution support

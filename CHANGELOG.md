# Changelog

All notable changes to this project will be documented in this file.
The format loosely follows Keep a Changelog and Semantic Versioning.

## [1.1.0] - 2025-09-23
### Added
- Scope-based synchronization using `playerEnteredScope` / `playerLeftScope` events (performance improvement) with fallback radius scan.
- `AdminMode.SelfOpaque` option: admin sees self at normal alpha while others see transparency.
- `AdminMode.AllowedGroups` for permission gating of `/admin` command.
- Automatic late-join synchronization event `adminmode:requestSync`.
- Automatic locale file discovery (no need to list each in `fxmanifest.lua`).
- Locale key sanitation (collapsing multiple underscores) to avoid display of raw keys.
- Configurable locale fallback chain via `Config.LocaleFallback`.
- Performance section in `config.lua` (`Config.Performance`).

### Changed
- Consolidated duplicate `playerDropped` handlers and improved cleanup of transparency state.
- README updated with new features, upgrade instructions, and performance notes.
- Improved locale loader resilience when `Config.ResourceName` mismatches the folder name.

### Fixed
- Raw keys like `admin3d__line1` appearing in 3D text due to mis-typed underscores or resource name mismatch.
- Potential missing transparency sync for players joining after admins toggled mode.

### Notes
- Existing configs remain compatible; add the new optional fields to benefit from enhancements.
- If scope events are unreliable in your server build, disable with `Config.Performance.UseScopeEvents = false`.

## [1.0.1] - 2025-09-22
### Added
- Minor internal refinements (initial public adjustments).

## [1.0.0] - Initial Release
### Features
- Basic admin toggle (transparency + optional godmode).
- 3D admin text lines.
- Teleport and dimension commands.
- Static ID (optional external resource).
- Basic locale system (en/de).
- Optional database + Discord logging.


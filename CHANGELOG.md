# Changelog

All notable changes to ShuttleX are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.4] - 2026-06-17

### Fixed
- Launch failures for CLI terminals (Ghostty, Alacritty, kitty, WezTerm) now surface in the UI instead of only the system log.
- Groups that share a name (e.g. from hand-edited JSON) are merged on load, so they no longer collide as identities or share expand/collapse state.
- An inline `# comment` on a `Host` line in `~/.ssh/config` is no longer turned into bogus host aliases.

## [1.6.3] - 2026-06-15

### Changed
- Terminal.app "new tab" now waits until the tab actually appears (up to ~2 s) instead of a fixed delay — reliable on slow or busy Macs.

### Fixed
- An unreadable `~/.ssh/config` (permissions/encoding) now surfaces a clear error with a permissions hint instead of silently showing no servers. A missing file stays a calm "no config found" message. Unreadable `Include` files are logged and skipped instead of failing the whole parse.

## [1.6.2] - 2026-06-15

### Added
- DMG download (drag-to-install), built and attached to every release automatically.

### Fixed
- Completed AppleScript and Warp-YAML escaping to also handle `\r`, `\n`, `\t` (defense-in-depth; the untrusted import path already rejected these characters).

## [1.6.1] - 2026-06-14

### Changed
- New app icon: a space-shuttle launch stack (Pixabay, recolored white on the blue→indigo squircle). The menu bar glyph is unchanged.

## [1.6.0] - 2026-06-14

### Added
- In-app server editor (JSON source): add, edit, rename, move between groups, and delete servers from Settings → "Add / edit servers…" — no hand-editing of JSON required.
- Credits to the original SSHMenu and to Shuttle in the README.

## [1.5.3] - 2026-06-14

### Fixed
- No longer opens two windows when launching a terminal that wasn't running; ShuttleX reuses the window the terminal opens on startup.

## [1.5.2] - 2026-06-14

### Changed
- When the terminal isn't running yet, a new window is always opened; tab/split only apply once a window exists.

## [1.5.1] - 2026-06-14

### Added
- Search also matches group names — a query like "web" shows the whole "Prod · web" group, not only servers with "web" in their name.

## [1.5.0] - 2026-06-14

### Added
- Swift Testing suite; CI now runs `swift test`.
- Proper app icon (`.icns`).

### Changed
- Terminals are addressed by bundle id (robust against the iTerm/iTerm2 naming). Friendly guidance is shown when AppleScript is blocked by Automation/Accessibility permissions.

### Fixed
- Backup write/prune failures are logged instead of being swallowed silently.

## [1.4.2] - 2026-06-14

### Security
- Prevent command injection from server data: SSH targets are shell-quoted when the command is built, and imported rows whose fields contain unsafe characters are skipped.

## [1.4.1] - 2026-06-14

### Added
- `SECURITY.md` with a vulnerability reporting policy.

## [1.4.0] - 2026-06-14

### Added
- JSON backup history — the last 3 versions are kept next to the file on every change.
- Configurable JSON file path (Settings → "Choose…").

## [1.3.1] - 2026-06-13

### Changed
- Translated the app UI, code comments, and metadata to English.

## [1.3.0] - 2026-06-13

### Added
- Collapsible groups in the menu (collapsed by default; expand on click; matches expand automatically while searching).

### Changed
- The name column is used verbatim as the display name.

## [1.2.1] - 2026-06-13

### Fixed
- CSV files with CRLF line endings (Google Sheets exports) were not split into rows.

## [1.2.0] - 2026-06-13

### Added
- Table import: CSV / TSV / XLSX → ShuttleX JSON, grouped by "Stage · Cluster".

## [1.1.1] - 2026-06-13

### Changed
- Menu bar icon: a shuttle-orbiter side profile as a template image (adapts to light/dark).

## [1.1.0] - 2026-06-13

### Added
- Initial release. A menu-bar SSH launcher built with SwiftUI (`MenuBarExtra`), pure arm64 for Apple Silicon. Hosts from `~/.ssh/config` or a JSON file; choose your terminal (Terminal, iTerm2, Ghostty, Warp, Alacritty, kitty, WezTerm); open in a new window, tab, or split.

[1.6.4]: https://github.com/DasDuo/ShuttleX/compare/v1.6.3...v1.6.4
[1.6.3]: https://github.com/DasDuo/ShuttleX/compare/v1.6.2...v1.6.3
[1.6.2]: https://github.com/DasDuo/ShuttleX/compare/v1.6.1...v1.6.2
[1.6.1]: https://github.com/DasDuo/ShuttleX/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/DasDuo/ShuttleX/compare/v1.5.3...v1.6.0
[1.5.3]: https://github.com/DasDuo/ShuttleX/compare/v1.5.2...v1.5.3
[1.5.2]: https://github.com/DasDuo/ShuttleX/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/DasDuo/ShuttleX/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/DasDuo/ShuttleX/compare/v1.4.2...v1.5.0
[1.4.2]: https://github.com/DasDuo/ShuttleX/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/DasDuo/ShuttleX/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/DasDuo/ShuttleX/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/DasDuo/ShuttleX/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/DasDuo/ShuttleX/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/DasDuo/ShuttleX/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/DasDuo/ShuttleX/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/DasDuo/ShuttleX/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/DasDuo/ShuttleX/releases/tag/v1.1.0

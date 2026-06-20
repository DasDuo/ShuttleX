# Changelog

All notable changes to ShuttleX are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.11.0] - 2026-06-20

### Added
- **Global hotkey** (configurable in Settings → General, off by default): press it from anywhere to open ShuttleX as a centered, Spotlight-style search window — the search field is focused, type to filter, **↑/↓** to pick, **Enter** to connect, **Esc** to dismiss. Press it again to close.
- **Remote server source** (Settings → Server source → **Remote URL**): load a read-only server list from an `https://` URL — a shared "single source of truth" for a team. Inventory only (groups, names, host, port); any commands in the file are ignored for safety, and the list is cached locally so the menu still works offline.
- **Default SSH user** (JSON and remote sources): a global default login user for entries that don't set their own, with a "Use default user" toggle per server in the editor.
- **Personal, local overrides for the remote source**: set your own **login user** and **favorites** per server. They're stored locally (keyed by host:port), so they're personal to you and survive remote reloads — managed in a consistent "Edit servers…" editor.

### Changed
- The menu is now a standalone panel instead of a `MenuBarExtra` popover, which is what makes the programmatic/hotkey open possible. Clicking the menu-bar icon still shows the familiar dropdown **anchored under the icon** (the original Shuttle/SSHMenu feel); the global hotkey is an additional power-user layer that opens the same panel centered on screen.

## [1.10.0] - 2026-06-18

### Added
- Keyboard navigation in the menu: **↑/↓** moves the selection through the results (the list scrolls to keep it visible) and **Enter** connects the selected server. The search field clears after connecting.

## [1.9.0] - 2026-06-18

### Added
- Favorites: pin your most-used servers to a **★ Favorites** section at the top of the dropdown — hover the star on a row, or use the **Favorite** toggle in the editor. The section is expanded by default when small (≤5) and always collapsible. Stored as `favorite` in the JSON (written only when set); JSON source only.

## [1.8.0] - 2026-06-17

### Added
- Run a command on a server: a new **Remote command** field in the editor (`remoteCommand` in JSON) builds `ssh -t … <command>` from the host/user/port — e.g. enter `htop`. A **Raw custom command** toggle keeps the verbatim mode for jump hosts/tunnels.
- Reorder servers within a group by dragging them in the editor.

### Fixed
- Servers that share a name (e.g. two "AdGuard" with different IPs) are now handled correctly in the editor — editing, deleting or reordering one no longer affects the other. Entries now carry an internal id instead of being matched by name.

## [1.7.2] - 2026-06-17

### Changed
- The Settings window now has a bounded height and scrolls, so it fits smaller screens (e.g. 14") instead of growing to its full content height.

## [1.7.1] - 2026-06-17

### Fixed
- The menu popover no longer resizes and jumps toward the menu bar when expanding or collapsing a group. The list area now has a fixed height and scrolls internally, so the panel stays in a stable position.

## [1.7.0] - 2026-06-17

### Added
- Optional update check (off by default): when enabled in Settings → General, ShuttleX checks the public GitHub Releases API at most once a day and shows an "Update available" hint in the menu that links to the download page. No account, no tracking; it never auto-installs.

### Changed
- Release notes are now taken from this changelog instead of an auto-generated commit list.

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

[1.11.0]: https://github.com/DasDuo/ShuttleX/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/DasDuo/ShuttleX/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/DasDuo/ShuttleX/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/DasDuo/ShuttleX/compare/v1.7.2...v1.8.0
[1.7.2]: https://github.com/DasDuo/ShuttleX/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/DasDuo/ShuttleX/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/DasDuo/ShuttleX/compare/v1.6.4...v1.7.0
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

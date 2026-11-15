# Changelog

All notable changes to ShuttleX are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.17.1] - 2026-11-15

### Fixed
- Opening Settings could bring up an extra blank window next to it. ShuttleX carries an empty placeholder `Settings` scene (SwiftUI requires an app to have one), which macOS could restore as a stray window — and activating the app pulled it to the front. Such a window is now closed on sight, and ShuttleX's own windows opt out of window restoration so no new ones appear.
- Closing Settings or the server editor left ShuttleX active with no window on screen, so the next keystrokes went nowhere. Closing now returns you where you came from: the menu comes back if that's where you opened it from — whether by the gear or ⌘, — and otherwise focus goes back to the app you were working in.
- Switching to another app (e.g. ⌘-Tab) while the server editor was open could hide that window along with the menu.

## [1.17.0] - 2026-11-15

### Added
- **Edit button in the menu**: the top bar now carries a pencil next to Reload and the gear that opens the server editor directly — previously the editor was only reachable through Settings. It's hidden when the source is `~/.ssh/config`, which ShuttleX reads but never edits.

### Changed
- **The server editor is its own window** instead of a sheet on top of Settings: it manages your server list rather than configuring the app. It resizes for long lists, and closing it brings the menu back when that's where you came from.
- The Settings window is wider (520pt) and resizable — it used to be exactly as wide as the sheets it hosted, which left them sitting flush against the window edges.

### Fixed
- With an empty server list, the menu said *"Edit the JSON file in Settings."* — sending you to hand-edit JSON instead of to the built-in editor that exists so you don't have to. It now points at the editor.
- `build.sh` now asks the toolchain where it put the binary instead of hard-coding the path. Swift 6.4 moved the build output, so building locally silently packaged a stale binary from an older toolchain. Only affects building from source — released builds were never affected.

## [1.16.0] - 2026-11-15

### Added
- **←/→ jump between groups** in the menu: while browsing with the keyboard (empty search field), ←/→ move the selection to the previous/next group — the fast way past a big group. While typing a query, ←/→ keep moving the text cursor as usual.
- **Compact list** (Settings → General, off by default): dense menu rows — server name only, no icon, no detail line, tighter spacing. Handy for long lists.

### Note on the 1.16.0 betas
The `1.16.0-beta.1` / `beta.2` prereleases contained a **URL entry type** (opening `https://`, `vnc://`, `rdp://` targets). It has been **removed**: ShuttleX is an SSH launcher, and opening other protocols pulls it away from that one purpose. Those prereleases also shipped without the two features above — the code was left out of the release commit by mistake, which is fixed here.

## [1.15.0] - 2026-08-14

### Added
- **Open a whole group, staggered**: right-click a group header and choose **"Open all N — staggered"** to open every server in the group one after another, spaced by a configurable delay (Settings → General → "Open-all stagger", default 2 s). The spacing keeps SSH-agent prompts (e.g. Secretive touch approvals) sequential instead of a burst. Note: ShuttleX can't detect when a session is fully established (ssh runs inside the terminal), so a fixed stagger is the honest approximation.

## [1.14.6] - 2026-07-13

### Fixed
- On managed Macs (endpoint/security tooling with invisible overlay windows), clicking inside the panel — e.g. a group header — could close it instead: the overlay received the click, so ShuttleX's outside-click monitor fired. Clicks are now judged by **screen position**: inside the panel's frame never closes it, regardless of which app the event was delivered to.

### Changed
- Panel diagnostics now use `os.Logger` with public payloads — plain `NSLog` content is redacted to `<private>` in `log stream`, which made remote debugging blind.

## [1.14.5] - 2026-07-13

### Changed
- Added lightweight diagnostic logging around the panel (why it was shown/hidden, where an "outside" click landed, group-header toggles — no host names or other data). Visible via `log stream --predicate 'process == "ShuttleX"'`; helps debug machine-specific reports like the panel closing on click.

## [1.14.4] - 2026-07-12

### Fixed
- Opening a connection as an iTerm2 **split** now focuses the new pane, so you can type into the new session right away — previously the previously active session kept the focus. (Windows and tabs already behaved correctly.)

## [1.14.3] - 2026-06-29

### Fixed
- **↑/↓ now work immediately** when the menu opens — no need to type first. Arrow-browsing steps through all servers accordion-style: only the group holding the selection is expanded, the previous one collapses. Searching still expands everything, and Enter on a fresh, collapsed menu deliberately does nothing.
- **Esc (or clicking elsewhere) now hands focus back** to the app you came from. Previously ShuttleX stayed the active app with no window after closing the hotkey panel, so your next keystrokes went nowhere until you clicked. An open Settings window is not affected.

## [1.14.2] - 2026-06-29

### Fixed
- The hotkey recorder accepted key combinations without a real modifier — recording e.g. a plain `K` would have made every "K" typed in *any* app open ShuttleX. A shortcut now requires ⌘, ⌥ or ⌃.
- Typing in the **Remote URL** or **Default user** fields no longer reloads on every keystroke — while typing a URL this fired network requests against partial hostnames. Reload now happens on Enter, via the Reload button, and on every menu open as before.
- The remote inventory is no longer re-fetched on every menu open: fetches of the same URL are throttled to once per minute (the cached list still shows instantly). The **Reload** button and editing the URL bypass the throttle.

## [1.14.1] - 2026-06-28

### Fixed
- A single group (e.g. the whole list when the source is `~/.ssh/config`) couldn't be collapsed — its chevron did nothing. It now toggles like any other group: expanded by default when small (≤5 hosts), collapsed otherwise (with many hosts you search instead of scroll), and always collapsible. Searching still expands everything.

## [1.14.0] - 2026-06-27

### Added
- **Duplicate a server** in the editor (the new icon next to Edit): inserts a copy directly below, with `-copy` appended to the name and everything else carried over. Handy for variants of the same host without re-typing it — e.g. one entry that opens a shell and another that runs a remote command like `htop`, or the same server with a different user or port.

## [1.13.1] - 2026-06-27

### Fixed
- Pressing **⌘,** opened an empty grey window instead of Settings. It now opens the real settings window — the same one the gear button opens.
- Opening Settings is now consistent from every entry point (gear, ⌘,, the right-click menu): the dropdown panel closes first and the settings window comes cleanly to the front, instead of the floating panel sometimes covering it.

## [1.13.0] - 2026-06-27

### Added
- **Copy SSH command**: right-click any server in the menu to copy its `ssh …` command to the clipboard — handy for sharing in chat, pasting into another terminal, or dropping into a ticket. Works for every source.

## [1.12.0] - 2026-06-22

### Added
- **Optional server tags** (off by default; enable in Settings → General). When on, each server gets an optional comma-separated **Tags** field in the editor, tags show as small badges in the menu, and search matches them. When off, tags appear nowhere — and any existing tags are kept, not removed. Stored as `tags` in the JSON (written only when set); a remote source may also provide them (strings only, never executed).

## [1.11.3] - 2026-06-22

### Changed
- The table-import preview now shows at most 50 servers (with a "Showing 50 of N" note) and renders lazily, so importing a large sheet (hundreds/thousands of rows) stays responsive. All rows are still imported — only the preview is capped.

### Fixed
- IPv6 addresses in bracket notation (e.g. `[2001:db8::1]`) were wrongly rejected by the in-app editor and table import. The character denylist treated `[` and `]` as unsafe (shell globbing) — but they pose no risk here: every connection target is shell-quoted when the `ssh` command is built, and *that* is the actual injection guard, not the denylist. Brackets are now allowed, so bracketed IPv6 hosts save and import correctly; genuine shell metacharacters and whitespace are still rejected.

## [1.11.2] - 2026-06-22

### Fixed
- Opening Settings still crashed in 1.11.1. The cause was `KeyboardShortcuts.Recorder`, whose `Bundle.module` can't be resolved in a hand-built, code-signed `.app` (its accessor only looks next to the executable or at a baked build path — and a resource bundle at the app root can't be signed). Replaced it with a small custom recorder that uses only the package's core API and never touches `Bundle.module`.

## [1.11.1] - 2026-06-22

### Fixed
- The app crashed when opening Settings (the global-hotkey recorder couldn't find its resources). SPM package resource bundles (`KeyboardShortcuts`) are now bundled into the app, so `Bundle.module` resolves at runtime.

## [1.11.0] - 2026-06-22

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

[1.17.1]: https://github.com/DasDuo/ShuttleX/compare/v1.17.0...v1.17.1
[1.17.0]: https://github.com/DasDuo/ShuttleX/compare/v1.16.0...v1.17.0
[1.16.0]: https://github.com/DasDuo/ShuttleX/compare/v1.15.0...v1.16.0
[1.15.0]: https://github.com/DasDuo/ShuttleX/compare/v1.14.6...v1.15.0
[1.14.6]: https://github.com/DasDuo/ShuttleX/compare/v1.14.5...v1.14.6
[1.14.5]: https://github.com/DasDuo/ShuttleX/compare/v1.14.4...v1.14.5
[1.14.4]: https://github.com/DasDuo/ShuttleX/compare/v1.14.3...v1.14.4
[1.14.3]: https://github.com/DasDuo/ShuttleX/compare/v1.14.2...v1.14.3
[1.14.2]: https://github.com/DasDuo/ShuttleX/compare/v1.14.1...v1.14.2
[1.14.1]: https://github.com/DasDuo/ShuttleX/compare/v1.14.0...v1.14.1
[1.14.0]: https://github.com/DasDuo/ShuttleX/compare/v1.13.1...v1.14.0
[1.13.1]: https://github.com/DasDuo/ShuttleX/compare/v1.13.0...v1.13.1
[1.13.0]: https://github.com/DasDuo/ShuttleX/compare/v1.12.0...v1.13.0
[1.12.0]: https://github.com/DasDuo/ShuttleX/compare/v1.11.3...v1.12.0
[1.11.3]: https://github.com/DasDuo/ShuttleX/compare/v1.11.2...v1.11.3
[1.11.2]: https://github.com/DasDuo/ShuttleX/compare/v1.11.1...v1.11.2
[1.11.1]: https://github.com/DasDuo/ShuttleX/compare/v1.11.0...v1.11.1
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

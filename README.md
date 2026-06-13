# ShuttleX

A modern SSH launcher for the macOS menu bar — inspired by [Shuttle](https://github.com/fitztrev/shuttle), rebuilt with SwiftUI (`MenuBarExtra`, `@Observable`). Pure **arm64** binary for Apple Silicon, not a universal app.

## Features

- Lives entirely in the menu bar (no Dock icon); a modern dropdown panel with a search field, hover effects, and **collapsible groups** (collapsed by default, click to expand; matches expand automatically while searching)
- **Switchable server source** (Settings → Server source):
  - `~/.ssh/config` — hosts are read directly (including `Include` directives; wildcard hosts like `*` are ignored)
  - JSON file at `~/.config/shuttlex/servers.json` (created with sample entries the first time you switch to it). The path is configurable in Settings, and the last 3 versions are kept as backups next to the file (`servers.backup-…json`) on every change — manual or imported
- **Choose your terminal app**: Terminal, iTerm2, Ghostty, Warp, Alacritty, kitty, WezTerm — only apps that are actually installed are offered (also switchable right in the dropdown footer)
- **Choose how it opens** (dropdown footer or Settings): new window, new tab, or split pane — depending on what the terminal app supports:
  - iTerm2: window, tab, split right, split down
  - Terminal.app: window, tab (tab needs the Accessibility permission once, see Notes)
  - Ghostty, Warp, Alacritty, kitty, WezTerm: new windows only (can't be steered otherwise from outside; unsupported modes fall back to "new window" automatically)
- Search + Enter connects straight to the first match
- Optional: launch at login (Settings → General)

## Download

Prebuilt binaries are on the [Releases](https://github.com/DasDuo/ShuttleX/releases) page — download `ShuttleX-<version>-arm64.zip`, unzip it, move it to `/Applications`, and approve it once (see "Distributing to another Mac").

Releases are produced automatically: push a tag (`git tag v1.3.0 && git push origin v1.3.0`) and GitHub Actions builds and publishes the zip.

## Build & run

```sh
./build.sh
open build/ShuttleX.app
```

Requirements: an Apple Silicon Mac, Xcode (or the Command Line Tools) with Swift 5.9+, macOS 14+.

For "launch at login" to work reliably, copy the app to `/Applications` after building:

```sh
cp -R build/ShuttleX.app /Applications/
```

## Table import (CSV / Excel / Google Sheets)

ShuttleX can generate the JSON directly from a spreadsheet — handy when you manage many servers. Settings → **Table import → "Import table …"**.

Expected columns (order doesn't matter; the header row is detected automatically, and German/English names are recognized):

| User | Server DNS | Server IP | Cluster | Stage |
|------|-----------|-----------|---------|-------|
| deploy | web01.prod.example.com | 10.0.1.11 | web | Prod |

- **Format**: CSV, TSV, or Excel (`.xlsx`). The `,` and `;` delimiters are auto-detected. Google Sheets: just export as CSV or Excel (File → Download).
- **IP or DNS**: before importing you choose whether the connection target is the DNS name or the IP address (if the chosen value is missing, it falls back to the other).
- **Name**: the "Server DNS" (or "Name") column is used verbatim as the display name in the menu — it doesn't have to be a real DNS. You can pick the IP as the connection target independently.
- **Grouping**: one group is created per combination as `Stage · Cluster` (e.g. "Prod · web") — keeping the menu tidy.
- **Mode**: *Merge* updates entries with the same name and adds new ones (manually maintained servers are preserved); *Replace* overwrites the JSON file completely.

A sample file lives at [`examples/servers-sample.csv`](examples/servers-sample.csv).

## JSON format

`~/.config/shuttlex/servers.json`:

```json
{
  "groups": [
    {
      "name": "Production",
      "hosts": [
        { "name": "Web server", "user": "root", "host": "web1.example.com" },
        { "name": "Database", "user": "admin", "host": "db.example.com", "port": 2222 },
        { "name": "Via jump host", "command": "ssh -J jump.example.com root@10.0.0.5" }
      ]
    }
  ],
  "hosts": [
    { "name": "Ungrouped", "host": "example.org" }
  ]
}
```

- `host`/`user`/`port` are assembled into `ssh user@host -p port`
- `command` allows arbitrary custom commands (jump hosts, tunnels, mosh, …)
- top-level `hosts` end up in a group called "Server"

## Distributing to another Mac

Besides the app bundle, `./build.sh` also produces `ShuttleX-<version>-arm64.zip`. Copy the zip to the target Mac, unzip it, and move the app to `/Applications`.

Because the app is only ad-hoc signed (not notarized), Gatekeeper blocks the first launch when the file arrives via the internet/AirDrop. There are two ways to approve it:

1. **Via Terminal** (simplest): remove the quarantine attribute, after which the app starts normally:
   ```sh
   xattr -dr com.apple.quarantine /Applications/ShuttleX.app
   ```
2. **Via System Settings**: launch the app once (dismiss the warning), then click **"Open Anyway"** under *System Settings → Privacy & Security*. (Since macOS 15, right-click → Open is no longer enough.)

If the app arrives on a FAT/exFAT-formatted USB stick, no quarantine attribute is set and it starts right away.

Distributing without this hurdle would require a **Developer ID signature + notarization** (Apple Developer account, $99/year). With an account: `codesign --sign "Developer ID Application: …" --options runtime` followed by `xcrun notarytool submit`.

## Notes

- For Terminal.app and iTerm2, macOS asks once on first connect for permission ("ShuttleX wants to control Terminal") — this is required for AppleScript and must be allowed.
- The "new tab" mode in Terminal.app works via a simulated Cmd+T keystroke (Terminal.app offers no AppleScript API for it). For this, ShuttleX must be allowed under System Settings → Privacy & Security → Accessibility. iTerm2 doesn't need this — there tabs and splits go straight through the AppleScript API.
- Splits open in the currently active iTerm2 window; with no window open, a new one is created instead (same behavior for tabs).
- Ghostty, Alacritty, kitty, and WezTerm are launched via command-line arguments; Warp via a launch configuration (`warp://launch/…`).
- The app is ad-hoc signed (local build). Distributing to other Macs would require a Developer ID signature + notarization.

## License

[MIT](LICENSE)

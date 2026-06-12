# ShuttleX

Moderner SSH-Launcher für die macOS-Menüleiste — inspiriert von [Shuttle](https://github.com/fitztrev/shuttle), neu gebaut mit SwiftUI (`MenuBarExtra`, `@Observable`). Reines **arm64**-Binary für Apple Silicon, keine Universal App.

## Features

- Lebt ausschließlich in der Menüleiste (kein Dock-Icon), modernes Dropdown-Panel mit Suchfeld, Hover-Effekten und Gruppen
- **Server-Quelle umschaltbar** (Einstellungen → Server-Quelle):
  - `~/.ssh/config` — Hosts werden direkt ausgelesen (inkl. `Include`-Direktiven, Wildcard-Hosts wie `*` werden ignoriert)
  - JSON-Datei unter `~/.config/shuttlex/servers.json` (wird beim ersten Umschalten mit Beispiel-Einträgen angelegt)
- **Terminal-App wählbar**: Terminal, iTerm2, Ghostty, Warp, Alacritty, kitty, WezTerm — es werden nur tatsächlich installierte Apps angeboten (auch direkt im Footer des Dropdowns umschaltbar)
- **Öffnen-Modus wählbar** (Footer des Dropdowns oder Einstellungen): Neues Fenster, Neuer Tab oder Split-Pane — je nachdem, was die Terminal-App kann:
  - iTerm2: Fenster, Tab, Split rechts, Split unten
  - Terminal.app: Fenster, Tab (Tab benötigt einmalig die Bedienungshilfen-Berechtigung, siehe Hinweise)
  - Ghostty, Warp, Alacritty, kitty, WezTerm: nur neue Fenster (von außen nicht anders steuerbar; nicht unterstützte Modi fallen automatisch auf „Neues Fenster“ zurück)
- Suche + Enter verbindet direkt zum ersten Treffer
- Optional: Start beim Anmelden (Einstellungen → Allgemein)

## Bauen & Starten

```sh
./build.sh
open build/ShuttleX.app
```

Voraussetzungen: Apple-Silicon-Mac, Xcode (oder Command Line Tools) mit Swift 5.9+, macOS 14+.

Damit „Beim Anmelden starten“ zuverlässig funktioniert, die App nach dem Build nach `/Applications` kopieren:

```sh
cp -R build/ShuttleX.app /Applications/
```

## JSON-Format

`~/.config/shuttlex/servers.json`:

```json
{
  "groups": [
    {
      "name": "Produktion",
      "hosts": [
        { "name": "Webserver", "user": "root", "host": "web1.example.com" },
        { "name": "Datenbank", "user": "admin", "host": "db.example.com", "port": 2222 },
        { "name": "Via Jumphost", "command": "ssh -J jump.example.com root@10.0.0.5" }
      ]
    }
  ],
  "hosts": [
    { "name": "Ohne Gruppe", "host": "example.org" }
  ]
}
```

- `host`/`user`/`port` werden zu `ssh user@host -p port` zusammengesetzt
- `command` erlaubt beliebige eigene Befehle (Jumphosts, Tunnel, mosh, …)
- `hosts` auf oberster Ebene landet in der Gruppe „Server“

## Weitergabe an einen anderen Mac

`./build.sh` erzeugt neben dem App-Bundle auch `ShuttleX-<version>-arm64.zip`. Das Zip auf den Ziel-Mac kopieren, entpacken und die App nach `/Applications` ziehen.

Da die App nur ad-hoc signiert (nicht notarisiert) ist, blockiert Gatekeeper den ersten Start, wenn die Datei aus dem Internet/AirDrop kommt. Freigeben geht auf zwei Wegen:

1. **Per Terminal** (einfachster Weg): Quarantäne-Attribut entfernen, danach startet die App normal:
   ```sh
   xattr -dr com.apple.quarantine /Applications/ShuttleX.app
   ```
2. **Per Systemeinstellungen**: App einmal starten (Meldung wegklicken), dann unter *Systemeinstellungen → Datenschutz & Sicherheit* auf **„Dennoch öffnen“** klicken. (Seit macOS 15 reicht Rechtsklick → Öffnen nicht mehr.)

Kommt die App per USB-Stick (FAT/exFAT-formatiert), wird kein Quarantäne-Attribut gesetzt und sie startet direkt.

Für eine Weitergabe ohne diese Hürde bräuchte es eine **Developer-ID-Signatur + Notarisierung** (Apple-Developer-Account, 99 €/Jahr). Mit Account: `codesign --sign "Developer ID Application: …" --options runtime` und anschließend `xcrun notarytool submit`.

## Hinweise

- Bei Terminal.app und iTerm2 fragt macOS beim ersten Verbinden einmalig nach der Berechtigung „ShuttleX möchte Terminal steuern“ — das ist für AppleScript nötig und muss erlaubt werden.
- Der Modus „Neuer Tab“ in Terminal.app funktioniert über einen simulierten Cmd+T-Tastendruck (Terminal.app bietet dafür keine AppleScript-API). Dafür muss ShuttleX unter Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen erlaubt werden. iTerm2 braucht das nicht — dort gehen Tabs und Splits direkt über die AppleScript-API.
- Splits öffnen sich im aktuell aktiven iTerm2-Fenster; ohne offenes Fenster wird stattdessen ein neues erstellt (gleiches Verhalten bei Tabs).
- Ghostty, Alacritty, kitty und WezTerm werden über Kommandozeilen-Argumente gestartet, Warp über eine Launch-Configuration (`warp://launch/…`).
- Die App ist ad-hoc signiert (lokaler Build). Für die Weitergabe an andere Macs wäre eine Developer-ID-Signatur + Notarisierung nötig.

# Artisan Port Manager

Artisan Port Manager is a lightweight, native macOS menu-bar utility for finding and managing listening TCP ports. It is built with Swift, SwiftUI, and small amounts of AppKit for system integrations—no web runtime or third-party dependencies.

## Features

- Live, ascending list of TCP listeners with port, process, PID, user, address family, command, executable, working directory, and inferred project name
- Instant search across ports, PIDs, process names, projects, commands, users, addresses, and working directories
- Native browser, clipboard, and Finder actions
- Safe process control: PID identity revalidation, SIGTERM by default, separately confirmed SIGKILL, self-process protection, duplicate-signal prevention, and clear permission errors
- Manual refresh (`⌘R`) and configurable auto-refresh while the menu UI is active
- Launch at Login using `SMAppService`
- Native light/dark appearance, context menus, empty/loading/error states, and no Dock icon

## Screenshots

Screenshots are not checked into this source-only repository. Build and run the app, then click the monochrome network icon in the menu bar to see the compact 390-point port browser.

## Requirements

- macOS 14 Sonoma or newer
- Xcode 16 or a compatible recent Xcode release
- The built-in `/usr/sbin/lsof` utility

## Building

1. Clone or copy this repository.
2. Open `ArtisanPortManager.xcodeproj` in Xcode.
3. Select the **ArtisanPortManager** scheme and **My Mac**.
4. Build and run (`⌘R`).
5. Click the network icon that appears in the menu bar.

Command-line build:

```bash
xcodebuild -project ArtisanPortManager.xcodeproj \
  -scheme ArtisanPortManager \
  -configuration Debug \
  -derivedDataPath .build/XcodeDerivedData \
  build
```

For a fast compiler check without creating an app bundle, the repository also supports `swift build`.

## Running

The app is an agent application (`LSUIElement = true`), so it intentionally has no Dock icon or ordinary main window. Opening the menu shows cached results immediately and begins refreshes at the configured interval. Settings are available from the menu footer.

## Architecture

- `AppState` is `@MainActor`-isolated and owns view-facing state and orchestration. `ObservableObject` is used for broad compatibility with the macOS 14 SwiftUI lifecycle and straightforward dependency injection.
- `PortScanner` coordinates field-oriented parsing and batched process inspection behind `PortScanning`.
- `ProcessInspector` performs one `ps` and one CWD-focused `lsof` invocation for all PIDs in a scan.
- `ProcessController` uses injectable inspection/signaling protocols so safety and signal behavior can be tested without killing real processes.
- SwiftUI views contain presentation logic only; system actions live in services.

## How Port Discovery Works

The scanner runs macOS `lsof` directly with an argument array:

```text
/usr/sbin/lsof -nP -iTCP -sTCP:LISTEN -FpcuPnT
```

The `-F` mode is machine-oriented and avoids parsing the human table. `LsofParser` understands IPv4, bracketed IPv6, loopback, and wildcard endpoints. Results are deterministically deduplicated by PID, port, and address family; the same process still gets a separate row for each port. Metadata is enriched in batches to avoid launching commands per row. No process-derived string is ever evaluated by a shell.

## Process Termination

Terminate sends `SIGTERM`, allowing a process to clean up. Force Kill is a distinct, explicitly confirmed action that sends `SIGKILL`. Before either signal, the app checks that the PID exists and that its current executable still matches the selected scan record. The app excludes its own PID and refuses self-termination at the controller layer as defense in depth.

## Permissions and Sandbox

The Xcode target intentionally disables App Sandbox. A sandboxed app cannot reliably inspect unrelated local processes or signal developer tools, which are the core product functions. The app never invokes `sudo`, prompts for a password, or attempts privilege escalation. macOS will return permission errors for processes the current user cannot control, and the UI reports them clearly.

Direct distribution should use Developer ID signing and notarization. The bundle structure is suitable for a future notarized ZIP/DMG or Homebrew Cask; signing credentials and packaging are intentionally not part of the repository.

## Testing

The Xcode test target covers:

- IPv4, IPv6, wildcard, malformed, duplicate, and multi-port `lsof` records
- Search matching and metadata/project formatting
- SIGTERM, SIGKILL, PID identity changes, and permission failures using fake signalers

Run:

```bash
xcodebuild -project ArtisanPortManager.xcodeproj \
  -scheme ArtisanPortManager \
  -destination 'platform=macOS' \
  test
```

`Diagnostics/IntegrationDiagnostic.swift` is a source-level integration diagnostic. It starts an owned Python listener on port 48765, confirms the scanner sees it, terminates it through `ProcessController`, and confirms it disappears. It is intentionally outside the normal test suite so normal tests never depend on system port state.

## Known Limitations

- Processes owned by other users may expose limited metadata and cannot be terminated without appropriate OS permission.
- Docker Desktop may show its proxy process rather than container-level metadata.
- “Open in Browser” always uses `http://localhost:<port>`; protocol probing is deliberately omitted.
- Launch at Login registration is available only from a properly bundled application.
- Port discovery depends on the system `lsof` output contract.

## Future Improvements

- Signed/notarized release automation and DMG packaging
- Optional Docker container enrichment
- Friendly aliases, favorites, and port occupancy notifications
- HTTP/HTTPS reachability detection

# Artisan Port Manager

Artisan Port Manager is a lightweight, native macOS menu-bar utility for finding and managing listening TCP ports. It is built with Swift, SwiftUI, and small amounts of AppKit for system integrations—no web runtime or third-party dependencies.

## Features

### Discovering ports

- Live, ascending list of TCP listeners with port, process, PID, user, address family, command, executable, working directory, and inferred project name
- Instant search across ports, PIDs, process names, projects, commands, users, addresses, working directories, and aliases
- Manual refresh (`⌘R`) and configurable auto-refresh while the menu UI is active

### Grouping multi-port processes

A single process often listens on several ports — an editor's language-server host can
hold four at once. Those are distinct listeners rather than duplicates, so the app groups
them under their owning process instead of hiding any of them:

- A process with more than one port collapses into a single row showing a port summary
  (`40973, 47821, 47822, 50561`, capped with `+N more`) and a port-count badge
- Expanding reveals every port with its own detail view and terminate control
- Processes with one port are displayed exactly as before
- Genuine duplicates — the same PID *and* port reported twice, including parallel IPv4/IPv6
  sockets — are collapsed during parsing

### Aliases and favorites

- Rename any port to something meaningful — "Artisan DB" rather than `5432` — from the row
  context menu or the detail view. The alias becomes the row's label and the process name
  moves to the caption
- Pin the ports you check constantly; favorites sort to the top of the list with a star
- Both are keyed by port **and executable path** rather than PID, so they survive server
  restarts. Lookup falls back to a port-only key when the executable cannot be resolved
- Aliases are searchable alongside every other field

### Reachability

A socket in `lsof` only proves something is bound to a port. Probing reports what it
actually answers:

| Indicator | Meaning |
| --- | --- |
| Green + globe | Serving HTTP or HTTPS, with the status code it returned |
| Blue | Accepts TCP but does not speak HTTP — a database, for example |
| Orange | Holding the socket but refusing connections |
| Grey | Probe in flight |

- Open and Copy URL use the discovered scheme, so an HTTPS-only dev server opens correctly
  instead of failing on `http://`
- A Reachability row in the detail view shows the full status and offers a re-check
- **Check Reachability** in the row context menu probes a single port on demand
- Probing is on by default and can be disabled entirely in Settings

### Acting on ports

- Native browser, clipboard, and Finder actions, opening each port with the scheme it actually serves
- Safe process control: PID identity revalidation, SIGTERM by default, separately confirmed SIGKILL, self-process protection, duplicate-signal prevention, and clear permission errors
- Termination confirmations state what is actually released: signals target a PID, so a
  multi-port process loses every listener, and the dialog names them
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
- `ReachabilityProber` sits behind `ReachabilityProbing` so probe outcomes can be faked in tests without touching the network.
- `PortBookmarkStore` persists aliases and favorites in `UserDefaults`, injectable with a custom suite so tests never touch real user preferences.
- SwiftUI views contain presentation logic only; system actions live in services.

Every external dependency — command execution, process inspection, signalling, probing,
and preference storage — is reached through a protocol with an injectable implementation.
That is what keeps the test suite free of system state.

### Key types

| Type | Responsibility |
| --- | --- |
| `ListeningPort` | One listening socket and its enriched process metadata |
| `PortGroup` | Ports clustered by owning PID, for the collapsible list rows |
| `PortIdentity` | Restart-stable key (port + executable) for aliases and favorites |
| `PortReachability` | What a port answers: HTTP/HTTPS, TCP-only, unreachable, or unknown |
| `ProcessMetadata` | `ps`-derived parent PID, user, executable, command, and working directory |

## How Port Discovery Works

The scanner runs macOS `lsof` directly with an argument array:

```text
/usr/sbin/lsof -nP -iTCP -sTCP:LISTEN -FpcuPnT
```

The `-F` mode is machine-oriented and avoids parsing the human table. `LsofParser` understands IPv4, bracketed IPv6, loopback, and wildcard endpoints. Parallel IPv4 and IPv6 sockets owned by the same PID on the same port are collapsed into one logical row; different processes and different ports remain distinct. Metadata is enriched in batches to avoid launching commands per row. No process-derived string is ever evaluated by a shell.

Two distinctions matter when reading this code:

- **Duplicates are collapsed; multiple ports are not.** The same PID *and* port appearing
  twice — multiple file descriptors, or parallel IPv4/IPv6 sockets — is one listener
  reported repeatedly, so the parser keeps a single preferred representative. The same PID
  on *different* ports is several real listeners, so `PortGroup` clusters them for display
  while every port stays individually reachable.
- **Parser state is cleared per record.** `lsof -F` emits a `p` record followed by fields
  that inherit from it. Cached command, user, and PID are all reset on each new `p` record,
  because a stale PID surviving a malformed record would attribute a socket to the wrong
  process — and this app signals by PID.

## How Reachability Probing Works

After each scan, every visible port is probed concurrently on loopback:

1. **HTTP** — a `HEAD` request to `http://127.0.0.1:<port>/`. Any status counts as success,
   including `4xx` and `5xx`: an error response still proves a web server is answering.
2. **HTTPS** — the same request over TLS if HTTP did not answer. Self-signed certificates
   are accepted, but the trust delegate checks the host explicitly and the prober only ever
   contacts `127.0.0.1`.
3. **Raw TCP** — an `NWConnection` attempt if neither spoke HTTP. This is what separates a
   database from a process holding a socket while refusing connections.

Each attempt uses a short timeout (1.5s by default), since a healthy loopback server
answers in milliseconds. Responses are never served from cache. Results are keyed by port
and retained across refreshes so rows do not flicker back to unknown on every scan; entries
for ports that stop listening are dropped so the cache cannot grow unbounded during a long
session. Probing can be disabled in Settings, which clears the cache.

## Process Termination

Terminate sends `SIGTERM`, allowing a process to clean up. Force Kill is a distinct, explicitly confirmed action that sends `SIGKILL`. Before either signal, the app checks that the PID exists and that its current executable still matches the selected scan record. The app excludes its own PID and refuses self-termination at the controller layer as defense in depth.

Signals target a **process**, not a port. A process listening on several ports loses every
listener when terminated, so the confirmation dialog says so explicitly and names the ports
being released rather than citing only the row that was clicked.

## Settings and Persistence

| Setting | Default | Effect |
| --- | --- | --- |
| Auto Refresh | On | Rescans while the menu is open |
| Refresh Interval | 3 seconds | 1, 3, 5, 10, or 30 seconds |
| Show Other Users' Processes | Off | Includes listeners owned by other users |
| Check Port Reachability | On | Probes each port; disabling clears cached results |
| Launch at Login | Off | Registers the app via `SMAppService` |

Settings, aliases, and favorites are stored in `UserDefaults`. Bookmarks are keyed by
`PortIdentity` — port plus executable path — so they survive PID churn across restarts.
`PortBookmarkStore` accepts an injected `UserDefaults` suite, which is how the tests exercise
persistence without touching real preferences.

## Permissions and Sandbox

The Xcode target intentionally disables App Sandbox. A sandboxed app cannot reliably inspect unrelated local processes or signal developer tools, which are the core product functions. The app never invokes `sudo`, prompts for a password, or attempts privilege escalation. macOS will return permission errors for processes the current user cannot control, and the UI reports them clearly.

Direct distribution should use Developer ID signing and notarization. The bundle structure is suitable for a future notarized ZIP/DMG or Homebrew Cask; signing credentials and packaging are intentionally not part of the repository.

## Testing

The Xcode test target contains **36 tests** across six suites, none of which depend on
system port state or real user preferences:

| Suite | Covers |
| --- | --- |
| `LsofParserTests` | IPv4, IPv6, wildcard, malformed, duplicate, and multi-port records; the stale-PID regression |
| `PortGroupingTests` | Clustering by PID, ordering, port-summary truncation, and the guarantee that grouping never drops a listener |
| `BookmarkTests` | Alias round-tripping, trimming, executable scoping, restart survival, favorite toggling, and alias search |
| `ReachabilityTests` | Scheme selection, HTTP fallback, status labels, and probes against a real bound socket |
| `FilteringTests` | Search matching and metadata/project formatting |
| `ProcessControllerTests` | SIGTERM, SIGKILL, PID identity changes, and permission failures using fake signalers |

`TCPTestListener` binds an ephemeral loopback port that accepts connections but never
answers HTTP, which is how the `.tcpOnly` and `.unreachable` probe paths are verified
without depending on anything already running on the machine.

Run:

```bash
xcodebuild -project ArtisanPortManager.xcodeproj \
  -scheme ArtisanPortManager \
  -destination 'platform=macOS' \
  test
```

`Diagnostics/IntegrationDiagnostic.swift` is a source-level integration diagnostic. It starts an owned Python listener on port 48765, confirms the scanner sees it, terminates it through `ProcessController`, and confirms it disappears. It is intentionally outside the normal test suite so normal tests never depend on system port state.

## Versioning and Changelog

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Notable
changes for each release are recorded in [CHANGELOG.md](CHANGELOG.md), which follows the
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

Every user-facing change ships with a changelog entry and a version bump in the same
commit. Releases are tagged `vMAJOR.MINOR.PATCH` and published on the
[Releases page](https://github.com/david-mogbeyi/artisan-port-manager/releases). The
version lives in three places that must not drift: `CFBundleShortVersionString` and
`CFBundleVersion` in `Info.plist`, and `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in
both the Debug and Release build configurations. [CLAUDE.md](CLAUDE.md) documents the full
process.

| Version | Highlights |
| --- | --- |
| 1.3.0 | Reachability probing; Open uses the scheme a port actually serves |
| 1.2.0 | Port aliases and favorites |
| 1.1.0 | Multi-port process grouping; detail view layout fix; stale-PID parser fix |
| 1.0.0 | Initial release |

## Known Limitations

- Processes owned by other users may expose limited metadata and cannot be terminated without appropriate OS permission.
- Docker Desktop may show its proxy process rather than container-level metadata.
- Reachability probing only inspects loopback (`127.0.0.1`) and accepts self-signed certificates there.
- Launch at Login registration is available only from a properly bundled application.
- Port discovery depends on the system `lsof` output contract.

## Future Improvements

- Signed/notarized release automation and DMG packaging
- Optional Docker container enrichment
- Port occupancy notifications

# Changelog

All notable changes to Artisan Port Manager are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-08-19

Ports can now be named and pinned, turning the list from a system readout into a
personal dashboard.

### Added

- **Port aliases.** Rename any port to something meaningful — "Artisan DB" instead of
  `5432` — from the row's context menu or the detail view. The alias becomes the row's
  primary label and the process name moves to the caption, so nothing is lost. Aliases are
  keyed by port and executable rather than PID, so they survive server restarts.
- **Favorites.** Pin the ports you check constantly and they sort to the top of the list,
  marked with a star. Ordering within the pinned and unpinned bands is otherwise unchanged.
- Aliases are searchable alongside ports, PIDs, process names, projects, commands, users,
  and working directories.
- Rename sheet reachable from the list context menu and the detail view's More menu, with
  a Remove Alias action when one is already set.

## [1.1.0] - 2026-08-18

Focused on the port list and detail views: a process that listens on many ports no
longer floods the list, and the detail screen now fits the popover.

### Added

- **Grouped multi-port processes.** A process listening on several ports is now a single
  collapsible row showing a port summary (`40973, 47821, 47822, 50561`) and a port-count
  badge, instead of one near-identical row per port. Expanding reveals every port with its
  own detail navigation and terminate control, so no listener is hidden. Processes with a
  single port are unchanged.
- **Group context menu** with Expand/Collapse Ports, Copy All Ports, Copy PID, Reveal
  Project in Finder, and process-level Terminate / Force Kill.
- Unit tests covering grouping, ordering, port-summary truncation, and the guarantee that
  grouping never drops a listener.

### Fixed

- **Port detail view no longer overflows the popover.** The window size was applied to the
  `NavigationStack`'s root content rather than the stack itself, so pushing the detail view
  left it without geometry — content was clipped on the right and pushed below the visible
  area. The frame now sits on the `NavigationStack`, giving every screen in the flow the
  same fixed size.
- Detail-view quick actions ("Open", "Copy URL", "More") wrap gracefully instead of running
  off the right edge, and long process names truncate rather than squeezing the header.
- **Sockets could be attributed to the wrong process.** The `lsof` parser reset the cached
  command and user on each `p` record but never the PID itself, so a malformed PID line
  left the previous process's PID in scope for the next socket. Because termination targets
  a PID, this could have signalled the wrong process. Covered by a regression test.

### Changed

- Termination confirmation now reflects that signals target the whole process: killing a
  multi-port process reads "Terminate <name> and its 4 ports?" and names the ports being
  released, rather than citing only the clicked port.

## [1.0.0] - 2026-08-17

### Added

- Menu bar app listing TCP listeners with process name, PID, project, and address.
- Search across port, PID, process name, project, command, working directory, and user.
- Port detail view with quick actions, process metadata, and copy helpers.
- Terminate (SIGTERM) and Force Kill (SIGKILL) with confirmation and PID-identity checks.
- Settings for auto-refresh, refresh interval, showing system processes, and launch at login.

### Fixed

- Collapsed duplicate rows for the same process and port, including parallel IPv4/IPv6
  sockets and repeated file descriptors for one listener.

[Unreleased]: https://github.com/david-mogbeyi/artisan-port-manager/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/david-mogbeyi/artisan-port-manager/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/david-mogbeyi/artisan-port-manager/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/david-mogbeyi/artisan-port-manager/releases/tag/v1.0.0

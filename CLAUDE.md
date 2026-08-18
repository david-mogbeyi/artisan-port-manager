# Artisan Port Manager — working conventions

Native macOS menu-bar app (Swift, SwiftUI, small amounts of AppKit). No third-party
dependencies. Source-only repository; build artifacts are gitignored.

## Every user-facing change ships with a changelog entry and a version bump

This is not optional and does not need to be requested. If a change alters behaviour,
appearance, or the public surface of the app, the same commit must also update
`CHANGELOG.md` and the version. Do this as part of the work, before proposing the commit.

### 1. Bump the version

The project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html):

- **MAJOR** — incompatible or removed behaviour users relied on.
- **MINOR** — a new user-facing capability, added backwards-compatibly.
- **PATCH** — a bug fix or internal correction with no new capability.

When a release mixes categories, the highest one wins: a release containing both a new
feature and bug fixes is a MINOR bump, not a PATCH.

The version lives in **three** places and they must not drift. Update all of them:

| Location | Keys |
| --- | --- |
| `ArtisanPortManager/Info.plist` | `CFBundleShortVersionString`, `CFBundleVersion` |
| `ArtisanPortManager.xcodeproj/project.pbxproj` — **Debug** config | `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` |
| `ArtisanPortManager.xcodeproj/project.pbxproj` — **Release** config | `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` |

`CFBundleShortVersionString` and `MARKETING_VERSION` carry the semver string (`1.1.0`).
`CFBundleVersion` and `CURRENT_PROJECT_VERSION` carry the build number, which increments
by one on every release and never resets.

Run `plutil -lint` on both files after editing — the pbxproj is hand-maintained and easy
to corrupt.

### 2. Write the changelog entry

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Add a new
version section above the previous one, dated `YYYY-MM-DD`, grouping entries under
`Added`, `Changed`, `Fixed`, `Removed`, `Deprecated`, or `Security`.

Write entries for someone deciding whether to upgrade, not for someone reading the diff:

- Say what changed for the user and, for fixes, what the wrong behaviour was. Name the
  cause when it explains the symptom.
- Do not enumerate touched files, function names, or refactors with no observable effect.
- Call out anything that changes the meaning of a destructive action.

Update the link definitions at the bottom of the file: point `[Unreleased]` at the new
version and add a compare link for it.

### 3. Tag the release

Releases are tagged `vMAJOR.MINOR.PATCH` with an annotated tag (`git tag -a`) on the
commit that lands on `main`. Push tags explicitly — `git push` alone does not send them.
The changelog's compare links depend on these tags existing.

### Changes that do not need this

Skip the version bump and changelog for work with no user-visible effect: editing this
file or the README, comment-only or formatting changes, and test-only changes that do not
accompany a behaviour change. When unsure, add the entry — a redundant line is cheaper
than a silent behaviour change.

## Before proposing a commit

- `xcodebuild -project ArtisanPortManager.xcodeproj -scheme ArtisanPortManager -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO test` passes.
- New behaviour has tests. The parser, filtering, grouping, and process-control layers are
  all covered by pure unit tests with no system dependencies — keep them that way.
- `main` is the default branch. Land work through a branch and a PR rather than committing
  to `main` directly.

## Domain constraints worth knowing

- **Termination targets a PID, not a port.** A process listening on several ports loses
  every listener when signalled. Any UI that offers termination must say so.
- **Multiple ports on one PID are not duplicates.** `lsof` reports one row per socket. Real
  duplicates are the same PID *and* port appearing twice (multiple file descriptors, or
  parallel IPv4/IPv6 sockets); those are collapsed in `LsofParser`. Distinct ports on one
  process are distinct listeners and must stay individually reachable — see `PortGroup`.
- **Be careful with PID handling in the parser.** State cached across `lsof` records must be
  cleared on each new record; a stale PID means signalling the wrong process.
- The app is a `MenuBarExtra` with `.menuBarExtraStyle(.window)`. The popover takes its size
  from the content's ideal size, so the frame belongs on the `NavigationStack` — putting it
  on a child leaves pushed views without geometry.

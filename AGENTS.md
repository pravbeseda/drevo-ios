# AGENTS.md

Guidance for coding agents in this repository. Claude Code loads it through `CLAUDE.md`.

## Project

`drevo-ios` is the iPhone and iPad client of the offline Orthodox encyclopedia reader «Древо» (`ru.drevoinfo`), a port of
[drevo-android](https://github.com/pravbeseda/drevo-android). Articles come from two read-only SQLite databases built by
`pravbeseda/drevo-db`, whose `docs/format.md` is the format contract. The plan and every design decision live in
`.github/tasks/ios-port.md`; read its "Decisions" table before changing the architecture. UI text is Russian; everything
written into the repository is English.

## Layout

- `DrevoKit/` — a Swift package, the testable core: database access, article assembly, queries, and the `@Observable`
  models the views bind to. It imports neither UIKit nor SwiftUI, and builds for macOS too so that `swift test` runs on
  the host.
- `Drevo/` — the app target: SwiftUI views, the `WKWebView` bridge and resources. Views hold no logic; a decision a view
  would make belongs in a model in `DrevoKit`, with a test.
- `DrevoUITests/` — XCUITest, run on iPhone and iPad simulators over the databases `db.lock` pins, so their titles
  are stable.
- `Drevo/Resources/Web/` — the article page's stylesheets and scripts, copied from drevo-android's
  `drevo/src/main/assets/`. The build copies every resource flat into the bundle root, which is the page's base URL.
- `Drevo.xcodeproj` uses folder-synchronized groups: a file added under `Drevo/` or `DrevoUITests/` is in its target
  with no project edit. `project.pbxproj` changes only for build settings, phases and targets.

The layout follows the horizontal size class, never the device idiom: an unfolded iPhone Duo, an iPad in Split View and
a rotated phone are the same event to the app.

## Databases

The app bundles the drevo-db release that `db.lock` pins: `main` and `patch` under the constant names `main.sqlite` and
`patch.sqlite` in `Drevo/Resources/Database/`, git-ignored. **Run `scripts/fetch-db.sh` once after a clone and after
every `db.lock` change**; it downloads only what is missing or stale and checks each file against its SHA-256 in
`db.lock`. The app target's first build phase runs it with `--check`, which never downloads: a missing or stale file
fails the build with that instruction. A new database is a `db.lock` change — the release tag, the release holding
`main`, and both hashes from that release's `SHA256SUMS` — followed by a fetch. The symlink
`Drevo/Resources/db.lock` bundles the file itself, so the About screen names the release.

`DrevoKit`'s tests run on drevo-db's reference build, copied into `DrevoKit/Tests/DrevoKitTests/Fixtures/` with a
README naming the drevo-db commit; copy it again whenever drevo-db's fixtures change. `FormatFixturesTests` assembles
every article there and compares it byte for byte with `expected/`.
`BundledDatabaseTests` is the release gate drevo-db's `docs/format.md` asks for: on the databases `db.lock` pins it
checks the format version (`FormatVersion`) and assembles every article. It runs only when `DREVO_DATABASE_DIR` is
set, which CI does after fetching; run it after every `db.lock` change.

## Build & test

```bash
swift test --package-path DrevoKit -Xswiftc -warnings-as-errors   # the core, on the host, in seconds
scripts/swift-format.sh lint                                      # formatting, as CI and the pre-commit hook check it
scripts/swift-format.sh format                                    # format every tracked Swift file in place
scripts/tests/fetch-db-test.sh                                    # scripts/fetch-db.sh against a fake gh
DREVO_DATABASE_DIR=$PWD/Drevo/Resources/Database \
  swift test --package-path DrevoKit -c release --filter BundledDatabaseTests   # the pinned databases, as CI checks them
```

The app's build and UI tests run through `xcodebuild test -scheme Drevo`; the exact command and simulator destinations
are in `.github/workflows/ci.yml`. Locally Xcode 27 is used; CI pins Xcode 26.6 in that workflow, so the project and
package stay buildable by both. The package declares `swift-tools-version: 6.2`.

The iPhone Duo simulator (iOS 27.1 runtime) runs only locally. Run the UI tests on it twice, folded and unfolded: its
pose is set in Device Hub, since neither `simctl` nor XCUITest can fold it, and stays set between runs.

**Formatting is owned by swift-format** (the one shipped with Xcode, config in `.swift-format`): run the format script
rather than formatting by hand.

**No dependencies beyond the system SDK** (decision 6): SQLite through `SQLite3`, zlib through `Compression`.

## Test-first rules

1. **A bug is fixed through a failing test**: reproduce it, watch the test fail, then fix it.
2. **New logic in `DrevoKit` is written test-first**: red → green → refactor. Tests use Swift Testing (`import Testing`,
   `@Test`, `#expect`); XCTest only in `DrevoUITests`, where XCUITest requires it.

Seams are built into the code under test: no mocking library. **No mutable global state** — no `static var`, no
singletons; a database or a model is created once and passed in.

## Never weaken a check

Warnings are errors in the Xcode project (`SWIFT_TREAT_WARNINGS_AS_ERRORS`, `GCC_TREAT_WARNINGS_AS_ERRORS`) and in the
package through the `swift test` command above (`Package.swift` says why it is not a package setting). Swift 6 language
mode makes concurrency checking complete, and swift-format runs with `--strict`. Fix a finding; never silence it — no new `@preconcurrency`, `nonisolated(unsafe)`,
`@unchecked Sendable`, skipped or disabled test, or relaxed setting without explicit permission.

## Commits

`.githooks/pre-commit` refuses a commit on `main`, scans the staged change with `gitleaks` and runs the swift-format lint.
Point each checkout at it once: `git config core.hooksPath .githooks`. `gitleaks` must be on `PATH`
(`brew install gitleaks`); when it is missing the hook fails rather than skipping the scan.

## Continuous integration

`.github/workflows/ci.yml` runs on pull requests against `main`, pushes to `main` and `workflow_dispatch`:

- `checks` — formatting, `swift test`, the `fetch-db.sh` test, the databases (cached by `db.lock`'s hash),
  `BundledDatabaseTests` on them, and `xcodebuild test` on an iPhone and an iPad simulator, on macOS.
- `secret-scan` — `gitleaks` over the whole history.

Dependency updates arrive through Renovate (`renovate.json5`, extending
[`pravbeseda/renovate-config`](https://github.com/pravbeseda/renovate-config)); each rule departing from the preset
carries its reason.

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
- `DrevoUITests/` — XCUITest, run on iPhone and iPad simulators.
- `Drevo.xcodeproj` uses folder-synchronized groups: a file added under `Drevo/` or `DrevoUITests/` is in its target
  with no project edit. `project.pbxproj` changes only for build settings, phases and targets.

The layout follows the horizontal size class, never the device idiom: an unfolded iPhone Duo, an iPad in Split View and
a rotated phone are the same event to the app.

## Build & test

```bash
swift test --package-path DrevoKit      # the core, on the host, in seconds
scripts/swift-format.sh lint            # formatting, as CI and the pre-commit hook check it
scripts/swift-format.sh format          # format every tracked Swift file in place
```

The app's build and UI tests run through `xcodebuild test -scheme Drevo`; the exact command and simulator destinations
are in `.github/workflows/ci.yml`. Locally Xcode 27 is used; CI pins Xcode 26.6 in that workflow, so the project and
package stay buildable by both. The package declares `swift-tools-version: 6.2`.

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

Warnings are errors in both the Xcode project (`SWIFT_TREAT_WARNINGS_AS_ERRORS`, `GCC_TREAT_WARNINGS_AS_ERRORS`) and the
package (`.treatAllWarnings(as: .error)`), Swift 6 language mode makes concurrency checking complete, and swift-format
runs with `--strict`. Fix a finding; never silence it — no new `@preconcurrency`, `nonisolated(unsafe)`,
`@unchecked Sendable`, skipped or disabled test, or relaxed setting without explicit permission.

## Commits

`.githooks/pre-commit` refuses a commit on `main`, scans the staged change with `gitleaks` and runs the swift-format lint.
Point each checkout at it once: `git config core.hooksPath .githooks`. `gitleaks` must be on `PATH`
(`brew install gitleaks`); when it is missing the hook fails rather than skipping the scan.

## Continuous integration

`.github/workflows/ci.yml` runs on pull requests against `main`, pushes to `main` and `workflow_dispatch`:

- `checks` — formatting, `swift test`, and `xcodebuild test` on an iPhone and an iPad simulator, on macOS.
- `secret-scan` — `gitleaks` over the whole history.

Dependency updates arrive through Renovate (`renovate.json5`, extending
[`pravbeseda/renovate-config`](https://github.com/pravbeseda/renovate-config)); each rule departing from the preset
carries its reason.

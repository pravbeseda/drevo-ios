# iOS/iPadOS port and the database contract

Bring the offline reader to iPhone and iPad, and turn the link between the database generator
(`pravbeseda/drevo-db`) and its clients from "files in a local folder" into an explicit, tested contract.
Three repositories are involved: drevo-db, drevo-android and drevo-ios (this one). Phases 1–4 were done
in drevo-db and drevo-android; this plan moved here from drevo-android's `.github/tasks/` when phase 5 started.

## Decisions

| # | Decision | Why |
|---|----------|-----|
| 0 | Separate iOS repository; one universal app for iPhone and iPad | Xcode/SPM, macOS CI and App Store Connect share nothing with the Gradle gates here; `NavigationSplitView` covers both form factors |
| 1 | The iOS bundle ships the same `main` + `patch` pair; `TextPatcher` is ported to Swift | Same artifact for both platforms, drevo-db unchanged, offline from the first launch, and an update re-downloads only the ~17 MB patch file, since App Store updates ship the files that changed |
| 2 | The format contract lives in drevo-db: `docs/format.md`, reference fixtures, `PRAGMA user_version` | The producer owns the format; both clients test against the same fixtures, so a format change fails a test instead of a user |
| 3 | Built databases are published as GitHub Releases of drevo-db; each app pins a version and verifies SHA-256 | The iOS bundle needs the exact files at build time on any machine and in CI; git and Git LFS cannot hold 318 MB per version |
| 4 | drevo-db moves to Gradle with JUnit, CI and a fixture task; the database itself is still built locally by `make.sh` | The contract owner needs tests and a build that works from a fresh clone; a scheduled CI build can be added on top later |
| 5 | Minimum iOS 17, SwiftUI with `@Observable` | iPhone XS/XR and newer; iOS 16 adds only iPhone 8/X at the cost of the old observation model |
| 6 | System `SQLite3` behind a thin in-house wrapper, no dependency | Six to eight queries and one writable table do not justify GRDB; the wrapper is one replaceable place |
| 7 | New code in drevo-db is Kotlin; phase 1 rewrote `MakeDB3` in Kotlin whole | The rule drevo-android keeps for new files; the live generator was ~280 lines, and comparing `sqlite3 .dump` output against the old build proves the rewrite |
| 8 | Two-column `NavigationSplitView` (word list, article). The list's title is its filter menu (`toolbarTitleMenu`): «Все статьи» for all articles, the topic name («Святые») or «Закладки». Special pages and settings sit in a "⋯" menu, over the list on a compact width and over the article on a regular one | One navigation mechanism; the Android drawer is not an iOS idiom, and a three-column split or a tab bar adds a second axis of transitions for little gain |
| 9 | The layout follows the horizontal size class, never the device idiom; the selected article, history, anchor and scroll position live in models, not in the web view | Unfolding an iPhone Duo, iPad Split View / Stage Manager and rotation are the same event to the app, and each may recreate the web view |
| 10 | `@Observable` models live in a package target and are tested by `swift test`; Swift 6 language mode, Swift Testing, warnings as errors | "Views hold no logic" needs a testable home for the logic; `Observation` is not SwiftUI; a gate, not a report, as in drevo-android |
| 11 | The Xcode build phase only verifies the database files and fails with a hint to run `scripts/fetch-db.sh`; CI caches them by `db.lock`; the UI tests run on those pinned files | A build that downloads is non-hermetic, fights Xcode's script sandboxing and fires on previews and indexing; every build bundles the pinned files anyway, and the pin keeps the titles the tests look for fixed |
| 12 | Russian development region with a String Catalog; text size follows Dynamic Type; find in page through `WKWebView.isFindInteractionEnabled` | System controls appear in Russian; platform behaviour for free |
| 13 | A plain `Drevo.xcodeproj` in git with folder-synchronized groups; no XcodeGen or Tuist | Logic lives in the package, so the project holds one thin target; synchronized folders keep file additions out of `project.pbxproj`, and no tool has to run after a clone or in CI |
| 14 | `pravbeseda/drevo-ios` is a public GitHub repository | Public repositories run macOS jobs free, so CI can test iPhone and iPad, and the iPhone Duo once its runner has Xcode 27; the client holds no secret. drevo-db became public too, so CI downloads its releases with the workflow's own token and no PAT exists |
| 15 | Bundle identifier `ru.drevoinfo`, display name «Древо» | The same identifier as the Android package; it is fixed only when the App Store Connect record is created, so a clash found then costs nothing |
| 16 | Themes: system (default) / light / dark; dark is `styleblack.css` over the system dark appearance | Android's dark and black differ only in the chrome's grey, and iOS dark mode is already black; a custom grey palette would not reach system menus and sheets |
| 17 | The `@Observable` models live in the `DrevoKit` target itself; a `Library` actor owns the databases and does their work off the main actor | The models are the core's only consumer, so its types stay internal and the public API is what the views need; a second consumer (a widget) is the moment to split targets |

## Current state

```
drevo-info.ru/drevo2.tar.gz → DB/download.sh → DB/drevo.txt → drevo-db (Kotlin) → main.<N>.obb + patch.<M>.obb
    → ~/Work/drevo/drevo-db/DB → release-new-db.sh (drevo-android) → ~/Yandex.Disk.localized/Drevo/<version> → Play Console
```

- `main` is 318 MB and changes rarely; `patch` is 10–17 MB and is rebuilt monthly.
- The format exists only as code: drevo-db's `ArticleRecord` / `TextChange` / `ZipText` / `Main.kt` write it,
  `DB.java` / `ArticleReader` / `ArticleAssembler` / `Article` read it.
- Since phase 1, drevo-db builds from a fresh clone with Gradle, has unit tests and CI; its output is unchanged from
  the Java generator it replaced (same `sqlite3 .dump`).
- The databases carry no format version (`user_version` is `0`).

Format facts the contract has to record (taken from drevo-db, `Article.java`, `SlovnikActivity.java`):

- `patch`: `tblSlovnik(_id INTEGER, title TEXT PRIMARY KEY)`, `tblTopics(article_id, topic)`,
  `tblTexts(_id INTEGER PRIMARY KEY, ziptext BLOB, isfulltext)`; indexes `id` and `title` on `tblSlovnik`.
- `main`: `tblTexts` only.
- `ziptext` is a zlib stream (RFC 1950: 2-byte header, deflate data, Adler-32 trailer; `DeflaterOutputStream`) of
  UTF-8 text. In `patch`, `isfulltext = 1` is a full text, `0` is a javaxdelta text delta against
  the `main` row of the same `_id`; no `patch` row means the `main` text is unchanged.
- Text is `<toc> <drevo> <body>`. The TOC is `#`-separated `anchor|title` entries; an anchor starting with `_` is a
  nested entry; the title `Начало статьи` stands for the article title.
- Topic `99` ("all articles") is added unless the article has a topic `>= 13`; article `4` (main page) is always in `99`
  and its title is stored with a leading space so it sorts first (to be removed: pravbeseda/drevo-db#2).
- Special article ids: `1` about the site, `2` calendar, `3` chronology, `4` main page. "Today" / "tomorrow" are looked up
  by the title `<day> <month>` shifted by −13 / −12 days (`MyUtils.getDayTitle`).
- A delta of 40 % of the new text's length or more is stored as the full text instead.
- Both files are written with a page size of 1024 bytes; the driver's default of 4096 makes `main` ~11 MB larger.
- javaxdelta offsets count UTF-16 code units (`CharBuffer`). The Swift port must patch over `utf16`, never over
  `String.Index` / grapheme clusters.

## Target architecture

```
drevo-db ──(GitHub Release db-<main>-<patch>: main, patch, stat.txt, SHA256SUMS)──┬──▶ drevo-android  (pinned in strings.xml)
     │                                                                                └──▶ drevo-ios  (pinned in db.lock)
     └──(fixtures/ + docs/format.md, copied into each client's tests)──────────────────────▶ both clients' test suites
```

## Phase 1 — drevo-db foundation (done: pravbeseda/drevo-db#3)

Branch in drevo-db; one PR.

1. Gradle wrapper, `gradle/libs.versions.toml`, `application` plugin running `MakeDB3`; javaxdelta and a current
   `sqlite-jdbc` from Maven Central; delete `lib/` and the `*.jar` workaround.
2. Track `DB/download.sh` (narrow the `DB/*` ignore to the generated files); `make.sh` calls Gradle instead of `javac`.
3. Delete `MakeDB.java`, `MakeDB2.java`, `MyDiff.java`, `make.bat`, `make2.sh`, `verify.bat` if nothing calls them
   (check `VerifyDiff` first: keep it if it is still the manual verification step).
4. Split `MakeDB3` so the per-line logic (parse a `<drevo>` line, build the TOC string, decide patch vs. full text)
   is a plain class with no JDBC, and test it test-first with JUnit.
5. GitHub Actions: build and tests on pull requests and on `main`; `renovate.json5` extending `pravbeseda/renovate-config`;
   `AGENTS.md` + `CLAUDE.md` stub.

Verify: a fresh clone runs `./gradlew test`, and `make.sh patch` on the real export produces a patch whose
`sqlite3 .dump` matches the one from the old `javac` build.

## Phase 2 — the format contract (done: pravbeseda/drevo-db#4)

1. `docs/format.md`: everything under "Format facts" above, file naming, and the rule that a release names the `main`
   its `patch` was built against.
2. The generator writes `PRAGMA user_version = 1` into both files. Clients treat `0` (every database already
   published) and `1` as format 1, and refuse anything higher with a clear message.
3. `fixtures/source/` holds two tiny exports (`drevo.v1.txt`, `drevo.v2.txt`, 5–10 articles each). A Gradle task builds
   `main` from v1 in `full` mode and `patch` from v2 in `patch` mode, and writes them to `fixtures/` together with
   `expected/<id>.txt`, the assembled text of every article.
4. The fixture set covers: unchanged article (no `patch` row), delta (`isfulltext = 0`), full replacement over the
   40 % threshold, an article new in v2 (no `main` row), article `4` with its leading space, an article with a nested
   TOC, an article excluded from topic `99`, non-BMP characters (UTF-16 surrogate pairs) inside a delta.
5. CI regenerates the fixtures and fails when they differ from the committed ones, comparing `sqlite3 .dump` output,
   not bytes, so an `sqlite-jdbc` bump does not fail it for page-layout reasons.

## Phase 3 — publishing databases (done: pravbeseda/drevo-db#6, first release `db-254-258`)

1. After a successful build `make.sh` asks for confirmation and runs `gh release create db-<main>-<patch>` with the
   `main` file (only when it is new; otherwise the release notes name the earlier release that holds it), the `patch`,
   `stat.txt` and `SHA256SUMS`.
2. Release notes: article count, added / patched percentages (the `Count:` line `make.sh` already logs).
3. The existing Yandex.Disk archive stays as it is.

## Phase 4 — drevo-android (done: pravbeseda/drevo-android#80, item 4 in #81)

Branch here; one PR.

1. Copy `fixtures/` into `drevo/src/test/resources/format/` with a one-line note naming the drevo-db commit it came from.
2. A JVM test drives `ArticleAssembler` over every fixture article and compares with `expected/`. The JVM suite has no
   SQLite, so the fixture task in phase 2 also exports the blobs in a SQLite-free form (`_id`, `isfulltext`, base64
   `main` / `patch` blobs); its exact shape is chosen in phase 2 to be readable from both a JVM test and `swift test`.
3. `release-new-db.sh` refuses an OBB whose `user_version` is newer than the format the app reads. Not a check in
   `DB` on open, as first planned: the OBB names are fixed in the APK, so a release is the only way an unreadable
   database reaches a device, and a message there would leave the user nothing to do.
4. Separate PR: `release-new-db.sh` downloads the newest release and verifies
   `SHA256SUMS` instead of reading `~/Work/drevo/drevo-db/DB`.

## Phase 5 — iOS app (3–5 days to MVP)

### Repository

```
drevo-ios/
  DrevoKit/            Swift package, no UIKit/SwiftUI: the testable core, the counterpart of drevo-android's Android-free classes
  Drevo/               Xcode app target: SwiftUI views and the WKWebView bridge only
  Drevo.xcodeproj
  db.lock              the pinned drevo-db release, the release holding main, SHA-256 of each file
  scripts/fetch-db.sh  downloads the db.lock release, verifies it, places it under Drevo/Resources/Database/
  .github/workflows/   swift test + xcodebuild test on macOS, gitleaks secret scan
  AGENTS.md, CLAUDE.md (stub), renovate.json5
```

The database files are git-ignored and fetched by `scripts/fetch-db.sh`; the Xcode build phase only checks that they
are present (decision 11). In the bundle they keep constant names (`main.sqlite`, `patch.sqlite`), so an update where only the patch
changed leaves `main` byte-identical and outside the download. The pinned versions are shown on the About screen.

Conventions copied from drevo-android: test-first for everything in `DrevoKit`; views hold no logic; no mutable global
state; `swift-format` (shipped with Xcode) as the formatter, checked in CI and in a pre-commit hook together with gitleaks.

### Order of work

One pull request per step, each green before the next.

- [x] 1. Skeleton (pravbeseda/drevo-ios#1): `.gitignore`, `AGENTS.md` + `CLAUDE.md`, `.swift-format`, `.githooks/pre-commit`, `renovate.json5`, CI,
      an empty `DrevoKit` and an app target that build. Deviations from drevo-android: no `decide-work` guard (public
      repository, so skipping a docs-only run saves nothing); the secret scan covers the whole history (no known leak to
      step around) and uses gitleaks' bundled rules alone (no signing secrets live here); a `DrevoUITests` target joins
      the app from the start, since `xcodebuild test` needs a test target and the size-class checks will live there.
      CI pins Xcode 26.6 (the newest on the `macos-26` runner), so the iPhone Duo simulator, which needs Xcode 27, is not
      in CI yet.
- [x] 2. Database pinning (pravbeseda/drevo-ios#2): `db.lock` (`db-254-258`), `scripts/fetch-db.sh` with a shell test against a fake `gh`,
      the verifying build phase, the CI cache. `db.lock` pins the SHA-256 of each file itself rather than trusting the
      release's `SHA256SUMS` at fetch time, and names the release holding `main` instead of searching for it as
      drevo-android's `release-db-fetch.sh` does.
- [x] 3. DrevoKit core (pravbeseda/drevo-ios#3): fixtures, `SQLiteDatabase` / `Statement`, `TextPatcher`, `ArticleAssembler`, `ArticleReader`,
      `FormatVersion`, `Article`, the fixture test. Deviations from drevo-android: `ArticleReader` is tested on the
      fixture databases, since `swift test` has SQLite, rather than on fake cursors; `TocEntry` carries `isNested`
      instead of two leading spaces in its title; `TextPatcher` rejects negative numbers, which javaxdelta's writer
      never produces; a TOC entry is nested only when its anchor starts with `_`, as format.md says, where
      drevo-android strips every underscore. `BundledDatabaseTests`, run by CI on the fetched databases, is the
      release gate of format.md: the pinned files' `user_version` and all 37 853 articles of `db-254-258`.
- [x] 4a. DrevoKit rest (pravbeseda/drevo-ios#4): `WordListQuery` / `SlovnikQueryBuilder` / `WordListReader`, `SearchHighlighter`,
      `ArticleHtmlBuilder`, `ArticleLink`, `ArticleHistory` (for `HistoryList`), `DayTitle`, `BookmarksStore` /
      `BookmarksSchema`. Deviations from drevo-android: the search is a bound parameter with `%`, `_` and `\` taken
      literally; the main page leads the list by id rather than by its title's leading space; the page carries a
      viewport meta tag and both stylesheets behind `prefers-color-scheme` media queries, so the theme follows the
      app's appearance without a rebuild, and drops `singlePane` and the Bible translation script (a later item);
      `ArticleHistory` keeps typed pages, not `id#scroll` strings; `SearchHighlighter` returns ranges for an
      `AttributedString`, not `<b>` markup. Article bodies link by bare id (`href="16473"`, ~110 000 links in the
      corpus), `#anchor` within the page, or `http(s)`; titles are looked up only for the calendar days.
- [x] 4b (pravbeseda/drevo-ios#5). The `@Observable` models the views bind to (decisions 10, 17): `Library` (an actor over `main`, `patch` and
      the bookmarks), `WordListModel` (topic, search, rows; the view reloads it with `.task(id: query)`, and a stale
      result is dropped), `ArticleModel` (page, contents, history, bookmark, special pages, today / tomorrow, link
      decisions for the web view, the word list selection that drives the split view) and `SettingsModel` (theme,
      font scale, list settings, one JSON value in `UserDefaults`). drevo-android checks no format on the device, and
      neither does `Library`: `BundledDatabaseTests` is the gate.
- [x] 5a. App MVP (pravbeseda/drevo-ios#6), items 1–4 below: the split view, the word list with its title menu and
      search, the article web view with its contents sheet, history and bookmark. Deviations: the UI tests run on the
      databases `db.lock` pins rather than on the fixtures, as decision 11 first said; the window's history and
      selection are kept in `@SceneStorage` and restored through `ArticleModel.start(restoring:)`; a web view created
      after its page was shown (the split view collapsing or expanding) loads `ArticleModel.resumedPage()`, the page at
      its last reported scroll; the split view uses the balanced style, so a portrait iPad keeps the list beside the
      article rather than sliding it over. The iPhone Duo was tested after 5b (see "iPhone Duo" below).
- [x] 5b. App MVP (pravbeseda/drevo-ios#7), items 5–6 below: the "⋯" menu and the settings screen. The release on
      the About screen comes from `db.lock`, which the app bundles through the symlink `Drevo/Resources/db.lock`; the
      font size is a CSS zoom on the page, the setting times the system's body text size over its default, set by a
      user script before the page restores its scroll; the web view runs in mobile content mode, since iPad's desktop
      mode fits the page to the width and undoes the zoom. Deviation: the search match (drevo-android's `searchType`, a
      switch over its list) is a setting too.
- [x] iPhone Duo: the UI tests pass on the iPhone Duo simulator (iOS 27.1, Xcode 27.1) folded and unfolded, each pose
      set by hand in Device Hub, since neither `simctl` nor XCUITest can fold it; folding and unfolding with an article
      open keeps the article, the selection and the list's scroll. The tests read the window's size class instead of
      the device idiom, and tap the back button by its identifier, which the Duo's vertical toolbar moves out of the
      navigation bar. The search field is pinned under the list's title on every width: `searchable` keeps the
      placement it started with, so one that followed the width stayed in the bottom bar after unfolding. CI still
      cannot run the Duo, which needs Xcode 27.

### DrevoKit (test-first, `swift test`)

| Type | Android counterpart | Notes |
|------|---------------------|-------|
| `SQLiteDatabase` / `Statement` | `SQLiteDatabase`, `Cursor` | ~100 lines over `SQLite3`; read-only files opened with `SQLITE_OPEN_READONLY` and the `immutable=1` URI flag |
| `TextPatcher` | javaxdelta `TextPatcher` | over `[UInt16]`; tested against the phase 2 fixtures, which javaxdelta itself produced |
| `ArticleAssembler` | `ArticleAssembler` | inflate through `Compression`: `COMPRESSION_ZLIB` is raw deflate, so the 2-byte zlib header is skipped and the Adler-32 trailer checked by hand; then patch; throws `CorruptArticle` |
| `ArticleReader` | `ArticleReader`, `RowLookup` | reads the `patch` row, then `main` unless `isfulltext = 1` |
| `Article` | `Article`, `TocEntry` | splits TOC and body at `<drevo>`; the TOC is an ordered list, since titles repeat in ~20 articles (`ArticleTest`) |
| `WordListQuery`, `SlovnikQueryBuilder` | same names | topics `0` / `99` / `1`–`11`, search type, portion as `LIMIT` |
| `SearchHighlighter` | same | |
| `ArticleHtmlBuilder` | same | emits `webkit.messageHandlers.drevo.postMessage(...)` instead of `Android.onLoad()` / `Android.onScroll()` |
| `ArticleHistory` | `HistoryList` | back / forward stacks with each page's scroll |
| `DayTitle` | `MyUtils.getDayTitle` | the −13 / −12 day shift |
| `BookmarksStore`, `BookmarksSchema` | `BookmarksDbHelper`, `BookmarksSchema` | same `tblSlovnik(_id, title)` table and `user_version`, so a bookmarks file exported on Android imports on iOS and back |
| `FormatVersion` | phase 4 check | accepts `user_version` 0 and 1 |

### App (SwiftUI)

MVP:

1. `NavigationSplitView` per decision 8: word list and article side by side on a regular width (iPad, unfolded
   iPhone Duo), one column on a compact one; the selection survives every collapse and expansion.
2. Word list with `.searchable`, pinned under its title; its title is the filter menu (all articles as «Все статьи»,
   persons, organisations, places, terms, church, bible, books, saints, holidays, church-slavonic, documents,
   bookmarks).
3. Article in `WKWebView` loading the HTML with the bundled `style.css`, `styleblack.css`, `common.js`, `jquery.min.js`
   (copied from `drevo/src/main/assets/`); in-corpus links (bare ids) classified by `ArticleLink`; TOC sheet; back / forward;
   scroll position restored from the model (decision 9).
4. Bookmarks: add, remove, list.
5. "⋯" menu entries: main page, calendar (with today highlighted), today, tomorrow, chronology, settings, about the site,
   about the app.
6. Settings: theme (system / light / dark, decision 16), font size on top of Dynamic Type, word-list mode and portion.

Later:

- [x] Bookmarks export / import through the Files app, validated by `BookmarksSchema`
      (pravbeseda/drevo-ios#10), in the settings screen. The export is drevo-android's `DrevoBookmarks-yyyyMMdd.db`,
      written by `VACUUM INTO`. Deviation: an import adds the file's bookmarks to the user's, skipping one already
      there by id or title, where drevo-android replaces them after a confirmation; nothing is lost to a wrong file, so
      no confirmation is asked. drevo-android's "clear bookmarks" is not ported.
- Bible translation setting (`bibleTranslate`), "rate the app" and "send feedback" links.

Not ported: OBB download and licensing (the bundle holds the data), billing (dormant on Android), `volumeKeys`
(iOS has no public API for the volume buttons), `quitAlert` (no back-to-exit on iOS), `widthPortrait` / `widthAlbum`
(the split view sizes itself).

### Distribution (after MVP)

Requires an Apple Developer Program membership. TestFlight first, then App Store review. Release process mirrors
drevo-android: bump `db.lock` to the new drevo-db release, build, upload. Automating it (Xcode Cloud or fastlane in CI)
is decided when it starts.

## Risks and prerequisites

- **Apple Developer Program ($99/year).** Payment and registration from Russia are hard since 2022. Check before phase 5
  reaches distribution; phases 1–4 pay off without iOS, and the simulator needs no membership.
- **App Store availability in Russia** for publishing and updates.
- **Update granularity.** The plan relies on the App Store shipping changed files only. Verify with the second TestFlight
  build: the download size of an update that changes only `patch` should be close to 17 MB.
- **Cellular download limit.** A ~335 MB first install over cellular asks the user for permission or waits for Wi-Fi.
- **`TextPatcher` port.** The algorithm is small (three methods), but the UTF-16 offset rule above is the classic way to
  get it wrong; the non-BMP fixture exists for that.

## Open questions

None; the repository name and bundle identifier are decisions 14 and 15.

## Out of scope

- A scheduled CI build of the database (decision 4 leaves it for later, on top of phase 1).
- Background Assets / downloading the database from a server instead of bundling it.
- Moving the Android app from OBB to Play Asset Delivery.

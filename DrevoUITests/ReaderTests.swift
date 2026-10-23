import XCTest

/// Runs on the databases `db.lock` pins, whose titles do not change between runs.
@MainActor
final class ReaderTests: XCTestCase {
    private let app = XCUIApplication()
    private let timeout: TimeInterval = 10

    /// The tests check the layout against the simulator they run on; the app itself never asks for the idiom.
    private var isRegularWidth: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private func launch() {
        continueAfterFailure = false
        app.launch()
    }

    private func open(_ title: String, searching search: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText(search)
        let row = app.staticTexts[title].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        row.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: timeout))
    }

    /// On a compact width the article is pushed over the list; the navigation bar's first button pops it.
    private func backToTheList(from title: String) {
        guard !isRegularWidth else { return }
        app.navigationBars[title].buttons.firstMatch.tap()
    }

    /// Leaves the search, which hides the navigation bar and with it the title menu while it is active.
    private func endSearch() {
        let close = app.buttons["закрыть"]
        if close.exists { close.tap() }
    }

    private func pick(_ topic: String) {
        let title = app.navigationBars.buttons["Древо"]
        XCTAssertTrue(title.waitForExistence(timeout: timeout))
        title.tap()
        app.buttons[topic].tap()
        XCTAssertTrue(app.navigationBars[topic].waitForExistence(timeout: timeout))
    }

    func testTheWordListShowsAllArticlesUnderTheTitleOfTheTree() {
        launch()
        XCTAssertTrue(app.navigationBars["Древо"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["ГЛАВНАЯ СТРАНИЦА"].waitForExistence(timeout: timeout))
    }

    func testARegularWidthShowsTheMainPageBesideTheList() throws {
        try XCTSkipUnless(isRegularWidth, "two columns need a regular width")
        launch()
        XCTAssertTrue(app.navigationBars["Древо"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.navigationBars["ГЛАВНАЯ СТРАНИЦА"].waitForExistence(timeout: timeout))
        open("СЕРГИЙ РАДОНЕЖСКИЙ", searching: "сергий радонеж")
        XCTAssertTrue(app.searchFields.firstMatch.isHittable)
    }

    func testACompactWidthPushesTheArticleOverTheListAndBackReturns() throws {
        try XCTSkipIf(isRegularWidth, "one column needs a compact width")
        launch()
        open("СЕРГИЙ РАДОНЕЖСКИЙ", searching: "сергий радонеж")
        XCTAssertFalse(app.searchFields.firstMatch.isHittable)
        backToTheList(from: "СЕРГИЙ РАДОНЕЖСКИЙ")
        XCTAssertTrue(app.navigationBars["СЕРГИЙ РАДОНЕЖСКИЙ"].waitForNonExistence(timeout: timeout))
        XCTAssertTrue(app.searchFields.firstMatch.isHittable)
    }

    func testTheTitleMenuPicksTheTopic() {
        launch()
        pick("Персоналии")
    }

    func testALinkOpensItsArticleAndHistoryGoesBackAndForward() {
        launch()
        open("СЕРГИЙ РАДОНЕЖСКИЙ", searching: "сергий радонеж")
        let link = app.webViews.links.element(boundBy: 0)
        XCTAssertTrue(link.waitForExistence(timeout: timeout))
        link.tap()
        XCTAssertTrue(app.navigationBars["СЕРГИЙ РАДОНЕЖСКИЙ"].waitForNonExistence(timeout: timeout))

        app.buttons["Назад"].tap()
        XCTAssertTrue(app.navigationBars["СЕРГИЙ РАДОНЕЖСКИЙ"].waitForExistence(timeout: timeout))
        app.buttons["Вперёд"].tap()
        XCTAssertTrue(app.navigationBars["СЕРГИЙ РАДОНЕЖСКИЙ"].waitForNonExistence(timeout: timeout))
    }

    func testTheContentsSheetJumpsAndCloses() {
        launch()
        open("СЕРГИЙ РАДОНЕЖСКИЙ", searching: "сергий радонеж")
        app.buttons["Содержание"].tap()
        let sheet = app.navigationBars["Содержание"]
        XCTAssertTrue(sheet.waitForExistence(timeout: timeout))
        app.collectionViews.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: timeout))
    }

    func testABookmarkIsListedUnderBookmarksUntilRemoved() {
        launch()
        open("СЕРГИЙ РАДОНЕЖСКИЙ", searching: "сергий радонеж")
        // A run stopped halfway can leave the bookmark set.
        if app.buttons["Убрать закладку"].waitForExistence(timeout: 2) {
            app.buttons["Убрать закладку"].tap()
        }
        app.buttons["Добавить закладку"].tap()
        XCTAssertTrue(app.buttons["Убрать закладку"].waitForExistence(timeout: timeout))

        backToTheList(from: "СЕРГИЙ РАДОНЕЖСКИЙ")
        endSearch()
        pick("Закладки")
        let row = app.collectionViews.staticTexts["СЕРГИЙ РАДОНЕЖСКИЙ"]
        XCTAssertTrue(row.waitForExistence(timeout: timeout))

        row.tap()
        app.buttons["Убрать закладку"].tap()
        XCTAssertTrue(app.buttons["Добавить закладку"].waitForExistence(timeout: timeout))
        backToTheList(from: "СЕРГИЙ РАДОНЕЖСКИЙ")
        XCTAssertTrue(row.waitForNonExistence(timeout: timeout))
    }
}

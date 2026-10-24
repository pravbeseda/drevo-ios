import XCTest

/// Runs on the databases `db.lock` pins, whose titles do not change between runs.
@MainActor
final class ReaderTests: XCTestCase {
    private let app = XCUIApplication()
    private let timeout: TimeInterval = 10

    /// The window's size class, which the app lays itself out by: a split view column may report a narrowed one.
    private var isRegularWidth: Bool { app.windows.firstMatch.horizontalSizeClass == .regular }

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

    /// On a compact width the article is pushed over the list; its back button, wherever the bar puts it, pops it.
    private func backToTheList() {
        guard !isRegularWidth else { return }
        app.buttons["BackButton"].tap()
    }

    private func pick(_ topic: String) {
        let title = app.navigationBars.buttons["Все статьи"]
        XCTAssertTrue(title.waitForExistence(timeout: timeout))
        title.tap()
        app.buttons[topic].tap()
        XCTAssertTrue(app.navigationBars[topic].waitForExistence(timeout: timeout))
    }

    func testTheWordListShowsAllArticlesUnderItsTitle() {
        launch()
        XCTAssertTrue(app.navigationBars["Все статьи"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["ГЛАВНАЯ СТРАНИЦА"].waitForExistence(timeout: timeout))
    }

    func testARegularWidthShowsTheMainPageBesideTheList() throws {
        launch()
        try XCTSkipUnless(isRegularWidth, "two columns need a regular width")
        XCTAssertTrue(app.navigationBars["Все статьи"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.navigationBars["ГЛАВНАЯ СТРАНИЦА"].waitForExistence(timeout: timeout))
        open("СЕРГИЙ РАДОНЕЖСКИЙ", searching: "сергий радонеж")
        XCTAssertTrue(app.searchFields.firstMatch.isHittable)
    }

    func testTheSearchFieldStaysWhileTheListScrolls() {
        launch()
        let list = app.collectionViews.firstMatch
        let row = list.staticTexts["ГЛАВНАЯ СТРАНИЦА"]
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        list.swipeUp()
        XCTAssertFalse(row.isHittable)
        XCTAssertTrue(app.searchFields.firstMatch.isHittable)
    }

    func testACompactWidthPushesTheArticleOverTheListAndBackReturns() throws {
        launch()
        try XCTSkipIf(isRegularWidth, "one column needs a compact width")
        open("СЕРГИЙ РАДОНЕЖСКИЙ", searching: "сергий радонеж")
        XCTAssertFalse(app.searchFields.firstMatch.isHittable)
        backToTheList()
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
        // Opened from the list, not the search: going back would refocus the search field, and the keyboard sliding
        // in after the app reports idle can catch the tap that leaves the search.
        let title = "13 СИРИЙСКИХ ОТЦОВ"
        let row = app.collectionViews.staticTexts[title]
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        row.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: timeout))
        // A run stopped halfway can leave the bookmark set.
        if app.buttons["Убрать закладку"].waitForExistence(timeout: 2) {
            app.buttons["Убрать закладку"].tap()
        }
        app.buttons["Добавить закладку"].tap()
        XCTAssertTrue(app.buttons["Убрать закладку"].waitForExistence(timeout: timeout))

        backToTheList()
        pick("Закладки")
        XCTAssertTrue(row.waitForExistence(timeout: timeout))

        row.tap()
        app.buttons["Убрать закладку"].tap()
        XCTAssertTrue(app.buttons["Добавить закладку"].waitForExistence(timeout: timeout))
        backToTheList()
        XCTAssertTrue(row.waitForNonExistence(timeout: timeout))
    }

    /// One menu per window: over the list on a compact width, over the article on a regular one.
    private func openMenu() {
        let menu = app.buttons["Меню"]
        XCTAssertTrue(menu.waitForExistence(timeout: timeout))
        XCTAssertEqual(app.buttons.matching(identifier: "Меню").count, 1)
        menu.tap()
    }

    func testTheMenuOpensASpecialPage() {
        launch()
        openMenu()
        app.buttons["Хронология"].tap()
        XCTAssertTrue(app.navigationBars["ХРОНОЛОГИЯ"].waitForExistence(timeout: timeout))
    }

    func testTodayOpensTheArticleOfTheDay() {
        launch()
        openMenu()
        app.buttons["Сегодня"].tap()
        // Day articles are titled by the day and the month.
        let day = app.navigationBars.matching(NSPredicate(format: "identifier MATCHES %@", "[0-9]+ .+")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: timeout))
    }

    func testAboutNamesTheBundledDatabase() {
        launch()
        openMenu()
        app.buttons["О приложении"].tap()
        let release = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "База статей, db-"))
            .firstMatch
        XCTAssertTrue(release.waitForExistence(timeout: timeout))
        app.buttons["Готово"].tap()
        XCTAssertTrue(release.waitForNonExistence(timeout: timeout))
    }

    /// `common.js` relabels a Bible passage's toggle links by what the page shows.
    private func cslToggle(_ verb: String) -> XCUIElement {
        app.webViews.links.matching(NSPredicate(format: "label MATCHES %@", "\(verb) +церковнославянский перевод"))
            .firstMatch
    }

    private func pickBibleTranslations(_ option: String) {
        openMenu()
        app.buttons["Настройки"].tap()
        let picker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Переводы Библии")).firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: timeout))
        picker.tap()
        app.buttons[option].tap()
        app.buttons["Готово"].tap()
        XCTAssertTrue(app.navigationBars["Настройки"].waitForNonExistence(timeout: timeout))
    }

    /// Picks the setting before searching: going back to the list would refocus the search field, which hides the
    /// menu, so only a regular width, whose menu sits over the article, changes it again with the article open.
    func testTheBibleSettingHidesTheChurchSlavonicTranslation() {
        launch()
        pickBibleTranslations("Только русский")
        open("МФ 1", searching: "мф 1")
        XCTAssertTrue(cslToggle("Показать").waitForExistence(timeout: timeout))

        guard isRegularWidth else { return }
        pickBibleTranslations("Русский и церковнославянский")
        XCTAssertTrue(cslToggle("Скрыть").waitForExistence(timeout: timeout))

        // The page's own toggle holds while only the font size changes; it ends where it began.
        cslToggle("Скрыть").tap()
        XCTAssertTrue(cslToggle("Показать").waitForExistence(timeout: timeout))
        openMenu()
        app.buttons["Настройки"].tap()
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: timeout))
        slider.adjust(toNormalizedSliderPosition: 0.4)
        slider.adjust(toNormalizedSliderPosition: 0.2)
        app.buttons["Готово"].tap()
        XCTAssertFalse(cslToggle("Скрыть").waitForExistence(timeout: 3))
        XCTAssertTrue(cslToggle("Показать").exists)
    }

    func testSettingsOpenAndClose() {
        launch()
        openMenu()
        app.buttons["Настройки"].tap()
        XCTAssertTrue(app.navigationBars["Настройки"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.sliders.firstMatch.exists)
        app.buttons["Готово"].tap()
        XCTAssertTrue(app.navigationBars["Настройки"].waitForNonExistence(timeout: timeout))
    }
}

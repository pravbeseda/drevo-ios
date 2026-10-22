import XCTest

@MainActor
final class LaunchTests: XCTestCase {
    func testLaunchShowsTheTitle() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Древо"].waitForExistence(timeout: 10))
    }
}

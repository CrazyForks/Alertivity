import XCTest

final class AlertivityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesAndStaysActive() {
        let app = launchApp()
        app.launch()

        // Menu-bar apps often remain background; just ensure they leave the notRunning state.
        let deadline = Date().addingTimeInterval(8)
        var isRunning = false
        repeat {
            if app.state != .notRunning {
                isRunning = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        XCTAssertTrue(isRunning, "App should be launched (foreground or background)")
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UITests")
        return app
    }

    private func selectMenuValue(in popup: XCUIElement, value: String) {
        guard popup.waitForExistence(timeout: 2) else { return }
        popup.click()

        let menuItem = popup.menuItems[value]
        if menuItem.waitForExistence(timeout: 2) {
            menuItem.click()
        }
    }
}

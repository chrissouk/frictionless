import XCTest

final class FrictionlessUITests: XCTestCase {
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func addTask(_ app: XCUIApplication, name: String) {
        app.buttons["Add task"].firstMatch.tap()
        let input = app.textFields["task-name"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText(name)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["task-\(name)"].waitForExistence(timeout: 5))
    }

    func testTaskSwitchAuditCorrectionAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-storage"]
        app.launch()
        XCTAssertTrue(app.buttons["Add task"].firstMatch.waitForExistence(timeout: 10))
        capture(app, "Empty tasks")
        addTask(app, name: "Writing")
        app.buttons["Manage tasks"].tap()
        app.buttons["Add task"].tap()
        let field = app.textFields["task-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("Reading")
        app.buttons["Save"].tap()
        app.buttons["Done"].tap()
        app.buttons["task-Writing"].tap()
        XCTAssertTrue(app.buttons["Stop tracking"].waitForExistence(timeout: 5))
        app.buttons["task-Reading"].tap()
        XCTAssertEqual(app.buttons["task-Reading"].value as? String, "Recording")
        capture(app, "Task picker recording")
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Stop tracking"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["task-Reading"].value as? String, "Recording")
        app.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["Timeline"].waitForExistence(timeout: 5))
        capture(app, "Daily audit")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Reading' AND label CONTAINS 'Recording'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Correct interval"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        app.buttons["Done"].tap()
        app.buttons["Stop tracking"].tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.buttons["Stop tracking"].waitForExistence(timeout: 5))
    }

    func testAuditWithRecordedHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-storage", "--audit-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["task-Writing"].waitForExistence(timeout: 10))
        app.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["2h 0m"].waitForExistence(timeout: 5))
        capture(app, "Daily audit with history")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Reading' AND label CONTAINS '1h 0m'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Correct interval"].waitForExistence(timeout: 5))
        capture(app, "Interval correction")
        app.buttons["5m"].tap()
        app.switches["Adjust previous task’s end too"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Daily audit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["55m"].exists)
        XCTAssertTrue(app.staticTexts["1h 5m"].exists)
    }

    func testAccessibilityLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-storage", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Add task"].firstMatch.waitForExistence(timeout: 10))
        capture(app, "Large text empty")
        addTask(app, name: "A longer task name for reading")
        app.buttons["task-A longer task name for reading"].tap()
        XCTAssertTrue(app.buttons["Stop tracking"].waitForExistence(timeout: 5))
        capture(app, "Large text recording")
    }
}

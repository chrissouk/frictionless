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
        XCTAssertTrue(app.navigationBars["Manage tasks"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Add task"].exists)
        let input = app.textFields["new-task-name"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText(name)
        app.buttons["Add"].tap()
        XCTAssertTrue(app.buttons["managed-task-\(name)"].waitForExistence(timeout: 5))
        capture(app, "Inline task creation")
        app.navigationBars["Manage tasks"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["task-\(name)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["What’s next?"].isHittable)
    }

    func testTaskSwitchAuditCorrectionAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-storage"]
        app.launch()
        XCTAssertTrue(app.buttons["Add task"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["What’s next?"].isHittable)
        capture(app, "Empty tasks")
        addTask(app, name: "Writing")
        app.buttons["Manage tasks"].tap()
        let field = app.textFields["new-task-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("Reading")
        app.buttons["Add"].tap()
        app.navigationBars["Manage tasks"].buttons["Done"].tap()
        app.buttons["task-Writing"].tap()
        XCTAssertTrue(app.buttons["Stop tracking"].waitForExistence(timeout: 5))
        app.buttons["task-Reading"].tap()
        XCTAssertEqual(app.buttons["task-Reading"].value as? String, "Recording")
        XCTAssertEqual(app.buttons.matching(identifier: "task-Reading").count, 1)
        XCTAssertLessThan(app.buttons["task-Reading"].frame.minY, app.buttons["task-Writing"].frame.minY)
        XCTAssertGreaterThan(app.buttons["Stop tracking"].frame.minY, app.buttons["task-Writing"].frame.maxY)
        XCTAssertLessThan(app.buttons["Stop tracking"].frame.maxY, app.buttons["Today"].frame.minY)
        capture(app, "Task picker recording")
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Stop tracking"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["task-Reading"].value as? String, "Recording")
        app.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["Timeline"].waitForExistence(timeout: 5))
        capture(app, "Daily audit")
        app.buttons["interval-Reading"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Correct interval"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        app.buttons["Done"].tap()
        app.buttons["Stop tracking"].tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.buttons["Stop tracking"].waitForExistence(timeout: 5))
    }

    func testTaskColorEditing() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-storage"]
        app.launch()
        XCTAssertTrue(app.buttons["Add task"].waitForExistence(timeout: 10))
        addTask(app, name: "Writing")
        app.buttons["Manage tasks"].tap()
        app.buttons["managed-task-Writing"].tap()
        XCTAssertTrue(app.navigationBars["Edit task"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["task-color"].firstMatch.tap()
        app.staticTexts["Sand"].tap()
        app.navigationBars["Edit task"].buttons["Save"].tap()
        XCTAssertTrue(app.buttons["managed-task-Writing"].waitForExistence(timeout: 5))
        app.buttons["managed-task-Writing"].tap()
        let color = app.buttons["task-color"]
        XCTAssertTrue(color.waitForExistence(timeout: 5))
        XCTAssertEqual(color.value as? String, "Sand")
        capture(app, "Saved task color")
        app.navigationBars["Edit task"].buttons["Cancel"].tap()
        app.navigationBars["Manage tasks"].buttons["Done"].tap()
        app.buttons["task-Writing"].tap()
        XCTAssertTrue(app.buttons["Stop tracking"].waitForExistence(timeout: 5))
        capture(app, "Colored active task")
    }

    func testAuditWithRecordedHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-storage", "--audit-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["task-Writing"].waitForExistence(timeout: 10))
        app.buttons["Today"].tap()
        app.buttons["Previous day"].tap()
        XCTAssertTrue(app.staticTexts["2h 0m"].waitForExistence(timeout: 5))
        capture(app, "Daily audit with history")
        app.buttons["interval-Reading"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Correct interval"].waitForExistence(timeout: 5))
        capture(app, "Interval correction")
        XCTAssertFalse(app.staticTexts["Started earlier"].exists)
        XCTAssertFalse(app.buttons["5m"].exists)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Daily audit"].waitForExistence(timeout: 5))
        let closed = NSPredicate(format: "exists == false")
        expectation(for: closed, evaluatedWith: app.navigationBars["Correct interval"])
        waitForExpectations(timeout: 5)
        capture(app, "Audit after correction")
        XCTAssertTrue(app.staticTexts["2h 0m"].exists)
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
        app.buttons["Today"].tap()
        XCTAssertTrue(app.navigationBars["Daily audit"].waitForExistence(timeout: 5))
        capture(app, "Large text audit")
    }
}

import XCTest

final class FrictionlessUITests: XCTestCase {
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func addTask(_ app: XCUIApplication, name: String) {
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Continue"].isEnabled)
        let input = app.textFields["new-task-name"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText(name)
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        capture(app, "Inline task creation")
        app.buttons["Continue"].tap()
        app.buttons["onboarding-task-\(name)"].tap()
        XCTAssertTrue(app.buttons["Let’s go"].waitForExistence(timeout: 5))
        capture(app, "Onboarding reminder")
        app.buttons["Let’s go"].tap()
        XCTAssertTrue(app.buttons["task-\(name)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["What’s next?"].isHittable)
    }

    func testTaskSwitchAuditCorrectionAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-storage"]
        app.launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
        capture(app, "Onboarding intro")
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

    func testOnboardingResumesWithoutLosingTasksOrRecording() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-storage"]
        app.launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
        app.buttons["Get started"].tap()
        let input = app.textFields["new-task-name"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("Writing")
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["Writing"].waitForExistence(timeout: 5))
        input.typeText("Reading")
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["Reading"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["What fills your day?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Writing"].exists)
        XCTAssertTrue(app.staticTexts["Reading"].exists)
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["onboarding-task-Reading"].exists)
        app.buttons["Edit tasks"].tap()
        XCTAssertTrue(app.staticTexts["Writing"].exists)
        app.buttons["Continue"].tap()
        app.buttons["onboarding-task-Writing"].tap()
        XCTAssertTrue(app.buttons["Let’s go"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Let’s go"].waitForExistence(timeout: 10))
        app.buttons["Let’s go"].tap()
        XCTAssertEqual(app.buttons["task-Writing"].value as? String, "Recording")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Stop tracking"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["task-Writing"].value as? String, "Recording")
        XCTAssertFalse(app.buttons["Get started"].exists)
    }

    func testTaskColorEditing() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-storage"]
        app.launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
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
        XCTAssertFalse(app.buttons["Get started"].exists)
        app.buttons["Today"].tap()
        app.buttons["Previous day"].tap()
        XCTAssertTrue(app.staticTexts["2h 0m"].waitForExistence(timeout: 5))
        capture(app, "Daily audit with history")
        app.buttons["interval-Reading"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Correct interval"].waitForExistence(timeout: 5))
        capture(app, "Interval correction")
        app.buttons["5m"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Daily audit"].waitForExistence(timeout: 5))
        let closed = NSPredicate(format: "exists == false")
        expectation(for: closed, evaluatedWith: app.navigationBars["Correct interval"])
        waitForExpectations(timeout: 5)
        capture(app, "Audit after correction")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '55m'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '1h 5m'")).firstMatch.exists)
    }

    func testAccessibilityLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-storage", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
        capture(app, "Large text onboarding")
        addTask(app, name: "A longer task name for reading")
        app.buttons["task-A longer task name for reading"].tap()
        XCTAssertTrue(app.buttons["Stop tracking"].waitForExistence(timeout: 5))
        capture(app, "Large text recording")
        app.buttons["Today"].tap()
        XCTAssertTrue(app.navigationBars["Daily audit"].waitForExistence(timeout: 5))
        capture(app, "Large text audit")
    }
}

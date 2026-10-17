import SwiftUI
import XCTest
@testable import MoleCore
@testable import MoleEngine
@testable import MoleUI

final class NavigationTests: XCTestCase {
    
    func testNavigationWorkflowItems() {
        let items = NavigationWorkflow.allCases
        XCTAssertEqual(items.count, 6)
        XCTAssertEqual(items[0], .clean)
        XCTAssertEqual(items[1], .analyze)
        XCTAssertEqual(items[2], .software)
        XCTAssertEqual(items[3], .optimize)
        XCTAssertEqual(items[4], .status)
        XCTAssertEqual(items[5], .history)
    }

    func testWorkflowMetadata() {
        for workflow in NavigationWorkflow.allCases {
            XCTAssertFalse(workflow.title.isEmpty, "Workflow title must not be empty")
            XCTAssertFalse(workflow.systemImage.isEmpty, "Workflow systemImage must not be empty")
        }

        XCTAssertEqual(NavigationWorkflow.clean.title, "Clean")
        XCTAssertEqual(NavigationWorkflow.clean.systemImage, "sparkles")
        XCTAssertEqual(NavigationWorkflow.analyze.title, "Analyze")
        XCTAssertEqual(NavigationWorkflow.analyze.systemImage, "chart.pie.fill")
        XCTAssertEqual(NavigationWorkflow.software.title, "Software")
        XCTAssertEqual(NavigationWorkflow.software.systemImage, "shippingbox.fill")
        XCTAssertEqual(NavigationWorkflow.optimize.title, "Optimize")
        XCTAssertEqual(NavigationWorkflow.optimize.systemImage, "bolt.fill")
        XCTAssertEqual(NavigationWorkflow.status.title, "Status")
        XCTAssertEqual(NavigationWorkflow.status.systemImage, "gauge.with.needle.fill")
        XCTAssertEqual(NavigationWorkflow.history.title, "History")
        XCTAssertEqual(NavigationWorkflow.history.systemImage, "clock.arrow.circlepath")
    }
}

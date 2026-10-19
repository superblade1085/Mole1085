import SwiftUI
import XCTest
@testable import MoleCore
@testable import MoleEngine
@testable import MoleUI

final class NavigationTests: XCTestCase {
    
    func testNavigationWorkflowItems() {
        let items = NavigationWorkflow.allCases
        XCTAssertEqual(items.count, 7)
        XCTAssertEqual(items[0], .clean)
        XCTAssertEqual(items[1], .analyze)
        XCTAssertEqual(items[2], .software)
        XCTAssertEqual(items[3], .optimize)
        XCTAssertEqual(items[4], .status)
        XCTAssertEqual(items[5], .history)
        XCTAssertEqual(items[6], .settings)
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
        XCTAssertEqual(NavigationWorkflow.settings.title, "Settings")
        XCTAssertEqual(NavigationWorkflow.settings.systemImage, "gearshape.fill")
    }

    @MainActor
    func testViewInstantiationSmokeTests() {
        let coordinator = MoleCoordinator()
        
        // Instantiate views and evaluate their body properties to verify no runtime traps
        let sidebar = SidebarView(coordinator: coordinator)
        _ = sidebar.body
        
        let clean = CleanView(coordinator: coordinator)
        _ = clean.body
        
        var showPreview = true
        let preview = CleanPreviewSheet(
            coordinator: coordinator,
            isPresented: Binding(get: { showPreview }, set: { showPreview = $0 })
        )
        _ = preview.body
        
        let treemap = AnalyzeTreemapView(coordinator: coordinator)
        _ = treemap.body
        
        let status = StatusView(coordinator: coordinator)
        _ = status.body

        let software = SoftwareView(coordinator: coordinator)
        _ = software.body

        let optimize = OptimizeView(coordinator: coordinator)
        _ = optimize.body

        let history = HistoryView(coordinator: coordinator)
        _ = history.body

        let settings = SettingsView(coordinator: coordinator)
        _ = settings.body

        var showOnboarding = true
        let onboarding = OnboardingView(
            coordinator: coordinator,
            isPresented: Binding(get: { showOnboarding }, set: { showOnboarding = $0 })
        )
        _ = onboarding.body
    }

    func testOnboardingPersistenceKey() {
        XCTAssertEqual(OnboardingView.completedOnboardingKey, "hasCompletedOnboarding")
        UserDefaults.standard.set(true, forKey: OnboardingView.completedOnboardingKey)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: OnboardingView.completedOnboardingKey))
    }
}

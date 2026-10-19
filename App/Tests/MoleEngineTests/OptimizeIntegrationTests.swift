import Foundation
import XCTest
@testable import MoleEngine

final class OptimizeIntegrationTests: XCTestCase {

    func testDecodeOptimizeTasksJSON() throws {
        let sampleJSON = """
        [
          {
            "id": "cache_refresh",
            "name": "Finder Cache Refresh",
            "description": "Refresh QuickLook thumbnails & icon services cache",
            "requires_sudo": false,
            "safe": true
          },
          {
            "id": "disk_permissions_repair",
            "name": "Permission Repair",
            "description": "Fix user directory permission issues",
            "requires_sudo": true,
            "safe": true
          }
        ]
        """

        let data = try XCTUnwrap(sampleJSON.data(using: .utf8))
        let tasks = try JSONDecoder().decode([OptimizeTaskItem].self, from: data)

        XCTAssertEqual(tasks.count, 2)
        XCTAssertEqual(tasks[0].id, "cache_refresh")
        XCTAssertEqual(tasks[0].name, "Finder Cache Refresh")
        XCTAssertEqual(tasks[0].systemIcon, "photo.stack")
        XCTAssertFalse(tasks[0].requiresSudo)
        XCTAssertTrue(tasks[0].safe)

        XCTAssertEqual(tasks[1].id, "disk_permissions_repair")
        XCTAssertEqual(tasks[1].systemIcon, "lock.shield")
        XCTAssertTrue(tasks[1].requiresSudo)
    }

    func testDecodeOptimizeExecutionResult() throws {
        let sampleJSON = """
        {
          "status": "success",
          "action": "cache_refresh",
          "exit_code": 0,
          "output": "  ✓ QuickLook thumbnails refreshed"
        }
        """

        let data = try XCTUnwrap(sampleJSON.data(using: .utf8))
        let result = try JSONDecoder().decode(OptimizeExecutionResult.self, from: data)

        XCTAssertEqual(result.status, "success")
        XCTAssertEqual(result.action, "cache_refresh")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("QuickLook thumbnails refreshed"))
    }

    @MainActor
    func testFetchOptimizeTasksViaCoordinator() async throws {
        let coordinator = MoleCoordinator()
        try await coordinator.fetchOptimizeTasks()

        XCTAssertFalse(coordinator.optimizeTasks.isEmpty, "Optimize tasks list must not be empty")
        XCTAssertTrue(coordinator.optimizeTasks.contains(where: { $0.id == "cache_refresh" }))
        XCTAssertTrue(coordinator.optimizeTasks.contains(where: { $0.id == "network_optimization" }))
    }

    @MainActor
    func testExecuteSafeOptimizeTaskViaCoordinator() async throws {
        let coordinator = MoleCoordinator()
        let result = try await coordinator.executeOptimizeTask(id: "cache_refresh")

        XCTAssertEqual(result.status, "success")
        XCTAssertEqual(result.action, "cache_refresh")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNotNil(coordinator.optimizeTaskResults["cache_refresh"])
    }
}

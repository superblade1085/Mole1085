import Foundation
import XCTest
@testable import MoleCore
@testable import MoleEngine

@MainActor
final class CoordinatorTests: XCTestCase {
    
    func testCategoryAggregationAndSelection() {
        let coordinator = MoleCoordinator(isMock: true)
        
        let cat1 = CleanCategory(
            id: "xcode",
            name: "Xcode Caches & DerivedData",
            group: .developer,
            bytes: 10_000_000,
            itemCount: 42,
            safetyLevel: .guaranteedSafe,
            isProtectedByTCC: false,
            isSelected: true,
            paths: []
        )
        let cat2 = CleanCategory(
            id: "logs",
            name: "System Logs",
            group: .logs,
            bytes: 5_000_000,
            itemCount: 12,
            safetyLevel: .rebuildable,
            isProtectedByTCC: true,
            isSelected: true,
            paths: []
        )
        
        coordinator.updateCategories([cat1, cat2])
        
        XCTAssertEqual(coordinator.totalReclaimableBytes, 15_000_000)
        XCTAssertEqual(coordinator.selectedReclaimableBytes, 15_000_000)
        
        // Toggle selection of cat2
        coordinator.toggleCategorySelection(id: "logs")
        XCTAssertEqual(coordinator.selectedReclaimableBytes, 10_000_000)
        XCTAssertEqual(coordinator.totalReclaimableBytes, 15_000_000)
        
        // Deselect all
        coordinator.deselectAllCategories()
        XCTAssertEqual(coordinator.selectedReclaimableBytes, 0)
        
        // Select all (should only select non-TCC categories: cat1 = 10,000,000)
        coordinator.selectAllCategories()
        XCTAssertEqual(coordinator.selectedReclaimableBytes, 10_000_000, "selectAllCategories must not select TCC-protected categories without FDA")
    }

    func testTreemapNodeGeneration() {
        let coordinator = MoleCoordinator(isMock: true)
        let cat1 = CleanCategory(
            id: "xcode",
            name: "Xcode",
            group: .developer,
            bytes: 60,
            itemCount: 1,
            safetyLevel: .guaranteedSafe,
            isProtectedByTCC: false,
            isSelected: true,
            paths: []
        )
        let cat2 = CleanCategory(
            id: "brew",
            name: "Homebrew",
            group: .developer,
            bytes: 40,
            itemCount: 1,
            safetyLevel: .guaranteedSafe,
            isProtectedByTCC: false,
            isSelected: true,
            paths: []
        )
        
        coordinator.updateCategories([cat1, cat2])
        guard let root = coordinator.treemapRoot else {
            XCTFail("treemapRoot must be generated when categories are present")
            return
        }
        
        XCTAssertEqual(root.size, 100)
        XCTAssertEqual(root.children.count, 2)
        
        // Layout normalized rects must fit inside [0, 0, 1, 1]
        for child in root.children {
            XCTAssertGreaterThanOrEqual(child.rect.minX, 0.0)
            XCTAssertGreaterThanOrEqual(child.rect.minY, 0.0)
            XCTAssertLessThanOrEqual(child.rect.maxX, 1.0001)
            XCTAssertLessThanOrEqual(child.rect.maxY, 1.0001)
            XCTAssertGreaterThan(child.rect.width, 0.0)
            XCTAssertGreaterThan(child.rect.height, 0.0)
        }
    }

    func testMockScanLifecycle() async throws {
        let coordinator = MoleCoordinator(isMock: true)
        XCTAssertFalse(coordinator.isScanning)
        
        try await coordinator.scanReclaimableSpace()
        
        XCTAssertFalse(coordinator.isScanning)
        XCTAssertGreaterThan(coordinator.categories.count, 0)
        XCTAssertGreaterThan(coordinator.totalReclaimableBytes, 0)
        XCTAssertEqual(coordinator.scanProgress, 1.0)
    }

    func testSafeCleanupExecutionWithMockFiles() async throws {
        let coordinator = MoleCoordinator(isMock: true)
        
        // Create synthetic files in /tmp to clean safely
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mole-coord-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let dummyFile1 = tempDir.appendingPathComponent("cache1.tmp")
        let dummyFile2 = tempDir.appendingPathComponent("cache2.tmp")
        try "test-content-1".write(to: dummyFile1, atomically: true, encoding: .utf8)
        try "test-content-2".write(to: dummyFile2, atomically: true, encoding: .utf8)
        
        let cat = CleanCategory(
            id: "test-cat",
            name: "Test Caches",
            group: .systemCaches,
            bytes: 200,
            itemCount: 2,
            safetyLevel: .guaranteedSafe,
            isProtectedByTCC: false,
            isSelected: true,
            paths: [dummyFile1, dummyFile2]
        )
        
        coordinator.updateCategories([cat])
        
        let mockTrashDir = tempDir.appendingPathComponent("MockTrash")
        try FileManager.default.createDirectory(at: mockTrashDir, withIntermediateDirectories: true)
        
        let cleanedBytes = try await coordinator.performSafeCleanup(categories: [cat]) { url, outResult in
            let dest = mockTrashDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: dest)
            outResult?.pointee = dest as NSURL
        }
        XCTAssertGreaterThan(cleanedBytes, 0)
        
        // Verify files are no longer at original locations
        XCTAssertFalse(FileManager.default.fileExists(atPath: dummyFile1.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dummyFile2.path))
        
        // Clean up mock directory
        try? FileManager.default.removeItem(at: tempDir)
    }
}

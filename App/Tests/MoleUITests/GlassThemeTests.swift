import SwiftUI
import XCTest
@testable import MoleCore
@testable import MoleEngine
@testable import MoleUI

final class GlassThemeTests: XCTestCase {
    
    func testGlassCornerRadiusAndBorderTokens() {
        XCTAssertEqual(GlassTheme.cardRadius, 12.0)
        XCTAssertEqual(GlassTheme.innerRadius, 8.0)
        XCTAssertEqual(GlassTheme.specularLineWidth, 0.5)
    }

    func testCategoryColorTokens() {
        let devColor = GlassTheme.color(for: .developer)
        let sysColor = GlassTheme.color(for: .systemCaches)
        let leftoversColor = GlassTheme.color(for: .appLeftovers)
        let logsColor = GlassTheme.color(for: .logs)
        
        // Ensure all categories map to distinct colors
        XCTAssertNotEqual(devColor, sysColor)
        XCTAssertNotEqual(devColor, leftoversColor)
        XCTAssertNotEqual(devColor, logsColor)
    }

    func testStorageGaugeProportions() {
        let info = DiskSpaceInfo(totalBytes: 1_000_000_000, freeBytes: 400_000_000, reclaimableBytes: 200_000_000)
        // Used space = 1,000,000,000 - 400,000,000 = 600,000,000
        // Clean Used (non-reclaimable) = 600,000,000 - 200,000,000 = 400,000,000 (40%)
        // Reclaimable = 200,000,000 (20%)
        // Free = 400,000,000 (40%)
        
        let proportions = StorageGaugeBar.calculateProportions(diskSpace: info)
        XCTAssertEqual(proportions.usedRatio, 0.4, accuracy: 0.001)
        XCTAssertEqual(proportions.reclaimableRatio, 0.2, accuracy: 0.001)
        XCTAssertEqual(proportions.freeRatio, 0.4, accuracy: 0.001)
        XCTAssertEqual(proportions.usedRatio + proportions.reclaimableRatio + proportions.freeRatio, 1.0, accuracy: 0.001)
    }

    func testStorageGaugeZeroTotalCapacityHandledSafely() {
        let info = DiskSpaceInfo(totalBytes: 0, freeBytes: 0, reclaimableBytes: 0)
        let proportions = StorageGaugeBar.calculateProportions(diskSpace: info)
        XCTAssertEqual(proportions.usedRatio, 0.0)
        XCTAssertEqual(proportions.reclaimableRatio, 0.0)
        XCTAssertEqual(proportions.freeRatio, 0.0)
    }
}

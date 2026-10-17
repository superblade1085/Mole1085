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
        XCTAssertNotNil(GlassTheme.highContrastBorderColor)
    }

    func testCategoryColorTokensAreMutuallyExclusive() {
        let allGroups: [CleanCategoryGroup] = [.developer, .systemCaches, .appLeftovers, .logs]
        for i in 0..<allGroups.count {
            for j in (i + 1)..<allGroups.count {
                let colorA = GlassTheme.color(for: allGroups[i])
                let colorB = GlassTheme.color(for: allGroups[j])
                XCTAssertNotEqual(
                    colorA,
                    colorB,
                    "Category colors must be distinct: \(allGroups[i]) vs \(allGroups[j])"
                )
            }
        }
    }

    func testStorageGaugeProportions() {
        let info = DiskSpaceInfo(totalBytes: 1_000_000_000, freeBytes: 400_000_000, reclaimableBytes: 200_000_000)
        // Total = 1,000,000,000
        // Free = 400,000,000 (40%)
        // Used total = 600,000,000
        // Reclaimable = 200,000,000 (20%)
        // Clean Used = 400,000,000 (40%)
        
        let proportions = StorageGaugeBar.calculateProportions(diskSpace: info)
        XCTAssertEqual(proportions.usedRatio, 0.4, accuracy: 0.001)
        XCTAssertEqual(proportions.reclaimableRatio, 0.2, accuracy: 0.001)
        XCTAssertEqual(proportions.freeRatio, 0.4, accuracy: 0.001)
        XCTAssertEqual(proportions.usedRatio + proportions.reclaimableRatio + proportions.freeRatio, 1.0, accuracy: 0.001)
    }

    func testStorageGaugeClampingWhenReclaimableExceedsUsed() {
        // Disk: 1 GB total, 800 MB free -> 200 MB used.
        // Reported reclaimable is 500 MB (which exceeds the 200 MB used).
        let info = DiskSpaceInfo(totalBytes: 1_000_000_000, freeBytes: 800_000_000, reclaimableBytes: 500_000_000)
        let proportions = StorageGaugeBar.calculateProportions(diskSpace: info)

        // Free = 800 MB / 1 GB = 0.8
        // Total Used = 200 MB. Reclaimable must be clamped to 200 MB max.
        // Reclaimable ratio = 0.2, Used (non-reclaimable) ratio = 0.0.
        XCTAssertEqual(proportions.freeRatio, 0.8, accuracy: 0.001)
        XCTAssertEqual(proportions.reclaimableRatio, 0.2, accuracy: 0.001)
        XCTAssertEqual(proportions.usedRatio, 0.0, accuracy: 0.001)
    }

    func testStorageGaugeClampingWhenFreeExceedsTotal() {
        // Purgeable APFS anomaly: free reported as 1.2 GB on a 1.0 GB volume.
        let info = DiskSpaceInfo(totalBytes: 1_000_000_000, freeBytes: 1_200_000_000, reclaimableBytes: 100_000_000)
        let proportions = StorageGaugeBar.calculateProportions(diskSpace: info)

        // Free clamped to totalBytes (1.0 ratio), used = 0.0, reclaimable = 0.0
        XCTAssertEqual(proportions.freeRatio, 1.0, accuracy: 0.001)
        XCTAssertEqual(proportions.usedRatio, 0.0, accuracy: 0.001)
        XCTAssertEqual(proportions.reclaimableRatio, 0.0, accuracy: 0.001)
    }

    func testStorageGaugeZeroTotalCapacityHandledSafely() {
        let info = DiskSpaceInfo(totalBytes: 0, freeBytes: 0, reclaimableBytes: 0)
        let proportions = StorageGaugeBar.calculateProportions(diskSpace: info)
        XCTAssertEqual(proportions.usedRatio, 0.0)
        XCTAssertEqual(proportions.reclaimableRatio, 0.0)
        XCTAssertEqual(proportions.freeRatio, 0.0)
    }
}

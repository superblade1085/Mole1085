import XCTest
@testable import MoleCore

final class ScaffoldingTests: XCTestCase {
    func testProjectTargetVersion() {
        XCTAssertEqual(MoleCore.minimumOSVersion, "14.0")
        XCTAssertTrue(MoleCore.isSupportedPlatform)
    }
}

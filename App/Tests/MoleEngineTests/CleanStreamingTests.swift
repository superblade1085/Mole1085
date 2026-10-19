import XCTest
@testable import MoleEngine

final class CleanStreamingTests: XCTestCase {

    func testParseScanStreamItemEvent() throws {
        let jsonLine = """
        {"type": "item", "category": "xcode", "category_name": "Xcode DerivedData", "group": "developer", "path": "/Users/test/Library/Developer/Xcode/DerivedData", "bytes": 15000000, "safe": true, "safety_level": "guaranteedSafe"}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(CleanStreamEvent.self, from: jsonLine)
        XCTAssertEqual(event.type, "item")
        XCTAssertEqual(event.category, "xcode")
        XCTAssertEqual(event.categoryName, "Xcode DerivedData")
        XCTAssertEqual(event.group, "developer")
        XCTAssertEqual(event.bytes, 15000000)
        XCTAssertEqual(event.safe, true)
        XCTAssertEqual(event.safetyLevel, "guaranteedSafe")
    }

    func testParseSummaryEvent() throws {
        let jsonLine = """
        {"type": "summary", "category": "xcode", "total_bytes": 15000000, "count": 1}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(CleanStreamEvent.self, from: jsonLine)
        XCTAssertEqual(event.type, "summary")
        XCTAssertEqual(event.category, "xcode")
        XCTAssertEqual(event.totalBytes, 15000000)
        XCTAssertEqual(event.count, 1)
    }

    func testParseCleanedEvent() throws {
        let jsonLine = """
        {"type": "cleaned", "category": "xcode", "path": "/Users/test/tmp", "bytes_reclaimed": 5000}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(CleanStreamEvent.self, from: jsonLine)
        XCTAssertEqual(event.type, "cleaned")
        XCTAssertEqual(event.category, "xcode")
        XCTAssertEqual(event.bytesReclaimed, 5000)
    }
}

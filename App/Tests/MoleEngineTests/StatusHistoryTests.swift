import XCTest
@testable import MoleEngine

final class StatusHistoryTests: XCTestCase {
    
    func testDecodeHealthJSON() throws {
        let sampleJSON = """
        {
          "memory_used_gb": 28.21,
          "memory_total_gb": 48.00,
          "disk_used_gb": 396.73,
          "disk_total_gb": 460.43,
          "disk_used_percent": 86.2,
          "uptime_days": 1.5,
          "optimizations": [
            {
              "category": "system",
              "name": "Finder Cache Refresh",
              "description": "Refresh QuickLook thumbnails",
              "action": "cache_refresh",
              "safe": true
            }
          ]
        }
        """.data(using: .utf8)!

        let telemetry = try JSONDecoder().decode(SystemHealthSnapshot.self, from: sampleJSON)
        XCTAssertEqual(telemetry.memoryUsedGB, 28.21, accuracy: 0.01)
        XCTAssertEqual(telemetry.memoryTotalGB, 48.00, accuracy: 0.01)
        XCTAssertEqual(telemetry.diskUsedPercent, 86.2, accuracy: 0.01)
        XCTAssertEqual(telemetry.optimizations.count, 1)
        XCTAssertEqual(telemetry.optimizations[0].action, "cache_refresh")
    }

    func testDecodeHistoryManifestJSON() throws {
        let sampleHistoryJSON = """
        {
          "logs": {
            "operations": "/Users/test/Library/Logs/mole/operations.log",
            "deletions": "/Users/test/Library/Logs/mole/deletions.log"
          },
          "limit": 5,
          "sessions": [
            {
              "id": "sess-001",
              "timestamp": "2026-10-19 10:00:00",
              "command": "clean",
              "bytes_reclaimed": 14500000000,
              "category": "xcode"
            }
          ],
          "deletions": [
            {
              "path": "/Users/test/Library/Developer/Xcode/DerivedData/app-1",
              "size": "500MB",
              "timestamp": "2026-10-19 10:00:01"
            }
          ]
        }
        """.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(HistoryManifest.self, from: sampleHistoryJSON)
        XCTAssertEqual(manifest.limit, 5)
        XCTAssertEqual(manifest.sessions.count, 1)
        XCTAssertEqual(manifest.sessions[0].command, "clean")
        XCTAssertEqual(manifest.deletions.count, 1)
        XCTAssertEqual(manifest.deletions[0].size, "500MB")
    }
}

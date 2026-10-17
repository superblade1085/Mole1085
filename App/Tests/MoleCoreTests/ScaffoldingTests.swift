import XCTest
@testable import MoleCore

final class ScaffoldingTests: XCTestCase {
    func testProjectTargetVersion() {
        XCTAssertEqual(MoleCore.minimumOSVersion, "14.0")
        XCTAssertTrue(MoleCore.isSupportedPlatform)
    }

    struct ScanEvent: Codable, Equatable {
        let category: String
        let path: String
        let bytes: Int
        let safe: Bool
    }

    func testJsonStreamAdapterExecutionAndSchema() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent() // MoleCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // App
            .deletingLastPathComponent() // Mole_with_UI
        let adapterScript = repoRoot.appendingPathComponent("adapters/json_stream.sh")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: adapterScript.path), "adapters/json_stream.sh must exist")
        
        for category in ["dev", "user"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [adapterScript.path, category]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            try process.run()
            process.waitUntilExit()
            
            XCTAssertEqual(process.terminationStatus, 0, "Adapter must exit with 0 for category \(category)")
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let lines = output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            
            XCTAssertFalse(lines.isEmpty, "Adapter must emit at least one JSON event for category \(category)")
            
            let decoder = JSONDecoder()
            for line in lines.prefix(25) {
                guard let lineData = line.data(using: .utf8) else {
                    XCTFail("Line could not be converted to UTF-8 data")
                    continue
                }
                let event = try decoder.decode(ScanEvent.self, from: lineData)
                XCTAssertEqual(event.category, category)
                XCTAssertFalse(event.path.isEmpty)
                XCTAssertGreaterThanOrEqual(event.bytes, 0)
            }
        }
    }
}

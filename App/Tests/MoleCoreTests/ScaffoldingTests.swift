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
        
        // Create an isolated synthetic mock home directory in /tmp to guarantee ZERO access to user files
        // and prevent macOS TCC privacy dialogs during test execution.
        let mockHome = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mole-mock-home-\(UUID().uuidString)")
        let fileManager = FileManager.default
        
        defer {
            try? fileManager.removeItem(at: mockHome)
        }
        
        // Setup synthetic mock directories
        let mockDevCache = mockHome.appendingPathComponent("Library/Developer/Xcode/DerivedData/SampleApp")
        let mockAppCache = mockHome.appendingPathComponent("Library/Caches/com.example.mockapp")
        let mockDownloads = mockHome.appendingPathComponent("Downloads")
        let mockNpmCache = mockHome.appendingPathComponent(".npm/_cacache")
        
        try fileManager.createDirectory(at: mockDevCache, withIntermediateDirectories: true)
        try "mock derived data".write(to: mockDevCache.appendingPathComponent("build.log"), atomically: true, encoding: .utf8)
        
        try fileManager.createDirectory(at: mockAppCache, withIntermediateDirectories: true)
        try "mock app cache".write(to: mockAppCache.appendingPathComponent("cache.db"), atomically: true, encoding: .utf8)
        
        try fileManager.createDirectory(at: mockDownloads, withIntermediateDirectories: true)
        try "mock installer".write(to: mockDownloads.appendingPathComponent("mock_installer.pkg"), atomically: true, encoding: .utf8)
        
        try fileManager.createDirectory(at: mockNpmCache, withIntermediateDirectories: true)
        try "mock npm".write(to: mockNpmCache.appendingPathComponent("dummy_index"), atomically: true, encoding: .utf8)
        
        let testedCategories = ["dev", "caches", "user", "all"]
        
        for category in testedCategories {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [adapterScript.path, category]
            
            // Strictly isolate environment to synthetic mock HOME and standard POSIX PATH
            var env = ProcessInfo.processInfo.environment
            env["HOME"] = mockHome.path
            env["USER"] = "mockuser"
            env["TMPDIR"] = NSTemporaryDirectory()
            process.environment = env
            
            let pipe = Pipe()
            process.standardOutput = pipe
            let inPipe = Pipe()
            process.standardInput = inPipe
            
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            
            XCTAssertEqual(process.terminationStatus, 0, "Adapter must exit with 0 for category \(category)")
            let output = String(data: data, encoding: .utf8) ?? ""
            let lines = output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            
            if category == "dev" || category == "user" || category == "all" {
                XCTAssertFalse(lines.isEmpty, "Adapter must emit at least one JSON event for category \(category)")
            }
            
            let decoder = JSONDecoder()
            for line in lines.prefix(25) {
                guard let lineData = line.data(using: .utf8) else {
                    XCTFail("Line could not be converted to UTF-8 data")
                    continue
                }
                let event = try decoder.decode(ScanEvent.self, from: lineData)
                if category == "all" {
                    XCTAssertFalse(event.category.isEmpty, "Category in 'all' event should not be empty")
                } else {
                    XCTAssertEqual(event.category, category)
                }
                XCTAssertFalse(event.path.isEmpty)
                XCTAssertGreaterThanOrEqual(event.bytes, 0)
            }
        }
    }
}

import Foundation
import XCTest
@testable import MoleEngine

final class AnalyzeIntegrationTests: XCTestCase {

    func testDecodeAnalyzeOutputJSON() throws {
        let sampleJSON = """
        {
          "scan_status": "complete",
          "path": "/Users/test",
          "overview": false,
          "entries": [
            {
              "scan_status": "complete",
              "name": "Library",
              "path": "/Users/test/Library",
              "size": 524288000,
              "is_dir": true
            },
            {
              "scan_status": "complete",
              "name": "Documents",
              "path": "/Users/test/Documents",
              "size": 104857600,
              "is_dir": true
            },
            {
              "scan_status": "complete",
              "name": "archive.zip",
              "path": "/Users/test/archive.zip",
              "size": 52428800,
              "is_dir": false
            }
          ],
          "total_size": 681574400,
          "total_files": 3
        }
        """

        let data = try XCTUnwrap(sampleJSON.data(using: .utf8))
        let output = try JSONDecoder().decode(AnalyzeOutput.self, from: data)

        XCTAssertEqual(output.path, "/Users/test")
        XCTAssertEqual(output.scanStatus, "complete")
        XCTAssertFalse(output.overview)
        XCTAssertEqual(output.entries.count, 3)
        XCTAssertEqual(output.totalSize, 681574400)
        XCTAssertEqual(output.totalFiles, 3)

        // Verify TreemapNode layout conversion
        let root = output.toTreemapNode()
        XCTAssertEqual(root.id, "/Users/test")
        XCTAssertEqual(root.name, "test")
        XCTAssertEqual(root.size, 681574400)
        XCTAssertEqual(root.children.count, 3)

        for child in root.children {
            XCTAssertGreaterThanOrEqual(child.rect.minX, 0.0)
            XCTAssertGreaterThanOrEqual(child.rect.minY, 0.0)
            XCTAssertLessThanOrEqual(child.rect.maxX, 1.0001)
            XCTAssertLessThanOrEqual(child.rect.maxY, 1.0001)
        }
    }

    func testAnalyzeStreamAdapterExecution() async throws {
        // Create isolated temp directory with test files
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mole-analyze-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let subDir = tempDir.appendingPathComponent("SubDir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let file1 = tempDir.appendingPathComponent("test1.dat")
        let file2 = subDir.appendingPathComponent("test2.dat")
        try Data(repeating: 0x41, count: 4096).write(to: file1)
        try Data(repeating: 0x42, count: 8192).write(to: file2)

        let adapterURL = MoleEngineLocator.shared.resolveAdapter(named: "analyze_stream.sh")
        let adapter = try XCTUnwrap(adapterURL, "analyze_stream.sh adapter must be resolvable")

        let streamer = ProcessStreamer()
        let stream = streamer.stream(
            executable: "/bin/bash",
            arguments: [adapter.path, "--path", tempDir.path],
            environment: ProcessInfo.processInfo.environment
        )

        var jsonBuffer = ""
        for try await line in stream {
            jsonBuffer += line + "\n"
        }

        let data = try XCTUnwrap(jsonBuffer.data(using: .utf8), "Output must be valid utf8")
        let output = try JSONDecoder().decode(AnalyzeOutput.self, from: data)

        XCTAssertEqual(output.scanStatus, "complete")
        XCTAssertGreaterThan(output.totalSize, 0)
        XCTAssertGreaterThanOrEqual(output.entries.count, 2)
    }
}

import Foundation
import XCTest
@testable import MoleEngine

final class SoftwareIntegrationTests: XCTestCase {

    func testDecodeInstalledAppsJSON() throws {
        let sampleJSON = """
        [
          {"name": "IINA", "bundle_id": "com.colliderli.iina", "source": "App", "uninstall_name": "IINA", "path": "/Applications/IINA.app", "size": "205.8MB"},
          {"name": "Xcode", "bundle_id": "com.apple.dt.Xcode", "source": "App", "uninstall_name": "Xcode", "path": "/Applications/Xcode.app", "size": "11.8GB"},
          {"name": "Tool", "bundle_id": "com.example.tool", "source": "Homebrew", "uninstall_name": "tool", "path": "/Applications/Tool.app", "size": "500KB"}
        ]
        """

        let data = try XCTUnwrap(sampleJSON.data(using: .utf8))
        let apps = try JSONDecoder().decode([InstalledApp].self, from: data)

        XCTAssertEqual(apps.count, 3)
        XCTAssertEqual(apps[0].name, "IINA")
        XCTAssertEqual(apps[0].bundleID, "com.colliderli.iina")
        XCTAssertEqual(apps[0].source, "App")
        XCTAssertEqual(apps[0].sizeDisplay, "205.8MB")
        XCTAssertGreaterThan(apps[0].sizeBytes, 200_000_000)

        XCTAssertEqual(apps[1].name, "Xcode")
        XCTAssertGreaterThan(apps[1].sizeBytes, 11_000_000_000)

        XCTAssertEqual(apps[2].source, "Homebrew")
        XCTAssertGreaterThan(apps[2].sizeBytes, 400_000)
    }

    func testParseSizeEdgeCases() {
        XCTAssertEqual(InstalledApp.parseSize("0 B"), 0)
        XCTAssertEqual(InstalledApp.parseSize("1024 B"), 1024)
        XCTAssertEqual(InstalledApp.parseSize("10 KB"), 10 * 1024)
        XCTAssertEqual(InstalledApp.parseSize("5.5 MB"), Int64(5.5 * 1024 * 1024))
        XCTAssertEqual(InstalledApp.parseSize("2.0 GB"), Int64(2.0 * 1024 * 1024 * 1024))
        XCTAssertEqual(InstalledApp.parseSize("invalid"), 0)
    }

    func testUninstallAdapterLeftoversExecution() async throws {
        let adapterURL = MoleEngineLocator.shared.resolveAdapter(named: "uninstall_adapter.sh")
        let adapter = try XCTUnwrap(adapterURL, "uninstall_adapter.sh adapter must be resolvable")

        let streamer = ProcessStreamer()
        let stream = streamer.stream(
            executable: "/bin/bash",
            arguments: [adapter.path, "--leftovers", "com.colliderli.iina", "IINA", "/Applications/IINA.app"],
            environment: ProcessInfo.processInfo.environment
        )

        var jsonBuffer = ""
        for try await line in stream {
            jsonBuffer += line + "\n"
        }

        let data = try XCTUnwrap(jsonBuffer.data(using: .utf8))
        let leftovers = try JSONDecoder().decode([AppLeftoverItem].self, from: data)

        // Leftovers array is valid JSON (may be empty or contain real caches)
        XCTAssertNotNil(leftovers)
    }
}

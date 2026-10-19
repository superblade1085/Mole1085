import XCTest
@testable import MoleEngine

final class EngineLocatorTests: XCTestCase {
    func testEngineRootResolution() {
        let locator = MoleEngineLocator.shared
        guard let engineRoot = locator.engineRootURL else {
            XCTFail("MoleEngineLocator must resolve an engine root URL")
            return
        }
        
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: engineRoot.path, isDirectory: &isDir)
        XCTAssertTrue(exists, "Engine root must exist on filesystem: \(engineRoot.path)")
        XCTAssertTrue(isDir.boolValue, "Engine root must be a directory")
    }

    func testResolveAdapter() {
        let locator = MoleEngineLocator.shared
        let adapterURL = locator.resolveAdapter(named: "json_stream.sh")
        XCTAssertNotNil(adapterURL, "Must resolve json_stream.sh adapter")
        if let url = adapterURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Adapter must exist at \(url.path)")
        }
    }

    func testResolveScript() {
        let locator = MoleEngineLocator.shared
        let scriptURL = locator.resolveScript(named: "bin/clean.sh")
        XCTAssertNotNil(scriptURL, "Must resolve bin/clean.sh")
        if let url = scriptURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Script must exist at \(url.path)")
        }
    }
}

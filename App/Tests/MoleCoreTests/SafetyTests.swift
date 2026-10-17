import XCTest
@testable import MoleCore

final class SafetyTests: XCTestCase {
    
    func testDatabaseCompanionBundling() {
        let db = URL(fileURLWithPath: "/tmp/sample_app.db")
        let companions = DatabaseGuard.bundleCompanionPaths(databaseURL: db)
        let filenames = companions.map { $0.lastPathComponent }
        
        XCTAssertTrue(filenames.contains("sample_app.db"))
        XCTAssertTrue(filenames.contains("sample_app.db-wal"))
        XCTAssertTrue(filenames.contains("sample_app.db-shm"))
        
        // Also test resolving from a sidecar file
        let wal = URL(fileURLWithPath: "/tmp/sample_app.db-wal")
        let fromWal = DatabaseGuard.bundleCompanionPaths(databaseURL: wal)
        let walFilenames = fromWal.map { $0.lastPathComponent }
        XCTAssertEqual(Set(filenames), Set(walFilenames))
    }
    
    func testSafeTrashMovesItemToTrash() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mole-trash-test-\(UUID().uuidString)")
        let mockTrash = tempDir.appendingPathComponent("MockTrash")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let targetFile = tempDir.appendingPathComponent("discard_me.tmp")
        try "temp trashable data".write(to: targetFile, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile.path))
        
        let trashedURL = try SafeTrash.trashItem(at: targetFile, trashDirectoryOverride: mockTrash)
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetFile.path), "Original file should no longer exist at source path")
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashedURL.path), "Item should exist in trash directory")
    }
    
    func testSafeTrashRefusesProtectedSystemPaths() {
        let protectedPaths = [
            "/",
            "/System",
            "/System/Library",
            "/usr",
            "/bin",
            "/sbin",
            "/Applications",
            "/Library",
            "/Users",
            NSHomeDirectory()
        ]
        
        for path in protectedPaths {
            let url = URL(fileURLWithPath: path)
            XCTAssertThrowsError(try SafeTrash.trashItem(at: url), "SafeTrash must reject protected path: \(path)") { error in
                guard let safetyError = error as? SafeTrashError else {
                    XCTFail("Expected SafeTrashError but got: \(error)")
                    return
                }
                XCTAssertEqual(safetyError, SafeTrashError.systemPathProtected(path))
            }
        }
    }
    
    func testDatalessGuardRegularFile() throws {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dataless_test_\(UUID().uuidString).tmp")
        try "regular file content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        XCTAssertFalse(DatalessGuard.isDatalessOrUbiquitous(url: tempFile))
    }
    
    func testFullDiskAccessSettingsURL() {
        let expectedURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        XCTAssertEqual(FullDiskAccess.settingsURL, expectedURL)
    }
}

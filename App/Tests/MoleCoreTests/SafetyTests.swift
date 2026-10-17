import XCTest
@testable import MoleCore

final class SafetyTests: XCTestCase {
    
    func testDatabaseCompanionBundling() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mole-db-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let db = tempDir.appendingPathComponent("sample_app.db")
        let wal = tempDir.appendingPathComponent("sample_app.db-wal")
        let shm = tempDir.appendingPathComponent("sample_app.db-shm")

        try "db data".write(to: db, atomically: true, encoding: .utf8)
        try "wal data".write(to: wal, atomically: true, encoding: .utf8)
        // Note: do not create shm to test onlyExisting filter

        let allCompanions = DatabaseGuard.bundleCompanionPaths(databaseURL: db, onlyExisting: false)
        let filenames = allCompanions.map { $0.lastPathComponent }
        XCTAssertTrue(filenames.contains("sample_app.db"))
        XCTAssertTrue(filenames.contains("sample_app.db-wal"))
        XCTAssertTrue(filenames.contains("sample_app.db-shm"))
        
        // Test onlyExisting filter
        let existingCompanions = DatabaseGuard.bundleCompanionPaths(databaseURL: db, onlyExisting: true)
        let existingFilenames = existingCompanions.map { $0.lastPathComponent }
        XCTAssertTrue(existingFilenames.contains("sample_app.db"))
        XCTAssertTrue(existingFilenames.contains("sample_app.db-wal"))
        XCTAssertFalse(existingFilenames.contains("sample_app.db-shm"), "Non-existent shm file should be filtered out when onlyExisting: true")
        
        // Test companion file recognition
        XCTAssertTrue(DatabaseGuard.isCompanionFile(url: wal))
        XCTAssertTrue(DatabaseGuard.isCompanionFile(url: shm))
        // Verify non-database file with similar suffix is NOT identified as a companion
        let dailyJournal = tempDir.appendingPathComponent("daily-journal")
        XCTAssertFalse(DatabaseGuard.isCompanionFile(url: dailyJournal))
    }
    
    func testSafeTrashMovesItemToTrash() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mole-trash-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let targetFile = tempDir.appendingPathComponent("discard_me.tmp")
        try "temp trashable data".write(to: targetFile, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile.path))
        
        var handlerCalled = false
        let fakeTrashURL = tempDir.appendingPathComponent("TrashResult.tmp")
        
        let trashed = try SafeTrash.trashItem(at: targetFile) { url, outResult in
            handlerCalled = true
            try FileManager.default.moveItem(at: url, to: fakeTrashURL)
            outResult?.pointee = fakeTrashURL as NSURL
        }
        
        XCTAssertTrue(handlerCalled, "SafeTrash must invoke the Cocoa trashing handler")
        XCTAssertEqual(trashed.path, fakeTrashURL.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fakeTrashURL.path))
    }

    func testSafeTrashRealExecution() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mole-real-trash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let targetFile = tempDir.appendingPathComponent("real_trash_candidate.tmp")
        try "real trash data".write(to: targetFile, atomically: true, encoding: .utf8)

        do {
            let resultingTrashURL = try SafeTrash.trashItem(at: targetFile)
            XCTAssertFalse(FileManager.default.fileExists(atPath: targetFile.path))
            try? FileManager.default.removeItem(at: resultingTrashURL)
        } catch SafeTrashError.permissionDenied {
            // Expected in sandboxed / headless CI environments where access to ~/.Trash is restricted by TCC
            XCTAssertTrue(true)
        }
    }
    
    func testSafeTrashRefusesProtectedSystemPaths() {
        let protectedPaths = [
            "/",
            "/System",
            "/System/Library",
            "/usr",
            "/usr/bin",
            "/bin",
            "/sbin",
            "/private",
            "/private/etc",
            "/private/var",
            "/private/var/db",
            "/private/var/root",
            "/etc",
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

    func testDatalessGuardDetectsSyntheticDatalessStub() {
        let mockURL = URL(fileURLWithPath: "/tmp/mock_icloud_file.dat")
        let isDataless = DatalessGuard.isDatalessOrUbiquitous(url: mockURL) { _ in
            return DatalessGuard.sfDatalessFlag
        }
        XCTAssertTrue(isDataless, "DatalessGuard must detect SF_DATALESS flag on stubs")
    }
    
    func testFullDiskAccessSettingsURL() {
        let expectedURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        XCTAssertEqual(FullDiskAccess.openSystemSettingsURL, expectedURL)
        XCTAssertEqual(FullDiskAccess.settingsURL, expectedURL)
    }

    func testFullDiskAccessIsGrantedExecution() {
        // Runs silent heuristic without crashing or throwing
        _ = FullDiskAccess.isGranted()
    }
}

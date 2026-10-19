import Foundation
import XCTest
@testable import MoleCore

final class UpdateManagerTests: XCTestCase {
    
    func testUpdateManagerInitializationAndFeedURL() {
        let feedURL = URL(string: "https://mole.fit/appcast.xml")!
        let manager = UpdateManager(feedURL: feedURL)
        XCTAssertEqual(manager.feedURL, feedURL)
        XCTAssertEqual(manager.state, .idle)
        XCTAssertEqual(manager.publicEdKey, UpdateManager.defaultPublicEdKey)
    }

    func testDefaultPublicEdKey() {
        let manager = UpdateManager()
        XCTAssertEqual(manager.publicEdKey, UpdateManager.defaultPublicEdKey)
        XCTAssertFalse(manager.publicEdKey.isEmpty)
    }

    func testUpdateWillInstallTriggersHelperGracefulShutdown() async {
        let feedURL = URL(string: "https://mole.fit/appcast.xml")!
        var shutdownInvoked = false
        
        let manager = UpdateManager(
            feedURL: feedURL,
            helperShutdownHandler: {
                shutdownInvoked = true
                return true
            }
        )
        
        let success = await manager.prepareForUpdateInstallation()
        XCTAssertTrue(success)
        XCTAssertTrue(shutdownInvoked, "UpdateManager must invoke graceful helper shutdown prior to bundle swap")
    }

    func testUpdateCheckStateTransitions() async {
        let feedURL = URL(string: "https://mole.fit/appcast.xml")!
        let manager = UpdateManager(feedURL: feedURL)
        
        XCTAssertEqual(manager.state, .idle)
        
        await manager.checkForUpdates()
        XCTAssertEqual(manager.state, .upToDate)
    }

    func testDefaultHelperShutdownTimeoutWhenDaemonAbsent() async {
        // When com.mole.helper is not installed, defaultHelperShutdown must fail-safe and return false
        // within the specified timeout without deadlocking.
        let result = await UpdateManager.defaultHelperShutdown(timeout: 0.1)
        XCTAssertFalse(result, "Shutdown should return false when daemon is absent")
    }
}

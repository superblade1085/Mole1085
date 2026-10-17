import Security
import XCTest
@testable import MoleCore
@testable import MoleHelper

final class XPCVerificationTests: XCTestCase {
    
    func testRequirementStringFormat() {
        let reqString = XPCVerification.designatedRequirementString(teamID: "TEAM123", bundleID: "com.mole.MoleApp")
        XCTAssertTrue(reqString.contains("identifier \"com.mole.MoleApp\""))
        XCTAssertTrue(reqString.contains("certificate leaf[subject.OU] == \"TEAM123\""))
        XCTAssertTrue(reqString.contains("anchor apple generic"))
        
        // Ensure the requirement string is syntactically valid by compiling it with the Security framework
        var requirement: SecRequirement?
        let status = SecRequirementCreateWithString(reqString as CFString, [], &requirement)
        XCTAssertEqual(status, errSecSuccess, "Generated requirement string must be syntactically valid in Security framework")
        XCTAssertNotNil(requirement)
    }

    func testHelperProtocolInterfaceRegistration() {
        let interface = NSXPCInterface(with: MoleHelperProtocol.self)
        XCTAssertNotNil(interface)
    }

    func testHelperDaemonProtocolImplementation() {
        let daemon = HelperDaemon(expectedTeamID: nil, expectedBundleID: "com.mole.MoleApp")
        
        let versionExpectation = expectation(description: "Get version")
        daemon.getVersion { version in
            XCTAssertEqual(version, "1.0.0")
            versionExpectation.fulfill()
        }
        
        let shutdownExpectation = expectation(description: "Graceful shutdown")
        daemon.requestGracefulShutdown { success in
            XCTAssertTrue(success)
            shutdownExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }

    func testHelperDaemonRejectsProtectedSystemPathClean() {
        let daemon = HelperDaemon(expectedTeamID: nil, expectedBundleID: "com.mole.MoleApp")
        let expectation = expectation(description: "Reject protected path")
        
        daemon.cleanRootPath("/System") { success, error in
            XCTAssertFalse(success)
            XCTAssertNotNil(error)
            XCTAssertTrue(error?.contains("protected") ?? false)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
}

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
        var shutdownCalled = false
        let shutdownExecutedExpectation = expectation(description: "Shutdown executed")
        
        let daemon = HelperDaemon(
            expectedTeamID: nil,
            expectedBundleID: "com.mole.MoleApp",
            shutdownHandler: {
                shutdownCalled = true
                shutdownExecutedExpectation.fulfill()
            }
        )
        
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
        XCTAssertTrue(shutdownCalled)
    }

    func testAuditTokenVerificationWithCurrentProcess() {
        var token = audit_token_t()
        var count = mach_msg_type_number_t(MemoryLayout<audit_token_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &token) { tokenPtr in
            tokenPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_AUDIT_TOKEN), intPtr, &count)
            }
        }
        XCTAssertEqual(kr, KERN_SUCCESS, "task_info should succeed in retrieving audit_token_t for the current process")
        
        // Negative test: current test runner does not have team "INVALID_TEAM" and bundle "com.mole.MoleApp"
        let verified = XPCVerification.verifyAuditToken(
            token,
            expectedTeamID: "INVALID_TEAM",
            expectedBundleID: "com.mole.MoleApp"
        )
        XCTAssertFalse(verified, "Verification must reject mismatched team/bundle for current process")

        // Zeroed audit token must fail safely
        var zeroToken = audit_token_t()
        let zeroVerified = XPCVerification.verifyAuditToken(
            zeroToken,
            expectedTeamID: nil,
            expectedBundleID: "com.mole.MoleApp"
        )
        XCTAssertFalse(zeroVerified, "Verification must safely reject zeroed audit token")
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

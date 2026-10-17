import Darwin
import Foundation
import Security

public enum XPCVerification {
    
    /// Generates the Apple Security Framework designated requirement string
    /// for code signature verification of peer processes connecting over XPC.
    public static func designatedRequirementString(teamID: String?, bundleID: String) -> String {
        if let teamID = teamID, !teamID.isEmpty {
            return "anchor apple generic and identifier \"\(bundleID)\" and ((certificate leaf[field.1.2.840.113635.100.6.1.9] /* Apple Development */) or (certificate 1[field.1.2.840.113635.100.6.2.6] /* Apple Developer ID CA */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* Developer ID */)) and certificate leaf[subject.OU] == \"\(teamID)\""
        } else {
            return "anchor apple generic and identifier \"\(bundleID)\""
        }
    }

    /// Verifies raw `audit_token_t` against designated requirement string.
    public static func verifyAuditToken(
        _ auditToken: audit_token_t,
        expectedTeamID: String?,
        expectedBundleID: String
    ) -> Bool {
        var token = auditToken
        let auditTokenData = Data(bytes: &token, count: MemoryLayout<audit_token_t>.size)

        let attributes: [CFString: Any] = [
            kSecGuestAttributeAudit: auditTokenData as CFData
        ]

        var secCode: SecCode?
        let codeStatus = SecCodeCopyGuestWithAttributes(nil, attributes as CFDictionary, [], &secCode)
        guard codeStatus == errSecSuccess, let code = secCode else {
            return false
        }

        let requirementString = designatedRequirementString(teamID: expectedTeamID, bundleID: expectedBundleID)
        var secRequirement: SecRequirement?
        let reqStatus = SecRequirementCreateWithString(requirementString as CFString, [], &secRequirement)
        guard reqStatus == errSecSuccess, let requirement = secRequirement else {
            return false
        }

        let validityStatus = SecCodeCheckValidityWithErrors(code, SecCSFlags(), requirement, nil)
        return validityStatus == errSecSuccess
    }

    /// Verifies the connecting XPC peer against the expected bundle identifier and team ID
    /// using `SecCodeCopyGuestWithAttributes` and `SecRequirementRef`.
    public static func verifyConnection(
        connection: NSXPCConnection,
        expectedTeamID: String?,
        expectedBundleID: String
    ) -> Bool {
        // Zero-trust: auditToken MUST be extracted from the connection via NSValue
        guard let tokenValue = connection.value(forKey: "auditToken") as? NSValue else {
            return false
        }
        var auditToken = audit_token_t()
        tokenValue.getValue(&auditToken)

        return verifyAuditToken(auditToken, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID)
    }
}

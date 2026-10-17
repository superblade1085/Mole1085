import Foundation
import MoleCore

public final class HelperDaemon: NSObject, NSXPCListenerDelegate, MoleHelperProtocol {
    public static let machServiceName = "com.mole.helper"
    public static let version = "1.0.0"

    private let expectedTeamID: String?
    private let expectedBundleID: String

    public init(expectedTeamID: String? = nil, expectedBundleID: String = "com.mole.MoleApp") {
        self.expectedTeamID = expectedTeamID
        self.expectedBundleID = expectedBundleID
        super.init()
    }

    // MARK: - NSXPCListenerDelegate

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Zero-trust audit token verification
        if let teamID = expectedTeamID {
            guard XPCVerification.verifyConnection(
                connection: newConnection,
                expectedTeamID: teamID,
                expectedBundleID: expectedBundleID
            ) else {
                newConnection.invalidate()
                return false
            }
        }

        let interface = NSXPCInterface(with: MoleHelperProtocol.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    // MARK: - MoleHelperProtocol

    public func getVersion(reply: @escaping (String) -> Void) {
        reply(Self.version)
    }

    public func cleanRootPath(_ path: String, reply: @escaping (Bool, String?) -> Void) {
        let url = URL(fileURLWithPath: path)
        do {
            try SafeTrash.trashItem(at: url)
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    public func requestGracefulShutdown(reply: @escaping (Bool) -> Void) {
        reply(true)
        // Allow XPC response to be transmitted before process termination
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.2) {
            exit(0)
        }
    }
}

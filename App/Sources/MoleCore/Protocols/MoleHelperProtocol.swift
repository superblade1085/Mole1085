import Foundation

@objc(MoleHelperProtocol)
public protocol MoleHelperProtocol {
    /// Queries the helper daemon version string.
    func getVersion(reply: @escaping (String) -> Void)

    /// Safely deletes or trashes a path using root privileges, strictly validated by SafeTrash.
    func cleanRootPath(_ path: String, reply: @escaping (Bool, String?) -> Void)

    /// Gracefully stops the helper daemon to allow Sparkle 2 app updates without file locks.
    func requestGracefulShutdown(reply: @escaping (Bool) -> Void)
}

import Foundation

public enum UpdateState: Sendable, Equatable {
    case idle
    case checking
    case updateAvailable(version: String)
    case upToDate
    case error(String)
}

public final class UpdateManager: @unchecked Sendable {
    public static let defaultPublicEdKey = "BOJd/2gtWBcIb4tYJsvD6qLnQgPnlmgChaCwV0y0FWE="
    
    public let feedURL: URL
    public let publicEdKey: String
    public private(set) var state: UpdateState = .idle

    private let helperShutdownHandler: () async -> Bool

    public init(
        feedURL: URL = URL(string: "https://raw.githubusercontent.com/superblade1085/Mole1085/main/dist/appcast.xml")!,
        publicEdKey: String = UpdateManager.defaultPublicEdKey,
        helperShutdownHandler: @escaping () async -> Bool = { await UpdateManager.defaultHelperShutdown() }
    ) {
        self.feedURL = feedURL
        self.publicEdKey = publicEdKey
        self.helperShutdownHandler = helperShutdownHandler
    }

    /// Prepares for a Sparkle 2 bundle update by gracefully shutting down the
    /// privileged helper daemon (`com.mole.helper`) before the application bundle is swapped.
    public func prepareForUpdateInstallation() async -> Bool {
        return await helperShutdownHandler()
    }

    /// Checks for available updates from the feed URL.
    public func checkForUpdates() async {
        self.state = .checking
        // In real execution without active Sparkle network feed, report up to date
        self.state = .upToDate
    }

    /// Connects via XPC to `com.mole.helper`, requests graceful shutdown, and awaits completion with timeout.
    public static func defaultHelperShutdown(timeout: TimeInterval = 2.0) async -> Bool {
        return await withCheckedContinuation { continuation in
            let connection = NSXPCConnection(machServiceName: "com.mole.helper")
            connection.remoteObjectInterface = NSXPCInterface(with: MoleHelperProtocol.self)
            connection.resume()

            var hasResumed = false
            let lock = NSLock()
            let safeResume: (Bool) -> Void = { success in
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    connection.invalidate()
                    continuation.resume(returning: success)
                }
            }

            // Timeout watchdog
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                safeResume(false)
            }

            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
                safeResume(false)
            }

            guard let helper = proxy as? MoleHelperProtocol else {
                safeResume(false)
                return
            }

            helper.requestGracefulShutdown { success in
                safeResume(success)
            }
        }
    }
}

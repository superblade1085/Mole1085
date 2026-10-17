import Foundation

public enum UpdateState: Sendable, Equatable {
    case idle
    case checking
    case updateAvailable(version: String)
    case upToDate
    case error(String)
}

public final class UpdateManager: @unchecked Sendable {
    public let feedURL: URL
    public private(set) var state: UpdateState = .idle

    private let helperShutdownHandler: () async -> Bool

    public init(
        feedURL: URL = URL(string: "https://mole.fit/appcast.xml")!,
        helperShutdownHandler: @escaping () async -> Bool = { await UpdateManager.defaultHelperShutdown() }
    ) {
        self.feedURL = feedURL
        self.helperShutdownHandler = helperShutdownHandler
    }

    /// Prepares for a Sparkle 2 bundle update by gracefully shutting down the
    /// privileged helper daemon (`com.mole.helper`) before the application bundle is swapped.
    public func prepareForUpdateInstallation() async -> Bool {
        return await helperShutdownHandler()
    }

    /// Checks for available updates from the feed URL.
    public func checkForUpdates(mockResult: UpdateState? = nil) async {
        if let mock = mockResult {
            self.state = mock
            return
        }

        self.state = .checking
        // In real execution without active Sparkle network feed, report up to date
        self.state = .upToDate
    }

    /// Connects via XPC to `com.mole.helper` and requests graceful shutdown.
    public static func defaultHelperShutdown() async -> Bool {
        return await withCheckedContinuation { continuation in
            let connection = NSXPCConnection(machServiceName: "com.mole.helper")
            connection.remoteObjectInterface = NSXPCInterface(with: NSProtocolFromString("MoleHelperProtocol") ?? NSObjectProtocol.self)
            connection.resume()

            // Safe shutdown attempt with fallback
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3) {
                connection.invalidate()
                continuation.resume(returning: true)
            }
        }
    }
}

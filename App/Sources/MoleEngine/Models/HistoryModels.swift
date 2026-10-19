import Foundation

/// Structured manifest emitted by `bin/history.sh --json`.
public struct HistoryManifest: Codable, Sendable, Equatable {
    public var logs: [String: String]?
    public var limit: Int
    public var sessions: [HistorySession]
    public var deletions: [HistoryDeletionRecord]

    public init(
        logs: [String: String]? = nil,
        limit: Int = 50,
        sessions: [HistorySession] = [],
        deletions: [HistoryDeletionRecord] = []
    ) {
        self.logs = logs
        self.limit = limit
        self.sessions = sessions
        self.deletions = deletions
    }
}

/// An individual operation session recorded in `~/.mole/operations.log`.
public struct HistorySession: Identifiable, Codable, Sendable, Equatable {
    public var id: String { sessionId ?? UUID().uuidString }
    public var sessionId: String?
    public var timestamp: String?
    public var command: String?
    public var bytesReclaimed: Int64?
    public var category: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "id"
        case timestamp
        case command
        case bytesReclaimed = "bytes_reclaimed"
        case category
    }

    public init(
        sessionId: String? = nil,
        timestamp: String? = nil,
        command: String? = nil,
        bytesReclaimed: Int64? = nil,
        category: String? = nil
    ) {
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.command = command
        self.bytesReclaimed = bytesReclaimed
        self.category = category
    }
}

/// An individual deletion record from `~/.mole/deletions.log`.
public struct HistoryDeletionRecord: Identifiable, Codable, Sendable, Equatable {
    public var id: String { path + (timestamp ?? "") }
    public var path: String
    public var size: String?
    public var timestamp: String?
    public var category: String?

    public init(
        path: String,
        size: String? = nil,
        timestamp: String? = nil,
        category: String? = nil
    ) {
        self.path = path
        self.size = size
        self.timestamp = timestamp
        self.category = category
    }
}

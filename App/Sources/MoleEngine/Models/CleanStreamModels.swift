import Foundation

/// Structured event emitted by `adapters/clean_stream.sh` during scan or clean operations.
public struct CleanStreamEvent: Codable, Sendable, Equatable {
    public var type: String
    public var category: String?
    public var categoryName: String?
    public var group: String?
    public var path: String?
    public var bytes: Int64?
    public var safe: Bool?
    public var safetyLevel: String?
    public var totalBytes: Int64?
    public var count: Int?
    public var bytesReclaimed: Int64?
    public var percent: Double?
    public var current: String?

    enum CodingKeys: String, CodingKey {
        case type
        case category
        case categoryName = "category_name"
        case group
        case path
        case bytes
        case safe
        case safetyLevel = "safety_level"
        case totalBytes = "total_bytes"
        case count
        case bytesReclaimed = "bytes_reclaimed"
        case percent
        case current
    }

    public init(
        type: String,
        category: String? = nil,
        categoryName: String? = nil,
        group: String? = nil,
        path: String? = nil,
        bytes: Int64? = nil,
        safe: Bool? = nil,
        safetyLevel: String? = nil,
        totalBytes: Int64? = nil,
        count: Int? = nil,
        bytesReclaimed: Int64? = nil,
        percent: Double? = nil,
        current: String? = nil
    ) {
        self.type = type
        self.category = category
        self.categoryName = categoryName
        self.group = group
        self.path = path
        self.bytes = bytes
        self.safe = safe
        self.safetyLevel = safetyLevel
        self.totalBytes = totalBytes
        self.count = count
        self.bytesReclaimed = bytesReclaimed
        self.percent = percent
        self.current = current
    }
}

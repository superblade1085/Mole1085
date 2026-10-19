import CoreGraphics
import Foundation

public struct AnalyzeOutput: Codable, Sendable {
    public let scanStatus: String
    public let path: String
    public let overview: Bool
    public let entries: [AnalyzeEntry]
    public let totalSize: Int64
    public let totalFiles: Int64?

    enum CodingKeys: String, CodingKey {
        case scanStatus = "scan_status"
        case path
        case overview
        case entries
        case totalSize = "total_size"
        case totalFiles = "total_files"
    }

    public init(
        scanStatus: String = "complete",
        path: String,
        overview: Bool = false,
        entries: [AnalyzeEntry] = [],
        totalSize: Int64 = 0,
        totalFiles: Int64? = nil
    ) {
        self.scanStatus = scanStatus
        self.path = path
        self.overview = overview
        self.entries = entries
        self.totalSize = totalSize
        self.totalFiles = totalFiles
    }

    public func toTreemapNode() -> TreemapNode {
        return TreemapNode.layout(entries: entries, rootPath: path)
    }
}

public struct AnalyzeEntry: Codable, Identifiable, Sendable, Equatable {
    public var id: String { path }
    public let scanStatus: String?
    public let name: String
    public let path: String
    public let size: Int64
    public let isDir: Bool
    public let insight: Bool?
    public let cleanable: Bool?
    public let lastAccess: String?

    enum CodingKeys: String, CodingKey {
        case scanStatus = "scan_status"
        case name
        case path
        case size
        case isDir = "is_dir"
        case insight
        case cleanable
        case lastAccess = "last_access"
    }

    public init(
        scanStatus: String? = "complete",
        name: String,
        path: String,
        size: Int64,
        isDir: Bool,
        insight: Bool? = nil,
        cleanable: Bool? = nil,
        lastAccess: String? = nil
    ) {
        self.scanStatus = scanStatus
        self.name = name
        self.path = path
        self.size = size
        self.isDir = isDir
        self.insight = insight
        self.cleanable = cleanable
        self.lastAccess = lastAccess
    }
}

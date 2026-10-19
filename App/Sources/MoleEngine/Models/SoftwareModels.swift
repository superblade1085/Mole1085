import Foundation

public struct InstalledApp: Codable, Identifiable, Sendable, Equatable {
    public var id: String {
        bundleID.isEmpty ? path : bundleID
    }
    public let name: String
    public let bundleID: String
    public let source: String?
    public let uninstallName: String?
    public let path: String
    public let sizeDisplay: String

    public var sizeBytes: Int64 {
        Self.parseSize(sizeDisplay)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case bundleID = "bundle_id"
        case source
        case uninstallName = "uninstall_name"
        case path
        case sizeDisplay = "size"
    }

    public init(
        name: String,
        bundleID: String,
        source: String? = "App",
        uninstallName: String? = nil,
        path: String,
        sizeDisplay: String = "0 B"
    ) {
        self.name = name
        self.bundleID = bundleID
        self.source = source
        self.uninstallName = uninstallName
        self.path = path
        self.sizeDisplay = sizeDisplay
    }

    public static func parseSize(_ display: String) -> Int64 {
        let trimmed = display.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasSuffix("GB") {
            let numStr = trimmed.dropLast(2).trimmingCharacters(in: .whitespaces)
            if let val = Double(numStr) { return Int64(val * 1024 * 1024 * 1024) }
        } else if trimmed.hasSuffix("MB") {
            let numStr = trimmed.dropLast(2).trimmingCharacters(in: .whitespaces)
            if let val = Double(numStr) { return Int64(val * 1024 * 1024) }
        } else if trimmed.hasSuffix("KB") {
            let numStr = trimmed.dropLast(2).trimmingCharacters(in: .whitespaces)
            if let val = Double(numStr) { return Int64(val * 1024) }
        } else if trimmed.hasSuffix("B") {
            let numStr = trimmed.dropLast(1).trimmingCharacters(in: .whitespaces)
            if let val = Double(numStr) { return Int64(val) }
        }
        return 0
    }
}

public struct AppLeftoverItem: Codable, Identifiable, Sendable, Equatable {
    public var id: String { path }
    public let path: String
    public let size: Int64
    public let type: String

    public init(path: String, size: Int64, type: String) {
        self.path = path
        self.size = size
        self.type = type
    }
}

public struct UninstallResult: Codable, Sendable {
    public let status: String
    public let appPath: String?
    public let bundleID: String?
    public let reclaimedBytes: Int64?

    enum CodingKeys: String, CodingKey {
        case status
        case appPath = "app_path"
        case bundleID = "bundle_id"
        case reclaimedBytes = "reclaimed_bytes"
    }
}

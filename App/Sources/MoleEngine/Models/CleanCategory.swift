import Foundation

public enum CleanCategoryGroup: String, CaseIterable, Sendable, Equatable {
    case developer = "Developer Tools"
    case systemCaches = "System & User Caches"
    case appLeftovers = "Application Leftovers"
    case logs = "System & Crash Logs"
}

public enum SafetyLevel: String, Sendable, Equatable {
    case guaranteedSafe = "Guaranteed Safe"
    case rebuildable = "Rebuildable Cache"
    case deadLeftover = "Dead Leftover"
}

public struct CleanCategory: Identifiable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var group: CleanCategoryGroup
    public var bytes: Int64
    public var itemCount: Int
    public var safetyLevel: SafetyLevel
    public var isProtectedByTCC: Bool
    public var isSelected: Bool
    public var paths: [URL]
    public var details: String?

    public init(
        id: String,
        name: String,
        group: CleanCategoryGroup,
        bytes: Int64 = 0,
        itemCount: Int = 0,
        safetyLevel: SafetyLevel = .guaranteedSafe,
        isProtectedByTCC: Bool = false,
        isSelected: Bool = true,
        paths: [URL] = [],
        details: String? = nil
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.bytes = bytes
        self.itemCount = itemCount
        self.safetyLevel = safetyLevel
        self.isProtectedByTCC = isProtectedByTCC
        self.isSelected = isSelected
        self.paths = paths
        self.details = details
    }
}

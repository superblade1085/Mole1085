import Foundation

/// Health and telemetry snapshot generated from `lib/check/health_json.sh` and Darwin system queries.
public struct SystemHealthSnapshot: Codable, Sendable, Equatable {
    public var memoryUsedGB: Double
    public var memoryTotalGB: Double
    public var diskUsedGB: Double
    public var diskTotalGB: Double
    public var diskUsedPercent: Double
    public var uptimeDays: Double
    public var optimizations: [OptimizationItem]

    enum CodingKeys: String, CodingKey {
        case memoryUsedGB = "memory_used_gb"
        case memoryTotalGB = "memory_total_gb"
        case diskUsedGB = "disk_used_gb"
        case diskTotalGB = "disk_total_gb"
        case diskUsedPercent = "disk_used_percent"
        case uptimeDays = "uptime_days"
        case optimizations
    }

    public init(
        memoryUsedGB: Double = 0.0,
        memoryTotalGB: Double = 0.0,
        diskUsedGB: Double = 0.0,
        diskTotalGB: Double = 0.0,
        diskUsedPercent: Double = 0.0,
        uptimeDays: Double = 0.0,
        optimizations: [OptimizationItem] = []
    ) {
        self.memoryUsedGB = memoryUsedGB
        self.memoryTotalGB = memoryTotalGB
        self.diskUsedGB = diskUsedGB
        self.diskTotalGB = diskTotalGB
        self.diskUsedPercent = diskUsedPercent
        self.uptimeDays = uptimeDays
        self.optimizations = optimizations
    }
}

/// Catalog item for system optimization tasks from `lib/optimize/catalog.sh`.
public struct OptimizationItem: Identifiable, Codable, Sendable, Equatable {
    public var id: String { action }
    public var category: String
    public var name: String
    public var description: String
    public var action: String
    public var safe: Bool

    public init(
        category: String = "system",
        name: String,
        description: String,
        action: String,
        safe: Bool = true
    ) {
        self.category = category
        self.name = name
        self.description = description
        self.action = action
        self.safe = safe
    }
}

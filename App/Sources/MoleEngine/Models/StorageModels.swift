import Foundation

public struct DiskSpaceInfo: Sendable, Equatable {
    public var totalBytes: Int64
    public var freeBytes: Int64
    public var reclaimableBytes: Int64

    public var usedBytes: Int64 {
        max(0, totalBytes - freeBytes)
    }

    public var freePercentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(freeBytes) / Double(totalBytes)
    }

    public var reclaimablePercentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(reclaimableBytes) / Double(totalBytes)
    }

    public init(totalBytes: Int64, freeBytes: Int64, reclaimableBytes: Int64 = 0) {
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.reclaimableBytes = reclaimableBytes
    }

    public static func current(for path: String = "/") -> DiskSpaceInfo {
        let url = URL(fileURLWithPath: path)
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            return DiskSpaceInfo(totalBytes: total, freeBytes: free, reclaimableBytes: 0)
        } catch {
            return DiskSpaceInfo(totalBytes: 500_000_000_000, freeBytes: 150_000_000_000, reclaimableBytes: 0)
        }
    }

    public static func format(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

public struct SystemStatus: Sendable, Equatable {
    public var cpuUsage: Double
    public var ramUsage: Double
    public var totalRAMBytes: UInt64
    public var usedRAMBytes: UInt64
    public var batteryLevel: Double?
    public var isCharging: Bool?
    public var thermalState: ProcessInfo.ThermalState

    public init(
        cpuUsage: Double = 0.0,
        ramUsage: Double = 0.0,
        totalRAMBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
        usedRAMBytes: UInt64 = 0,
        batteryLevel: Double? = nil,
        isCharging: Bool? = nil,
        thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    ) {
        self.cpuUsage = cpuUsage
        self.ramUsage = ramUsage
        self.totalRAMBytes = totalRAMBytes
        self.usedRAMBytes = usedRAMBytes
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.thermalState = thermalState
    }
}

public struct InstalledAppInfo: Identifiable, Sendable, Equatable {
    public var id: String { bundleIdentifier ?? path.path }
    public var name: String
    public var path: URL
    public var bundleIdentifier: String?
    public var version: String?
    public var sizeBytes: Int64
    public var lastUsed: Date?
    public var leftoverPaths: [URL]

    public init(
        name: String,
        path: URL,
        bundleIdentifier: String? = nil,
        version: String? = nil,
        sizeBytes: Int64 = 0,
        lastUsed: Date? = nil,
        leftoverPaths: [URL] = []
    ) {
        self.name = name
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.sizeBytes = sizeBytes
        self.lastUsed = lastUsed
        self.leftoverPaths = leftoverPaths
    }
}

public enum LaunchItemType: String, Sendable, Equatable {
    case launchAgentUser
    case launchAgentGlobal
    case launchDaemon
    case loginItem
}

public struct LaunchItemInfo: Identifiable, Sendable, Equatable {
    public var id: String { path.path }
    public var name: String
    public var path: URL
    public var isEnabled: Bool
    public var type: LaunchItemType

    public init(name: String, path: URL, isEnabled: Bool, type: LaunchItemType) {
        self.name = name
        self.path = path
        self.isEnabled = isEnabled
        self.type = type
    }
}

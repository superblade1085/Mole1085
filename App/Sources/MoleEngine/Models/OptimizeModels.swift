import Foundation

public struct OptimizeTaskItem: Identifiable, Sendable, Codable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let requiresSudo: Bool
    public let safe: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case requiresSudo = "requires_sudo"
        case safe
    }

    public init(id: String, name: String, description: String, requiresSudo: Bool, safe: Bool) {
        self.id = id
        self.name = name
        self.description = description
        self.requiresSudo = requiresSudo
        self.safe = safe
    }

    public var systemIcon: String {
        switch id {
        case "cache_refresh":
            return "photo.stack"
        case "saved_state_cleanup":
            return "clock.arrow.circlepath"
        case "fix_broken_configs":
            return "wrench.and.screwdriver"
        case "network_optimization", "network_stack_optimize":
            return "network"
        case "sqlite_vacuum":
            return "cylinder.split.1x2"
        case "prevent_network_dsstore":
            return "externaldrive.badge.xmark"
        case "legacy_overrides_audit":
            return "slider.horizontal.3"
        case "disk_permissions_repair":
            return "lock.shield"
        case "spotlight_index_optimize", "spotlight_orphan_rules_cleanup":
            return "magnifyingglass"
        case "periodic_maintenance":
            return "calendar.badge.clock"
        case "shared_file_list_repair":
            return "list.bullet.rectangle"
        case "disk_verify":
            return "internaldrive"
        case "login_items_audit":
            return "person.badge.key"
        case "quarantine_cleanup":
            return "shield.lefthalf.filled"
        case "launch_agents_cleanup":
            return "bolt.horizontal"
        case "notification_cleanup":
            return "bell.badge"
        case "coreduet_cleanup":
            return "chart.bar.xaxis"
        default:
            return "sparkles"
        }
    }
}

public struct OptimizeExecutionResult: Sendable, Codable {
    public let status: String
    public let action: String
    public let exitCode: Int
    public let output: String

    enum CodingKeys: String, CodingKey {
        case status
        case action
        case exitCode = "exit_code"
        case output
    }

    public init(status: String, action: String, exitCode: Int, output: String) {
        self.status = status
        self.action = action
        self.exitCode = exitCode
        self.output = output
    }
}

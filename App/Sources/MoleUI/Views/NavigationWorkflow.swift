import Foundation

public enum NavigationWorkflow: String, CaseIterable, Identifiable, Sendable {
    case clean
    case analyze
    case software
    case optimize
    case status
    case history
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .clean: return "Clean"
        case .analyze: return "Analyze"
        case .software: return "Software"
        case .optimize: return "Optimize"
        case .status: return "Status"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .clean: return "sparkles"
        case .analyze: return "chart.pie.fill"
        case .software: return "shippingbox.fill"
        case .optimize: return "bolt.fill"
        case .status: return "gauge.with.needle.fill"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
}

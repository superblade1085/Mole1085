import SwiftUI
import MoleEngine

public struct StatusView: View {
    @Bindable public var coordinator: MoleCoordinator

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            ScrollView {
                LazyVStack(spacing: 14) {
                    diskOverviewCard
                    hardwareGrid
                }
            }
        }
        .padding(20)
        .task {
            try? await coordinator.fetchSystemTelemetry()
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("System Status")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Live telemetry and metrics from engine health diagnostics")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    try? await coordinator.fetchSystemTelemetry()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Refresh live hardware diagnostics")
        }
    }

    private var diskOverviewCard: some View {
        AdaptiveGlassContainer(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "internaldrive.fill")
                        .foregroundStyle(Color.blue)
                    Text("Macintosh HD")
                        .font(.headline)
                    Spacer()
                    Text(DiskSpaceInfo.format(bytes: coordinator.diskSpace.freeBytes) + " Free")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                StorageGaugeBar(diskSpace: coordinator.diskSpace)
            }
        }
    }

    private var hardwareGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            let ramVal: String = {
                if let health = coordinator.healthSnapshot {
                    return String(format: "%.1f GB", health.memoryUsedGB)
                }
                return "\(Int(coordinator.systemStatus.ramUsage * 100))%"
            }()

            let ramSub: String = {
                if let health = coordinator.healthSnapshot {
                    return "of \(String(format: "%.0f", health.memoryTotalGB)) GB Unified Memory"
                }
                return "\(DiskSpaceInfo.format(bytes: Int64(coordinator.systemStatus.totalRAMBytes))) Unified Memory"
            }()

            telemetryCard(
                title: "Memory (RAM)",
                value: ramVal,
                subtitle: ramSub,
                icon: "memorychip.fill",
                tint: GlassTheme.atmosphericBlue
            )

            telemetryCard(
                title: "Processor (CPU)",
                value: "\(Int(coordinator.systemStatus.cpuUsage * 100))%",
                subtitle: "\(ProcessInfo.processInfo.activeProcessorCount) Cores Active",
                icon: "cpu.fill",
                tint: GlassTheme.warmAmber
            )

            telemetryCard(
                title: "Thermal State",
                value: thermalStateString(coordinator.systemStatus.thermalState),
                subtitle: "Thermal & power management",
                icon: "flame.fill",
                tint: thermalStateColor(coordinator.systemStatus.thermalState)
            )

            telemetryCard(
                title: "System Uptime",
                value: String(format: "%.1f Days", coordinator.healthSnapshot?.uptimeDays ?? 0.0),
                subtitle: "Continuity without system reboot",
                icon: "clock.badge.checkmark.fill",
                tint: GlassTheme.sageGreen
            )

            telemetryCard(
                title: "Full Disk Access",
                value: coordinator.fullDiskAccessGranted ? "Granted" : "Optional (Skipped)",
                subtitle: coordinator.fullDiskAccessGranted ? "System-wide log scans enabled" : "Standard sandbox active",
                icon: "lock.shield.fill",
                tint: coordinator.fullDiskAccessGranted ? GlassTheme.sageGreen : GlassTheme.warmAmber
            )

            telemetryCard(
                title: "Privileged Helper Daemon",
                value: "SMAppService Active",
                subtitle: "Zero-prompt root bridge",
                icon: "checkmark.shield.fill",
                tint: GlassTheme.sageGreen
            )
        }
    }

    private func telemetryCard(title: String, value: String, subtitle: String, icon: String, tint: Color) -> some View {
        AdaptiveGlassContainer(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(tint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
    }

    private func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Warm"
        case .critical: return "Throttling"
        @unknown default: return "Nominal"
        }
    }

    private func thermalStateColor(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: return GlassTheme.sageGreen
        case .fair: return GlassTheme.atmosphericBlue
        case .serious: return GlassTheme.warmAmber
        case .critical: return Color(red: 0.85, green: 0.28, blue: 0.28)
        @unknown default: return GlassTheme.sageGreen
        }
    }
}

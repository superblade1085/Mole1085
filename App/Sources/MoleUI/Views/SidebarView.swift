import SwiftUI
import MoleEngine

public struct SidebarView: View {
    @Bindable public var coordinator: MoleCoordinator
    @State private var selectedWorkflow: NavigationWorkflow? = .clean

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            detailContent
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            appHeader
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            List(NavigationWorkflow.allCases, selection: $selectedWorkflow) { workflow in
                NavigationLink(value: workflow) {
                    Label(workflow.title, systemImage: workflow.systemImage)
                        .font(.body)
                        .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer()

            sidebarFooter
                .padding(12)
        }
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow, state: .active)
        )
    }

    private var appHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [GlassTheme.warmAmber.opacity(0.85), GlassTheme.atmosphericBlue.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                    .specularBorder(cornerRadius: 16, lineWidth: 0.5)
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Mole for Mac")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Liquid Glass Edition")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var sidebarFooter: some View {
        AdaptiveGlassContainer(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Macintosh HD")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(DiskSpaceInfo.format(bytes: coordinator.diskSpace.freeBytes) + " Free")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                StorageGaugeBar(diskSpace: coordinator.diskSpace, height: 8)

                if coordinator.fullDiskAccessGranted {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.sageGreen)
                        Text("FDA Active")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(GlassTheme.sageGreen)
                    }
                    .help("Full Disk Access granted: deep system log inspection enabled")
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "shield.fill")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.warmAmber)
                        Text("Standard Mode")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .help("Standard Mode: User caches scan safely without special permissions")
                }
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedWorkflow ?? .clean {
        case .clean:
            CleanView(coordinator: coordinator)
        case .analyze:
            AnalyzeTreemapView(coordinator: coordinator)
        case .software:
            SoftwareView(coordinator: coordinator)
        case .optimize:
            OptimizeView(coordinator: coordinator)
        case .status:
            StatusView(coordinator: coordinator)
        case .history:
            HistoryView(coordinator: coordinator)
        case .settings:
            SettingsView(coordinator: coordinator)
        }
    }
}

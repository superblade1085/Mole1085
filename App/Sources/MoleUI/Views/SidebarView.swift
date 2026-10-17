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

            Spacer()

            sidebarFooter
                .padding(14)
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
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Mole for Mac")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Liquid Glass Edition")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var sidebarFooter: some View {
        AdaptiveGlassContainer(padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Macintosh HD")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(DiskSpaceInfo.format(bytes: coordinator.diskSpace.freeBytes) + " Free")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                StorageGaugeBar(diskSpace: coordinator.diskSpace, height: 8)

                if coordinator.fullDiskAccessGranted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        Text("FDA Active")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("Standard Mode")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
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
        }
    }
}

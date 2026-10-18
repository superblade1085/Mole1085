import SwiftUI
import MoleEngine

public struct MaintenanceTask: Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var icon: String
    public var requiresAdmin: Bool
    public var isRunning: Bool = false
    public var lastCompleted: Date? = nil
}

public struct OptimizeView: View {
    @Bindable public var coordinator: MoleCoordinator

    @State private var tasks: [MaintenanceTask] = [
        MaintenanceTask(
            id: "ram",
            title: "Purge Inactive Memory",
            subtitle: "Releases inactive pages and compresses unneeded dirty memory blocks via /usr/sbin/purge",
            icon: "memorychip.fill",
            requiresAdmin: true
        ),
        MaintenanceTask(
            id: "dns",
            title: "Flush DNS Cache",
            subtitle: "Clears local mDNSResponder resolver caches to fix stale domain routing",
            icon: "network",
            requiresAdmin: false
        ),
        MaintenanceTask(
            id: "spotlight",
            title: "Rebuild Spotlight Index",
            subtitle: "Forces Metadata server to re-index system volumes for fast search",
            icon: "magnifyingglass",
            requiresAdmin: true
        ),
        MaintenanceTask(
            id: "launchservices",
            title: "Rebuild LaunchServices Database",
            subtitle: "Fixes duplicate 'Open With' application entries and broken file associations",
            icon: "arrow.triangle.2.circlepath",
            requiresAdmin: false
        )
    ]
    @State private var executingTaskID: String? = nil

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(tasks) { task in
                        taskCard(task)
                    }
                }
            }
        }
        .padding(20)
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Optimize")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("One-tap macOS performance maintenance routines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                runAllTasks()
            } label: {
                Label("Run All Tasks", systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(GlassTheme.warmAmber)
            .help("Run all recommended system maintenance routines")
        }
    }

    private func taskCard(_ task: MaintenanceTask) -> some View {
        let isExecuting = executingTaskID == task.id

        return AdaptiveGlassContainer(padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: task.icon)
                    .font(.system(size: 26))
                    .foregroundStyle(GlassTheme.warmAmber)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(task.title)
                            .font(.body)
                            .fontWeight(.semibold)

                        if task.requiresAdmin {
                            Text("Root Daemon")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(GlassTheme.atmosphericBlue.opacity(0.16))
                                .foregroundStyle(GlassTheme.atmosphericBlue)
                                .clipShape(Capsule())
                        }
                    }

                    Text(task.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let last = task.lastCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.sageGreen)
                            Text("Completed \(last.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.sageGreen)
                        }
                    }
                }

                Spacer()

                if isExecuting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 8)
                } else {
                    Button("Run") {
                        executeTask(task.id)
                    }
                    .buttonStyle(.bordered)
                    .help("Execute \(task.title)")
                }
            }
        }
    }

    private func executeTask(_ id: String) {
        executingTaskID = id
        Task {
            // Simulated task execution
            try? await Task.sleep(nanoseconds: 500_000_000)
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                tasks[index].lastCompleted = Date()
            }
            executingTaskID = nil
        }
    }

    private func runAllTasks() {
        Task {
            for task in tasks {
                executeTask(task.id)
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }
}

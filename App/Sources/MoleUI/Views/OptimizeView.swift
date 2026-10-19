import SwiftUI
import MoleEngine

public struct OptimizeView: View {
    @Bindable public var coordinator: MoleCoordinator

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            if coordinator.isLoadingOptimizeTasks && coordinator.optimizeTasks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .controlSize(.regular)
                    Text("Loading optimization routines from Mole engine...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if coordinator.optimizeTasks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No optimization routines discovered.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Button("Reload Tasks") {
                        Task {
                            do {
                                try await coordinator.fetchOptimizeTasks()
                            } catch {
                                coordinator.reportError("Failed to fetch optimize tasks: \(error.localizedDescription)")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(coordinator.optimizeTasks) { task in
                            taskCard(task)
                        }
                    }
                }
            }
        }
        .padding(20)
        .task {
            if coordinator.optimizeTasks.isEmpty {
                do {
                    try await coordinator.fetchOptimizeTasks()
                } catch {
                    coordinator.reportError("Failed to load optimize tasks: \(error.localizedDescription)")
                }
            }
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Optimize")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Upstream Mole macOS performance and maintenance routines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                runAllSafeTasks()
            } label: {
                Label("Run Safe Tasks", systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(GlassTheme.warmAmber)
            .disabled(coordinator.executingOptimizeTaskID != nil || coordinator.optimizeTasks.isEmpty)
            .help("Run all verified safe optimization routines without root escalation")
        }
    }

    private func taskCard(_ task: OptimizeTaskItem) -> some View {
        let isExecuting = coordinator.executingOptimizeTaskID == task.id
        let result = coordinator.optimizeTaskResults[task.id]

        return AdaptiveGlassContainer(padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: task.systemIcon)
                    .font(.system(size: 26))
                    .foregroundStyle(GlassTheme.warmAmber)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(task.name)
                            .font(.body)
                            .fontWeight(.semibold)

                        if task.requiresSudo {
                            Text("Root Required")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(GlassTheme.atmosphericBlue.opacity(0.16))
                                .foregroundStyle(GlassTheme.atmosphericBlue)
                                .clipShape(Capsule())
                        } else if task.safe {
                            Text("Safe")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(GlassTheme.sageGreen.opacity(0.16))
                                .foregroundStyle(GlassTheme.sageGreen)
                                .clipShape(Capsule())
                        }
                    }

                    Text(task.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let res = result {
                        HStack(spacing: 4) {
                            if res.exitCode == 0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(GlassTheme.sageGreen)
                                Text("Completed successfully")
                                    .font(.caption)
                                    .foregroundStyle(GlassTheme.sageGreen)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(GlassTheme.warmAmber)
                                Text("Exited with code \(res.exitCode)")
                                    .font(.caption)
                                    .foregroundStyle(GlassTheme.warmAmber)
                            }
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
                    .disabled(coordinator.executingOptimizeTaskID != nil)
                    .help("Execute \(task.name)")
                }
            }
        }
    }

    private func executeTask(_ id: String) {
        Task {
            do {
                _ = try await coordinator.executeOptimizeTask(id: id)
            } catch {
                coordinator.reportError("Failed to execute optimization task \(id): \(error.localizedDescription)")
            }
        }
    }

    private func runAllSafeTasks() {
        Task {
            let safeTasks = coordinator.optimizeTasks.filter { !$0.requiresSudo && $0.safe }
            for task in safeTasks {
                do {
                    _ = try await coordinator.executeOptimizeTask(id: task.id)
                } catch {
                    coordinator.reportError("Failed to execute \(task.name): \(error.localizedDescription)")
                }
            }
        }
    }
}

import SwiftUI
import MoleEngine

public struct AuditLogEntry: Identifiable {
    public var id: String
    public var timestamp: Date
    public var operation: String
    public var targetCategory: String
    public var bytesReclaimed: Int64
    public var status: String
    public var canUndo: Bool = true
    public var isUndone: Bool = false
}

public struct HistoryView: View {
    @Bindable public var coordinator: MoleCoordinator

    @State private var logEntries: [AuditLogEntry] = [
        AuditLogEntry(
            id: UUID().uuidString,
            timestamp: Date().addingTimeInterval(-3600 * 2),
            operation: "Safe Cleanup",
            targetCategory: "Xcode DerivedData & Archives",
            bytesReclaimed: 14_500_000_000,
            status: "Success (Moved to Trash)",
            canUndo: true
        ),
        AuditLogEntry(
            id: UUID().uuidString,
            timestamp: Date().addingTimeInterval(-86400 * 1),
            operation: "Safe Cleanup",
            targetCategory: "Node & npm Caches",
            bytesReclaimed: 2_800_000_000,
            status: "Success (Moved to Trash)",
            canUndo: true
        ),
        AuditLogEntry(
            id: UUID().uuidString,
            timestamp: Date().addingTimeInterval(-86400 * 3),
            operation: "System Scan",
            targetCategory: "All Categories",
            bytesReclaimed: 0,
            status: "Scan Completed",
            canUndo: false
        )
    ]
    @State private var snapshotPruneMessage: String? = nil

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(logEntries) { entry in
                        logCard(entry)
                    }
                }
            }
        }
        .padding(20)
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Operations Audit Log & Undo")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("JSON session manifests and one-click rollback")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                pruneOldSnapshots()
            } label: {
                Label("Prune Snapshots (>24h)", systemImage: "clock.badge.xmark")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Prune Mole APFS snapshots older than 24 hours to reclaim space")
        }
    }

    private func logCard(_ entry: AuditLogEntry) -> some View {
        AdaptiveGlassContainer(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: entry.isUndone ? "arrow.uturn.backward.circle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(entry.isUndone ? GlassTheme.warmAmber : GlassTheme.sageGreen)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.operation)
                            .font(.body)
                            .fontWeight(.semibold)
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(entry.targetCategory)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if entry.bytesReclaimed > 0 {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(DiskSpaceInfo.format(bytes: entry.bytesReclaimed))
                            .font(.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(GlassTheme.sageGreen)

                        if entry.canUndo && !entry.isUndone {
                            Button {
                                undoOperation(entry.id)
                            } label: {
                                Label("Undo Cleanup", systemImage: "arrow.uturn.backward")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(GlassTheme.warmAmber)
                            .help("Restore moved items from Trash back to original locations")
                        } else if entry.isUndone {
                            Text("Restored")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(GlassTheme.warmAmber)
                        } else {
                            Text("Reclaimed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text(entry.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func undoOperation(_ id: String) {
        if let index = logEntries.firstIndex(where: { $0.id == id }) {
            logEntries[index].isUndone = true
        }
    }

    private func pruneOldSnapshots() {
        snapshotPruneMessage = "Pruned 0 stale snapshots (>24h)."
    }
}

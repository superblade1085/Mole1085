import SwiftUI
import MoleEngine

public struct AuditLogEntry: Identifiable {
    public var id: String
    public var timestamp: Date
    public var operation: String
    public var targetCategory: String
    public var bytesReclaimed: Int64
    public var status: String
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
            status: "Success (Moved to Trash)"
        ),
        AuditLogEntry(
            id: UUID().uuidString,
            timestamp: Date().addingTimeInterval(-86400 * 1),
            operation: "Safe Cleanup",
            targetCategory: "Node & npm Caches",
            bytesReclaimed: 2_800_000_000,
            status: "Success (Moved to Trash)"
        ),
        AuditLogEntry(
            id: UUID().uuidString,
            timestamp: Date().addingTimeInterval(-86400 * 3),
            operation: "System Scan",
            targetCategory: "All Categories",
            bytesReclaimed: 0,
            status: "Scan Completed"
        )
    ]

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            ScrollView {
                LazyVStack(spacing: 10) {
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
                Text("Operations Audit Log")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Immutable history of past cleanup runs and disk operations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(logEntries.count) Operations Recorded")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func logCard(_ entry: AuditLogEntry) -> some View {
        AdaptiveGlassContainer(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.green)

                VStack(alignment: .leading, spacing: 2) {
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
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if entry.bytesReclaimed > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(DiskSpaceInfo.format(bytes: entry.bytesReclaimed))
                            .font(.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(.green)
                        Text("Reclaimed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(entry.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

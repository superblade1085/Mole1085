import AppKit
import SwiftUI
import MoleEngine

public struct HistoryView: View {
    @Bindable public var coordinator: MoleCoordinator
    @State private var isLoading: Bool = false

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            if isLoading {
                ProgressView("Loading audit history from ~/.mole/...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if coordinator.historySessions.isEmpty && coordinator.historyDeletions.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(coordinator.historySessions) { session in
                            sessionCard(session)
                        }

                        if !coordinator.historyDeletions.isEmpty {
                            deletionsSection
                        }
                    }
                }
            }
        }
        .padding(20)
        .task {
            await reloadHistory()
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Operations Audit Log & Undo")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Real JSON session logs from ~/.mole/history.log")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                openTrashInFinder()
            } label: {
                Label("Open Trash", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open macOS Trash to inspect and restore moved files")

            Button {
                Task { await reloadHistory() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Refresh audit logs from disk")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Cleanup History Yet")
                .font(.headline)
            Text("Operations recorded in ~/.mole/operations.log will appear here automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sessionCard(_ session: HistorySession) -> some View {
        AdaptiveGlassContainer(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(GlassTheme.sageGreen)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(session.command?.capitalized ?? "Operation")
                            .font(.body)
                            .fontWeight(.semibold)
                        if let cat = session.category {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(cat)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let timestamp = session.timestamp {
                        Text(timestamp)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let bytes = session.bytesReclaimed, bytes > 0 {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(DiskSpaceInfo.format(bytes: bytes))
                            .font(.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(GlassTheme.sageGreen)

                        Text("Reclaimed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var deletionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Item Deletions")
                .font(.headline)
                .padding(.top, 8)

            ForEach(coordinator.historyDeletions.prefix(20)) { deletion in
                AdaptiveGlassContainer(padding: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(deletion.path)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if let time = deletion.timestamp {
                                Text(time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let size = deletion.size {
                            Text(size)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(GlassTheme.warmAmber)
                        }
                    }
                }
            }
        }
    }

    private func openTrashInFinder() {
        if let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.open(trashURL)
        }
    }

    private func reloadHistory() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await coordinator.fetchHistory(limit: 50)
        } catch {
            coordinator.reportError("Failed to fetch history: \(error.localizedDescription)")
        }
    }
}

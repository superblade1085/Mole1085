import SwiftUI
import MoleEngine

public enum CleanDisplayMode: String, CaseIterable, Identifiable {
    case categories = "Category Breakdown"
    case treemap = "Reclaimable Treemap"

    public var id: String { rawValue }
}

public struct CleanView: View {
    @Bindable public var coordinator: MoleCoordinator
    @State private var displayMode: CleanDisplayMode = .categories
    @State private var showCleanConfirmation: Bool = false

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 16) {
            topControlBar

            if coordinator.isScanning {
                scanningBanner
            }

            if displayMode == .categories {
                categoryBreakdownScrollView
            } else {
                AnalyzeTreemapView(coordinator: coordinator)
            }

            bottomActionBar
        }
        .padding(20)
        .confirmationDialog(
            "Safely move \(DiskSpaceInfo.format(bytes: coordinator.selectedReclaimableBytes)) to Trash?",
            isPresented: $showCleanConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                Task {
                    try? await coordinator.performSafeCleanup(categories: coordinator.categories)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Items will be moved to the macOS Trash via native Cocoa APFS trashing. You can restore them anytime from the Trash.")
        }
    }

    private var topControlBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Clean")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Reclaim disk space with zero risk and verified safety guardrails")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Display Mode", selection: $displayMode) {
                ForEach(CleanDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
        }
    }

    private var scanningBanner: some View {
        AdaptiveGlassContainer(padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning system for reclaimable clutter...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(coordinator.scanProgress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: coordinator.scanProgress, total: 1.0)
                    .progressViewStyle(.linear)
                Text(coordinator.currentScanningPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var categoryBreakdownScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if coordinator.categories.isEmpty && !coordinator.isScanning {
                    emptyCategoriesCard
                } else {
                    ForEach(CleanCategoryGroup.allCases, id: \.self) { group in
                        let groupCategories = coordinator.categories.filter { $0.group == group }
                        if !groupCategories.isEmpty {
                            groupSection(group: group, categories: groupCategories)
                        }
                    }
                }
            }
        }
    }

    private func groupSection(group: CleanCategoryGroup, categories: [CleanCategory]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.rawValue)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(categories.count) items · \(DiskSpaceInfo.format(bytes: categories.reduce(0) { $0 + $1.bytes }))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(categories) { category in
                categoryCard(category)
            }
        }
        .padding(.vertical, 4)
    }

    private func categoryCard(_ category: CleanCategory) -> some View {
        AdaptiveGlassContainer(padding: 12) {
            HStack(spacing: 14) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { category.isSelected },
                        set: { _ in coordinator.toggleCategorySelection(id: category.id) }
                    )
                )
                .toggleStyle(.checkbox)
                .disabled(category.isProtectedByTCC)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(category.name)
                            .font(.body)
                            .fontWeight(.medium)

                        safetyBadge(category.safetyLevel)

                        if category.isProtectedByTCC {
                            tccBadge
                        }
                    }

                    if let details = category.details {
                        Text(details)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(DiskSpaceInfo.format(bytes: category.bytes))
                        .font(.body)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text("\(category.itemCount) files")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func safetyBadge(_ level: SafetyLevel) -> some View {
        let tint: Color
        switch level {
        case .guaranteedSafe:
            tint = .green
        case .rebuildable:
            tint = .blue
        case .deadLeftover:
            tint = .purple
        }

        return Text(level.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.18))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }

    private var tccBadge: some View {
        Text("FDA Required")
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.18))
            .foregroundStyle(Color.orange)
            .clipShape(Capsule())
    }

    private var emptyCategoriesCard: some View {
        AdaptiveGlassContainer {
            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text("Ready to Clean")
                    .font(.headline)
                Text("Press 'Scan Space' below to discover caches, logs, and build artifacts that can be safely reclaimed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
        }
    }

    private var bottomActionBar: some View {
        AdaptiveGlassContainer(padding: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Selected:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(DiskSpaceInfo.format(bytes: coordinator.selectedReclaimableBytes))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.orange)
                    }
                    Text("of \(DiskSpaceInfo.format(bytes: coordinator.totalReclaimableBytes)) total reclaimable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Select All") {
                    coordinator.selectAllCategories()
                }
                .buttonStyle(.plain)
                .font(.caption)

                Button("Deselect All") {
                    coordinator.deselectAllCategories()
                }
                .buttonStyle(.plain)
                .font(.caption)

                Button {
                    Task {
                        try? await coordinator.scanReclaimableSpace()
                    }
                } label: {
                    Label("Scan Space", systemImage: "arrow.clockwise")
                }
                .disabled(coordinator.isScanning || coordinator.isCleaning)

                Button {
                    showCleanConfirmation = true
                } label: {
                    Label("Clean Selected", systemImage: "trash.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.orange)
                .disabled(coordinator.selectedReclaimableBytes == 0 || coordinator.isCleaning || coordinator.isScanning)
            }
        }
    }
}

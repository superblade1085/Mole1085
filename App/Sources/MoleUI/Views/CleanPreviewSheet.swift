import SwiftUI
import MoleCore
import MoleEngine

public struct CleanPreviewSheet: View {
    @Bindable public var coordinator: MoleCoordinator
    @Binding public var isPresented: Bool

    @State private var createSnapshotBeforeClean: Bool = true
    @State private var isExecutingClean: Bool = false

    public init(coordinator: MoleCoordinator, isPresented: Binding<Bool>) {
        self.coordinator = coordinator
        self._isPresented = isPresented
    }

    private var detectedSQLiteLocksCount: Int {
        var count = 0
        for cat in coordinator.categories where cat.isSelected {
            for p in cat.paths {
                if DatabaseGuard.isCompanionFile(url: p) {
                    count += 1
                }
            }
        }
        return count
    }

    private var detectedCloudStubsCount: Int {
        var count = 0
        for cat in coordinator.categories where cat.isSelected {
            for p in cat.paths {
                if DatalessGuard.isDatalessOrUbiquitous(url: p) {
                    count += 1
                }
            }
        }
        return count
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    storageImpactCard
                    safetyAuditStrip
                    insuranceCard
                    candidateItemsCard
                }
                .padding(20)
            }

            Divider()

            footerBar
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(width: 580, height: 540)
        .background(
            VisualEffectView(material: .sheet, blendingMode: .behindWindow, state: .active)
        )
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Clean Preview & Simulation")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Deterministic pre-flight dry run with APFS safety insurance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close simulation preview")
        }
    }

    // MARK: - Storage Impact Card
    private var storageImpactCard: some View {
        AdaptiveGlassContainer(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Storage Projection")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.warmAmber)
                        Text("-\(DiskSpaceInfo.format(bytes: coordinator.selectedReclaimableBytes))")
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundStyle(GlassTheme.warmAmber)
                        Text("reclaimed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Projected Disk Space
                let projectedFree = coordinator.diskSpace.freeBytes + coordinator.selectedReclaimableBytes
                let projectedReclaimable = max(0, coordinator.totalReclaimableBytes - coordinator.selectedReclaimableBytes)
                let projectedDisk = DiskSpaceInfo(
                    totalBytes: coordinator.diskSpace.totalBytes,
                    freeBytes: projectedFree,
                    reclaimableBytes: projectedReclaimable
                )

                StorageGaugeBar(diskSpace: projectedDisk, height: 10)

                HStack {
                    Text("Current: \(DiskSpaceInfo.format(bytes: coordinator.diskSpace.freeBytes)) Free")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("After Clean: \(DiskSpaceInfo.format(bytes: projectedFree)) Free")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(GlassTheme.sageGreen)
                }
            }
        }
    }

    // MARK: - Pre-Flight Safety Audit Strip
    private var safetyAuditStrip: some View {
        HStack(spacing: 8) {
            auditPill(
                icon: "lock.shield.fill",
                title: "DatabaseGuard",
                detail: "\(detectedSQLiteLocksCount) Companion Locks",
                tint: detectedSQLiteLocksCount > 0 ? GlassTheme.warmAmber : GlassTheme.sageGreen
            )
            auditPill(
                icon: "icloud.slash.fill",
                title: "DatalessGuard",
                detail: "\(detectedCloudStubsCount) Cloud Stubs",
                tint: detectedCloudStubsCount > 0 ? GlassTheme.warmAmber : GlassTheme.sageGreen
            )
            auditPill(
                icon: "arrow.uturn.backward.circle.fill",
                title: "SafeTrash",
                detail: "100% Reversible",
                tint: GlassTheme.sageGreen
            )
        }
    }

    private func auditPill(icon: String, title: String, detail: String, tint: Color) -> some View {
        AdaptiveGlassContainer(padding: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Insurance Safety Net
    private var insuranceCard: some View {
        AdaptiveGlassContainer(padding: 12) {
            Toggle(isOn: $createSnapshotBeforeClean) {
                HStack(spacing: 10) {
                    Image(systemName: "camera.badge.shield.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(GlassTheme.sageGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Create Instant APFS Local Snapshot")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Recommended")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(GlassTheme.sageGreen.opacity(0.18))
                                .foregroundStyle(GlassTheme.sageGreen)
                                .clipShape(Capsule())
                        }
                        Text("Enables instant system-level rollback via macOS Recovery or mole restore.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)
            .tint(GlassTheme.sageGreen)
        }
    }

    // MARK: - Candidate Drill-Down Items
    private var candidateItemsCard: some View {
        AdaptiveGlassContainer(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Clean Candidates (\(coordinator.categories.filter { $0.isSelected }.count) categories selected)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ForEach(coordinator.categories.filter { $0.isSelected }) { category in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.warmAmber)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(category.name)
                                .font(.body)
                                .fontWeight(.medium)
                            Text("\(category.itemCount) files · \(category.safetyLevel.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(DiskSpaceInfo.format(bytes: category.bytes))
                            .font(.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Footer
    private var footerBar: some View {
        HStack {
            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Spacer()

            Button {
                executeClean()
            } label: {
                HStack(spacing: 6) {
                    if isExecutingClean {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("Clean \(DiskSpaceInfo.format(bytes: coordinator.selectedReclaimableBytes))")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(GlassTheme.warmAmber)
            .controlSize(.regular)
            .disabled(coordinator.selectedReclaimableBytes == 0 || isExecutingClean)
        }
    }

    private func executeClean() {
        isExecutingClean = true
        Task {
            do {
                _ = try await coordinator.performSafeCleanup(
                    categories: coordinator.categories,
                    createSnapshot: createSnapshotBeforeClean
                )
            } catch {
                coordinator.reportError("Cleanup failed: \(error.localizedDescription)")
            }
            isExecutingClean = false
            isPresented = false
        }
    }
}

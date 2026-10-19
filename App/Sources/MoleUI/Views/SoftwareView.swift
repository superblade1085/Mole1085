import SwiftUI
import MoleEngine

public struct SoftwareView: View {
    @Bindable public var coordinator: MoleCoordinator
    @State private var filterMode: SoftwareFilterMode = .all
    @State private var appToUninstall: InstalledApp? = nil
    @State private var isUninstalling: Bool = false
    @State private var expandedAppIDs: Set<String> = []
    @State private var loadingLeftoverIDs: Set<String> = []

    public enum SoftwareFilterMode: String, CaseIterable, Identifiable {
        case all = "All Apps"
        case large = "Large (> 500 MB)"
        case leftovers = "With Leftovers"

        public var id: String { rawValue }
    }

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            if coordinator.isLoadingApps && coordinator.installedApps.isEmpty {
                loadingStateView
            } else if coordinator.installedApps.isEmpty {
                emptyStateView
            } else {
                appsListView
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 450)
        .task {
            if coordinator.installedApps.isEmpty && !coordinator.isLoadingApps {
                try? await coordinator.fetchInstalledApps()
            }
        }
        .confirmationDialog(
            "Uninstall \(appToUninstall?.name ?? "Application")?",
            isPresented: Binding(
                get: { appToUninstall != nil },
                set: { if !$0 { appToUninstall = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                if let app = appToUninstall {
                    Task {
                        isUninstalling = true
                        _ = try? await coordinator.uninstallApp(app: app)
                        isUninstalling = false
                        appToUninstall = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                appToUninstall = nil
            }
        } message: {
            if let app = appToUninstall {
                Text("This will move \(app.name) and its associated residual support files to Trash.")
            }
        }
    }

    private var filteredApps: [InstalledApp] {
        switch filterMode {
        case .all:
            return coordinator.installedApps
        case .large:
            return coordinator.installedApps.filter { $0.sizeBytes >= 500_000_000 }
        case .leftovers:
            return coordinator.installedApps.filter {
                if let items = coordinator.appLeftovers[$0.id] {
                    return !items.isEmpty
                }
                return false
            }
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Software & Leftover Hunter")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("\(coordinator.installedApps.count) applications discovered via Mole CLI")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if coordinator.isLoadingApps {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    Task {
                        try? await coordinator.fetchInstalledApps()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .help("Refresh installed applications list")
            }

            Picker("Filter", selection: $filterMode) {
                ForEach(SoftwareFilterMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
        }
    }

    private var appsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredApps) { app in
                    appRow(app)
                }
            }
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        let isExpanded = expandedAppIDs.contains(app.id)
        let leftovers = coordinator.appLeftovers[app.id]
        let isLoadingLeftovers = loadingLeftoverIDs.contains(app.id)

        return AdaptiveGlassContainer(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(GlassTheme.atmosphericBlue.opacity(0.16))
                            .frame(width: 40, height: 40)
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(GlassTheme.atmosphericBlue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(app.name)
                                .font(.body)
                                .fontWeight(.semibold)
                            if let src = app.source, !src.isEmpty {
                                Text(src)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.06))
                                    .clipShape(Capsule())
                            }
                        }
                        if !app.bundleID.isEmpty {
                            Text(app.bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(app.sizeDisplay)
                            .font(.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()

                        HStack(spacing: 8) {
                            // Probe Leftovers button
                            Button {
                                if isExpanded {
                                    expandedAppIDs.remove(app.id)
                                } else {
                                    expandedAppIDs.insert(app.id)
                                    if leftovers == nil {
                                        Task {
                                            loadingLeftoverIDs.insert(app.id)
                                            _ = try? await coordinator.fetchAppLeftovers(app: app)
                                            loadingLeftoverIDs.remove(app.id)
                                        }
                                    }
                                }
                            } label: {
                                if isLoadingLeftovers {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: isExpanded ? "chevron.up" : "magnifyingglass")
                                        Text(leftovers == nil ? "Find Leftovers" : "\(leftovers?.count ?? 0) Leftovers")
                                    }
                                    .font(.caption)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Scan residual containers, caches, and preferences")

                            // Uninstall button
                            Button(role: .destructive) {
                                appToUninstall = app
                            } label: {
                                Label("Uninstall", systemImage: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(GlassTheme.warmAmber)
                            .help("Move app and residual files to Trash")
                        }
                    }
                }

                // Expanded leftovers list
                if isExpanded {
                    Divider()
                    if let items = leftovers, !items.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Associated Residuals (\(items.count) items):")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(GlassTheme.softLavender)

                            ForEach(items) { item in
                                HStack(spacing: 6) {
                                    Image(systemName: iconForLeftoverType(item.type))
                                        .font(.caption)
                                        .foregroundStyle(GlassTheme.softLavender)
                                    Text(item.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    if item.size > 0 {
                                        Text(DiskSpaceInfo.format(bytes: item.size))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } else if leftovers != nil {
                        Text("No orphaned leftovers found for this application.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func iconForLeftoverType(_ type: String) -> String {
        switch type {
        case "cache": return "archivebox"
        case "applicationSupport": return "folder"
        case "preference": return "gearshape"
        case "container": return "shippingbox"
        case "log": return "doc.text"
        default: return "folder.badge.minus"
        }
    }

    private var loadingStateView: some View {
        AdaptiveGlassContainer {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Scanning Installed Software...")
                    .font(.headline)
                Text("Retrieving applications and bundle metadata via Mole CLI engine.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        }
    }

    private var emptyStateView: some View {
        AdaptiveGlassContainer {
            VStack(spacing: 16) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Applications Found")
                    .font(.headline)
                Text("Scan your Mac to inventory installed software and detect residual files.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Scan Applications") {
                    Task {
                        try? await coordinator.fetchInstalledApps()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        }
    }
}

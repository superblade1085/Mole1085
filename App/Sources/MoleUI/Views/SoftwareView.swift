import SwiftUI
import MoleEngine

public struct SoftwareView: View {
    @Bindable public var coordinator: MoleCoordinator
    @State private var installedApps: [InstalledAppInfo] = [
        InstalledAppInfo(
            name: "Xcode",
            path: URL(fileURLWithPath: "/Applications/Xcode.app"),
            bundleIdentifier: "com.apple.dt.Xcode",
            version: "15.4",
            sizeBytes: 11_800_000_000,
            lastUsed: Date(),
            leftoverPaths: [
                URL(fileURLWithPath: "~/Library/Caches/com.apple.dt.Xcode"),
                URL(fileURLWithPath: "~/Library/Developer/Xcode/DerivedData")
            ]
        ),
        InstalledAppInfo(
            name: "Visual Studio Code",
            path: URL(fileURLWithPath: "/Applications/Visual Studio Code.app"),
            bundleIdentifier: "com.microsoft.VSCode",
            version: "1.90.0",
            sizeBytes: 480_000_000,
            lastUsed: Date().addingTimeInterval(-86400 * 2),
            leftoverPaths: [
                URL(fileURLWithPath: "~/Library/Application Support/Code/Cache")
            ]
        ),
        InstalledAppInfo(
            name: "Docker",
            path: URL(fileURLWithPath: "/Applications/Docker.app"),
            bundleIdentifier: "com.docker.docker",
            version: "4.30.0",
            sizeBytes: 2_100_000_000,
            lastUsed: Date().addingTimeInterval(-86400 * 5),
            leftoverPaths: [
                URL(fileURLWithPath: "~/Library/Containers/com.docker.docker/Data/log")
            ]
        )
    ]
    @State private var selectedAppID: String? = nil

    @State private var filterMode: SoftwareFilterMode = .all

    public enum SoftwareFilterMode: String, CaseIterable, Identifiable {
        case all = "All Apps"
        case large = "Large (> 1 GB)"
        case leftovers = "Leftovers Only"

        public var id: String { rawValue }
    }

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredApps) { app in
                        appRow(app)
                    }
                }
            }
        }
        .padding(20)
    }

    private var filteredApps: [InstalledAppInfo] {
        switch filterMode {
        case .all:
            return installedApps
        case .large:
            return installedApps.filter { $0.sizeBytes >= 1_000_000_000 }
        case .leftovers:
            return installedApps.filter { !$0.leftoverPaths.isEmpty }
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Software & Leftover Hunter")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Inspect installed apps, residual containers, and dead leftovers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Picker("Filter", selection: $filterMode) {
                ForEach(SoftwareFilterMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
        }
    }

    private func appRow(_ app: InstalledAppInfo) -> some View {
        AdaptiveGlassContainer(padding: 14) {
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
                            if let version = app.version {
                                Text("v\(version)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let bundleID = app.bundleIdentifier {
                            Text(bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(DiskSpaceInfo.format(bytes: app.sizeBytes))
                            .font(.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        Text("App Bundle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !app.leftoverPaths.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Associated Residuals (\(app.leftoverPaths.count) items):")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(GlassTheme.softLavender)

                            Spacer()

                            Button {
                                // Simulated leftover trashing
                            } label: {
                                Label("Clean Leftovers", systemImage: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(GlassTheme.warmAmber)
                            .help("Move orphaned caches and leftovers to Trash")
                        }

                        ForEach(app.leftoverPaths, id: \.self) { path in
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.minus")
                                    .font(.caption)
                                    .foregroundStyle(GlassTheme.softLavender)
                                Text(path.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }
}

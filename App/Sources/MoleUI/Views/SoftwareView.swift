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

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(installedApps) { app in
                        appRow(app)
                    }
                }
            }
        }
        .padding(20)
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
            Text("\(installedApps.count) Applications Detected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func appRow(_ app: InstalledAppInfo) -> some View {
        AdaptiveGlassContainer(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "app.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(app.name)
                                .font(.body)
                                .fontWeight(.semibold)
                            if let version = app.version {
                                Text("v\(version)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let bundleID = app.bundleIdentifier {
                            Text(bundleID)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text(DiskSpaceInfo.format(bytes: app.sizeBytes))
                        .font(.body)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }

                if !app.leftoverPaths.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Associated Caches & Leftovers (\(app.leftoverPaths.count) items):")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(app.leftoverPaths, id: \.self) { path in
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.minus")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text(path.path)
                                    .font(.caption2)
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

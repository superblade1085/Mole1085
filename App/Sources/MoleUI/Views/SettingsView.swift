import SwiftUI
import AppKit
import ServiceManagement
import MoleCore
import MoleEngine

public enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }
}

public struct SettingsView: View {
    @Bindable public var coordinator: MoleCoordinator

    @AppStorage("appAppearanceMode") private var appearanceMode: AppAppearanceMode = .system
    @AppStorage("useApfsSnapshots") private var useApfsSnapshots: Bool = true
    @AppStorage("autoPruneSnapshots24h") private var autoPruneSnapshots24h: Bool = true
    @AppStorage("snapshotThresholdGB") private var snapshotThresholdGB: Double = 10.0
    @AppStorage("confirmBeforeClean") private var confirmBeforeClean: Bool = true

    @State private var isHelperRegistered: Bool = false
    @State private var helperStatusMessage: String? = nil

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            ScrollView {
                VStack(spacing: 16) {
                    appearanceSection
                    insurancePolicySection
                    systemPermissionsSection
                    aboutSection
                }
                .padding(.bottom, 16)
            }
        }
        .padding(20)
        .onAppear {
            checkHelperStatus()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
            Text("Customize appearance, safety thresholds, and system integration")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Appearance (Day / Night / System Sync)
    private var appearanceSection: some View {
        AdaptiveGlassContainer(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 16))
                        .foregroundStyle(GlassTheme.warmAmber)
                    Text("Appearance & Theme")
                        .font(.headline)
                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme Preference")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Sync with macOS appearance or explicitly lock Day (Light) or Night (Dark) mode.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    .help("Select application theme: System, Light, or Dark")
                }
            }
        }
    }

    // MARK: - Insurance & Safety Policy
    private var insurancePolicySection: some View {
        AdaptiveGlassContainer(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 16))
                        .foregroundStyle(GlassTheme.sageGreen)
                    Text("Insurance & Safety Policy")
                        .font(.headline)
                    Spacer()
                }

                Toggle(isOn: $useApfsSnapshots) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create APFS Local Snapshots for Large Cleans")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Automatically freezes an instant APFS snapshot before cleaning operations over \(Int(snapshotThresholdGB)) GB for zero-risk rollback.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(GlassTheme.sageGreen)

                Divider()

                Toggle(isOn: $autoPruneSnapshots24h) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Purge Mole APFS Snapshots After 24 Hours")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Ensures backup snapshots do not permanently occupy freeable disk blocks.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(GlassTheme.warmAmber)

                Divider()

                Toggle(isOn: $confirmBeforeClean) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Always Show Simulation Preview Sheet")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Presents dry-run gauges, SQLite lock audit, and candidate inspect list before moving items to Trash.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(GlassTheme.atmosphericBlue)
            }
        }
    }

    // MARK: - System Permissions & Daemon
    private var systemPermissionsSection: some View {
        AdaptiveGlassContainer(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(GlassTheme.atmosphericBlue)
                    Text("Privilege & System Integration")
                        .font(.headline)
                    Spacer()
                }

                // Full Disk Access Row
                HStack(spacing: 12) {
                    Image(systemName: coordinator.fullDiskAccessGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(coordinator.fullDiskAccessGranted ? GlassTheme.sageGreen : GlassTheme.warmAmber)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Full Disk Access (FDA)")
                            .font(.body)
                            .fontWeight(.medium)
                        Text(coordinator.fullDiskAccessGranted
                             ? "Active — Deep inspection of system logs and diagnostics enabled."
                             : "Optional — Standard mode active. User caches and development artifacts scan without prompts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("System Settings") {
                        FullDiskAccess.openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Open macOS Privacy & Security Settings")
                }

                Divider()

                // Privileged Helper Daemon Row
                HStack(spacing: 12) {
                    Image(systemName: isHelperRegistered ? "checkmark.circle.fill" : "wrench.and.screwdriver")
                        .font(.system(size: 18))
                        .foregroundStyle(isHelperRegistered ? GlassTheme.sageGreen : GlassTheme.warmAmber)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Persistent Privileged Daemon (SMAppService)")
                            .font(.body)
                            .fontWeight(.medium)
                        Text(isHelperRegistered
                             ? "Registered & Active — Seamlessly survives Sparkle updates."
                             : "Not registered — Needed only for root-level purge commands.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(isHelperRegistered ? "Registered" : "Register Helper") {
                        registerHelperDaemon()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isHelperRegistered)
                    .help("Register modern SMAppService background daemon")
                }
            }
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        AdaptiveGlassContainer(padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundStyle(GlassTheme.warmAmber)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mole for Mac · Open-Source Edition")
                        .font(.body)
                        .fontWeight(.semibold)
                    Text("Native Swift 5.9+ / SwiftUI macOS 14+ Architecture · Synchronized with tw93/Mole")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("v1.0.0")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
            }
        }
    }

    private func checkHelperStatus() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.mole.helper.plist")
            isHelperRegistered = (service.status == .enabled)
        }
    }

    private func registerHelperDaemon() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.mole.helper.plist")
            do {
                try service.register()
                isHelperRegistered = (service.status == .enabled)
                helperStatusMessage = nil
            } catch {
                helperStatusMessage = error.localizedDescription
            }
        }
    }
}

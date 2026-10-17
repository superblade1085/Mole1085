import SwiftUI
import AppKit
import ServiceManagement
import MoleCore
import MoleEngine

public struct OnboardingView: View {
    @Bindable public var coordinator: MoleCoordinator
    @Binding public var isPresented: Bool

    @State private var helperStatusString: String = "Not Registered"

    public init(coordinator: MoleCoordinator, isPresented: Binding<Bool>) {
        self.coordinator = coordinator
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 24) {
            heroHeader

            VStack(spacing: 12) {
                featureCard(
                    icon: "sparkles",
                    title: "Zero-Prompt Clean Architecture",
                    subtitle: "Over 80% of clutter (Xcode, npm, CocoaPods, user caches) cleans safely without admin prompts or special permissions.",
                    tint: .blue
                )

                featureCard(
                    icon: "lock.shield",
                    title: "Optional Full Disk Access (FDA)",
                    subtitle: coordinator.fullDiskAccessGranted
                        ? "Full Disk Access is active. System logs and protected caches can be inspected."
                        : "Optional permission for system logs & diagnostic reports. Never required for user caches.",
                    tint: coordinator.fullDiskAccessGranted ? .green : .orange,
                    actionTitle: coordinator.fullDiskAccessGranted ? "Authorized" : "Open System Settings",
                    actionDisabled: coordinator.fullDiskAccessGranted
                ) {
                    FullDiskAccess.openSystemSettings()
                }

                featureCard(
                    icon: "wrench.and.screwdriver",
                    title: "Persistent Privileged Daemon",
                    subtitle: "Registers Apple's modern SMAppService helper once. Persists across Sparkle 2 app updates without repetitive password dialogs.",
                    tint: .purple,
                    actionTitle: "Authorize Daemon",
                    actionDisabled: false
                ) {
                    registerHelperDaemon()
                }
            }

            HStack {
                Spacer()
                Button("Get Started") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 580)
    }

    private var heroHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Welcome to Mole for Mac")
                .font(.title)
                .fontWeight(.bold)

            Text("Clean, analyze, and optimize your Mac with verified safety guardrails.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func featureCard(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        actionTitle: String? = nil,
        actionDisabled: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        AdaptiveGlassContainer(padding: 14) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(tint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if let actionTitle = actionTitle, let action = action {
                    Button(actionTitle) {
                        action()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(actionDisabled)
                }
            }
        }
    }

    private func registerHelperDaemon() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.mole.helper.plist")
            do {
                try service.register()
                helperStatusString = "Registered"
            } catch {
                helperStatusString = "Registration error: \(error.localizedDescription)"
            }
        }
    }
}

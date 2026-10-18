import SwiftUI
import AppKit
import MoleCore
import MoleEngine
import MoleUI

@main
struct MoleApp: App {
    @State private var coordinator = MoleCoordinator()
    @AppStorage(OnboardingView.completedOnboardingKey) private var hasCompletedOnboarding: Bool = false
    @AppStorage("appAppearanceMode") private var appearanceMode: String = "System"

    var body: some Scene {
        WindowGroup {
            ZStack {
                SidebarView(coordinator: coordinator)
            }
            .preferredColorScheme(colorScheme)
            .sheet(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { if !$0 { hasCompletedOnboarding = true } }
            )) {
                OnboardingView(
                    coordinator: coordinator,
                    isPresented: Binding(
                        get: { !hasCompletedOnboarding },
                        set: { if !$0 { hasCompletedOnboarding = true } }
                    )
                )
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }

        #if os(macOS)
        Settings {
            SettingsView(coordinator: coordinator)
                .preferredColorScheme(colorScheme)
                .frame(width: 580, height: 500)
        }
        #endif
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
}

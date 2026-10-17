import Cocoa
import Darwin
import Foundation

public enum FullDiskAccess {
    /// URL to open macOS System Settings -> Privacy & Security -> Full Disk Access
    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!

    /// Silently tests whether Full Disk Access is granted without triggering TCC permission dialogs.
    ///
    /// On modern macOS (Sonoma/Sequoia), inspecting `~/Library/Safari` via `opendir` fails with `EPERM`
    /// when Full Disk Access is not granted, without prompting the user.
    public static func isGranted() -> Bool {
        let safariDir = ("~/Library/Safari" as NSString).expandingTildeInPath
        if let dir = opendir(safariDir) {
            closedir(dir)
            return true
        }
        return false
    }

    /// Opens macOS System Settings to the Full Disk Access pane.
    @MainActor
    public static func openSystemSettings() {
        NSWorkspace.shared.open(settingsURL)
    }
}

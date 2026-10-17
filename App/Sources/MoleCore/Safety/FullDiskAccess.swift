import Cocoa
import Darwin
import Foundation

public enum FullDiskAccess {
    /// URL to open macOS System Settings -> Privacy & Security -> Full Disk Access
    public static let openSystemSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
    
    /// Alias matching legacy settingsURL references
    public static let settingsURL = openSystemSettingsURL

    /// Silently tests whether Full Disk Access is granted without triggering TCC permission dialogs.
    ///
    /// Inspects `~/Library/Safari` and falls back to secondary TCC canary paths (`~/Library/Mail`).
    /// Correctly distinguishes TCC blocks (`EPERM` / `EACCES`) from non-existent paths (`ENOENT`).
    public static func isGranted() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let safariDir = home.appendingPathComponent("Library/Safari").path
        
        if let dir = opendir(safariDir) {
            closedir(dir)
            return true
        }
        
        // If blocked by TCC, errno is EPERM or EACCES
        if errno == EPERM || errno == EACCES {
            return false
        }
        
        // If folder did not exist (ENOENT) or other benign status, check secondary canary path: ~/Library/Mail
        let mailDir = home.appendingPathComponent("Library/Mail").path
        if let mail = opendir(mailDir) {
            closedir(mail)
            return true
        }
        
        return errno != EPERM && errno != EACCES
    }

    /// Opens macOS System Settings to the Full Disk Access pane.
    @MainActor
    public static func openSystemSettings() {
        NSWorkspace.shared.open(openSystemSettingsURL)
    }
}

import Cocoa
import Foundation

public enum SafeTrashError: Error, LocalizedError, Equatable {
    case itemNotFound(String)
    case systemPathProtected(String)
    case permissionDenied(String)
    case volumeDoesNotSupportTrash(String)
    case trashOperationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .itemNotFound(let path):
            return "Item not found: \(path)"
        case .systemPathProtected(let path):
            return "Path is a protected system directory: \(path)"
        case .permissionDenied(let path):
            return "Permission denied moving item to Trash: \(path)"
        case .volumeDoesNotSupportTrash(let path):
            return "Volume containing \(path) does not support trash"
        case .trashOperationFailed(let reason):
            return "Trash operation failed: \(reason)"
        }
    }
}

public enum SafeTrash {
    private static let systemTreePrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin"
    ]

    private static let protectedExactPaths: Set<String> = [
        "/",
        "/Library",
        "/Applications",
        "/Users",
        NSHomeDirectory(),
        URL(fileURLWithPath: NSHomeDirectory()).standardized.path
    ]

    /// Trashes an item safely using Cocoa's native APFS cross-volume trashing mechanism.
    ///
    /// - Parameters:
    ///   - url: The file or directory URL to trash.
    ///   - trashDirectoryOverride: Optional directory override used for synthetic unit testing in sandbox.
    /// - Returns: The resulting URL in the Trash.
    @discardableResult
    public static func trashItem(at url: URL, trashDirectoryOverride: URL? = nil) throws -> URL {
        let standardized = url.standardized
        let path = standardized.path

        guard FileManager.default.fileExists(atPath: path) else {
            throw SafeTrashError.itemNotFound(path)
        }

        // Refuse exact protected roots (/, /Library, /Applications, /Users, and user HOME)
        if protectedExactPaths.contains(path) {
            throw SafeTrashError.systemPathProtected(path)
        }

        // Refuse any path residing within core immutable system trees (/System, /usr, /bin, /sbin)
        for prefix in systemTreePrefixes {
            if path == prefix || path.hasPrefix(prefix + "/") {
                throw SafeTrashError.systemPathProtected(path)
            }
        }

        // Handle synthetic sandbox test directory override
        if let override = trashDirectoryOverride {
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: override, withIntermediateDirectories: true)
            let dest = override.appendingPathComponent(url.lastPathComponent)
            if fileManager.fileExists(atPath: dest.path) {
                try? fileManager.removeItem(at: dest)
            }
            try fileManager.moveItem(at: standardized, to: dest)
            return dest
        }

        var resultingURL: NSURL?
        do {
            try FileManager.default.trashItem(at: standardized, resultingItemURL: &resultingURL)
            guard let trashed = resultingURL as URL? else {
                throw SafeTrashError.trashOperationFailed("FileManager.trashItem did not return resulting URL")
            }
            return trashed
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && (nsError.code == NSFileWriteNoPermissionError || nsError.code == 513) {
                throw SafeTrashError.permissionDenied(path)
            }
            throw SafeTrashError.trashOperationFailed(error.localizedDescription)
        }
    }
}

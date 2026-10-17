import Cocoa
import Foundation

public extension URLResourceKey {
    /// Resource key representing whether the underlying volume supports trash.
    static let volumeSupportsTrashKey = URLResourceKey(rawValue: "NSURLVolumeSupportsTrashKey")
}

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
    public typealias TrashingHandler = (URL, AutoreleasingUnsafeMutablePointer<NSURL?>?) throws -> Void

    /// System directory hierarchies that must never be targeted for deletion.
    private static let systemTreePrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private/etc",
        "/private/var/db",
        "/private/var/root",
        "/private/var/run",
        "/private/var/audit",
        "/etc",
        "/var/db",
        "/var/root"
    ]

    /// Exact critical root paths that must never be deleted.
    private static let protectedExactPaths: Set<String> = [
        "/",
        "/private",
        "/private/var",
        "/etc",
        "/var",
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
    ///   - trashingHandler: Injectable Cocoa trashing implementation (defaults to `FileManager.default.trashItem`).
    /// - Returns: The resulting URL in the Trash.
    @discardableResult
    public static func trashItem(
        at url: URL,
        trashingHandler: TrashingHandler = { try FileManager.default.trashItem(at: $0, resultingItemURL: $1) }
    ) throws -> URL {
        let standardized = url.standardized
        let path = standardized.path
        let canonicalPath = standardized.resolvingSymlinksInPath().path

        guard FileManager.default.fileExists(atPath: path) else {
            throw SafeTrashError.itemNotFound(path)
        }

        // 1. Refuse exact protected roots
        if protectedExactPaths.contains(path) || protectedExactPaths.contains(canonicalPath) {
            throw SafeTrashError.systemPathProtected(path)
        }

        // 2. Refuse any path residing within immutable system trees (/System, /usr, /bin, /sbin, /private/etc, etc.)
        for prefix in systemTreePrefixes {
            if path == prefix || path.hasPrefix(prefix + "/") ||
               canonicalPath == prefix || canonicalPath.hasPrefix(prefix + "/") {
                throw SafeTrashError.systemPathProtected(path)
            }
        }

        // 3. Inspect volume read-only and trash support before deletion per design specification
        if let values = try? standardized.resourceValues(forKeys: [.volumeIsReadOnlyKey]),
           values.volumeIsReadOnly == true {
            throw SafeTrashError.volumeDoesNotSupportTrash(path)
        }

        do {
            _ = try FileManager.default.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: standardized, create: false)
        } catch {
            throw SafeTrashError.volumeDoesNotSupportTrash(path)
        }

        // 4. Execute Cocoa trashing
        var resultingURL: NSURL?
        do {
            try trashingHandler(standardized, &resultingURL)
            guard let trashed = resultingURL as URL? else {
                throw SafeTrashError.trashOperationFailed("FileManager.trashItem did not return resulting URL")
            }
            return trashed
        } catch let error as SafeTrashError {
            throw error
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && (nsError.code == NSFileWriteNoPermissionError || nsError.code == 513) {
                throw SafeTrashError.permissionDenied(path)
            }
            throw SafeTrashError.trashOperationFailed(error.localizedDescription)
        }
    }
}

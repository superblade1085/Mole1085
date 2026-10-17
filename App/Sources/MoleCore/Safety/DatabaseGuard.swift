import Foundation

public enum DatabaseGuard {
    private static let dbExtensions = ["db", "sqlite", "sqlite3"]
    private static let sidecarSuffixes = ["-wal", "-shm", "-journal"]

    /// Groups a database file and its associated companion files (-wal, -shm, -journal).
    ///
    /// Given any member of the database family (e.g. `foo.db` or `foo.db-wal`),
    /// this returns all companion URLs that exist or belong together.
    ///
    /// - Parameters:
    ///   - databaseURL: The URL of the database or any of its sidecars.
    ///   - onlyExisting: If `true`, filters the companions to only URLs currently present on disk.
    public static func bundleCompanionPaths(databaseURL: URL, onlyExisting: Bool = false) -> [URL] {
        let url = databaseURL.standardized
        let path = url.path

        var basePath = path
        // Strip known sidecar suffixes if a sidecar was passed
        for suffix in sidecarSuffixes {
            if basePath.hasSuffix(suffix) {
                basePath = String(basePath.dropLast(suffix.count))
                break
            }
        }

        let baseURL = URL(fileURLWithPath: basePath)
        var companions: [URL] = [baseURL]

        for suffix in sidecarSuffixes {
            let sidecarURL = URL(fileURLWithPath: basePath + suffix)
            companions.append(sidecarURL)
        }

        if onlyExisting {
            return companions.filter { FileManager.default.fileExists(atPath: $0.path) }
        }

        return companions
    }

    /// Determines if a path belongs to an active SQLite database journal or sidecar.
    /// Checks that the base file possesses a recognized database extension (.db, .sqlite, .sqlite3)
    /// to avoid falsely categorizing arbitrary user files (e.g. `daily-journal`).
    public static func isCompanionFile(url: URL) -> Bool {
        let filename = url.lastPathComponent
        for suffix in sidecarSuffixes {
            if filename.hasSuffix(suffix) {
                let baseName = String(filename.dropLast(suffix.count))
                let baseExt = (baseName as NSString).pathExtension.lowercased()
                if dbExtensions.contains(baseExt) {
                    return true
                }
            }
        }
        return false
    }
}

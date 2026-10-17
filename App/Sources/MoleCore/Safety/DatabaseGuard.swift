import Foundation

public enum DatabaseGuard {
    private static let sidecarSuffixes = ["-wal", "-shm", "-journal"]

    /// Groups a database file and its associated companion files (-wal, -shm, -journal).
    ///
    /// Given any member of the database family (e.g. `foo.db` or `foo.db-wal`),
    /// this returns all companion URLs that exist or belong together.
    public static func bundleCompanionPaths(databaseURL: URL) -> [URL] {
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

        return companions
    }

    /// Determines if a path belongs to an active SQLite database journal or sidecar.
    public static func isCompanionFile(url: URL) -> Bool {
        let path = url.path
        return sidecarSuffixes.contains { path.hasSuffix($0) }
    }
}

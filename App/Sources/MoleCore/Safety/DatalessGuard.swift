import Darwin
import Foundation

public enum DatalessGuard {
    /// SF_DATALESS flag on Darwin / APFS (defined in sys/stat.h as 0x40000000)
    public static let sfDatalessFlag: UInt32 = 0x40000000

    /// Inspects whether an item is a dataless file stub (e.g. evicted iCloud / cloud placeholder)
    /// without triggering a download or network fault.
    ///
    /// - Parameter url: The URL of the target file.
    /// - Returns: `true` if the file is dataless or an un-downloaded ubiquitous item.
    public static func isDatalessOrUbiquitous(url: URL) -> Bool {
        let path = url.standardized.path
        
        // 1. Check stat.st_flags for SF_DATALESS
        var statBuf = stat()
        if lstat(path, &statBuf) == 0 {
            if (statBuf.st_flags & sfDatalessFlag) != 0 {
                return true
            }
        }

        // 2. Check NSURLIsUbiquitousItemKey / NSURLUbiquitousItemDownloadingStatusKey
        let keys: Set<URLResourceKey> = [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ]
        if let resourceValues = try? url.resourceValues(forKeys: keys) {
            if resourceValues.isUbiquitousItem == true {
                if let status = resourceValues.ubiquitousItemDownloadingStatus {
                    if status == .notDownloaded {
                        return true
                    }
                }
            }
        }

        return false
    }
}

import Foundation

/// Discovers and resolves upstream Mole CLI engine components across App Bundle,
/// local repository development, and system install paths.
public final class MoleEngineLocator: @unchecked Sendable {
    public static let shared = MoleEngineLocator()

    private let lock = NSLock()
    private var cachedRootURL: URL?

    public init() {}

    /// The root directory containing `bin/`, `lib/`, `adapters/`, and `mo`.
    public var engineRootURL: URL? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedRootURL {
            return cached
        }

        let resolved = findEngineRoot()
        cachedRootURL = resolved
        return resolved
    }

    /// Resolves an adapter script from `adapters/` directory.
    public func resolveAdapter(named name: String) -> URL? {
        guard let root = engineRootURL else { return nil }
        let adapterURL = root.appendingPathComponent("adapters").appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: adapterURL.path) ? adapterURL : nil
    }

    /// Resolves a script or file relative to engine root (e.g. "bin/clean.sh", "lib/check/health_json.sh").
    public func resolveScript(named relativePath: String) -> URL? {
        guard let root = engineRootURL else { return nil }
        let scriptURL = root.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: scriptURL.path) ? scriptURL : nil
    }

    /// Resolves an executable binary from `bin/` (e.g. "status-go", "analyze-go", "mo").
    public func resolveBinary(named name: String) -> URL? {
        guard let root = engineRootURL else { return nil }
        let binaryURL = root.appendingPathComponent("bin").appendingPathComponent(name)
        if FileManager.default.isExecutableFile(atPath: binaryURL.path) {
            return binaryURL
        }
        let rootBinary = root.appendingPathComponent(name)
        if FileManager.default.isExecutableFile(atPath: rootBinary.path) {
            return rootBinary
        }
        return nil
    }

    // MARK: - Private Discovery Heuristics

    private func findEngineRoot() -> URL? {
        let fm = FileManager.default

        // 1. Explicit environment override
        if let envRoot = ProcessInfo.processInfo.environment["MOLE_ENGINE_ROOT"] {
            let url = URL(fileURLWithPath: envRoot)
            if isValidEngineRoot(url) {
                return url
            }
        }

        // 2. Main App Bundle resource: Contents/Resources/mole-engine
        if let bundleResource = Bundle.main.resourceURL?.appendingPathComponent("mole-engine") {
            if isValidEngineRoot(bundleResource) {
                return bundleResource
            }
        }

        // 3. Current working directory or parent directories (Development / swift test mode)
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        var candidate: URL? = cwd
        while let current = candidate {
            if isValidEngineRoot(current) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            candidate = parent
        }

        // 4. Source file relative discovery (for SPM test runner executing in .build directory)
        let sourceURL = URL(fileURLWithPath: #filePath)
        var sourceCandidate: URL? = sourceURL
        while let current = sourceCandidate {
            if isValidEngineRoot(current) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            sourceCandidate = parent
        }

        // 5. System install directories
        let systemCandidates = [
            URL(fileURLWithPath: "/usr/local/share/mole"),
            URL(fileURLWithPath: "/opt/homebrew/share/mole"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".local/share/mole"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".mole")
        ]
        for url in systemCandidates {
            if isValidEngineRoot(url) {
                return url
            }
        }

        return nil
    }

    private func isValidEngineRoot(_ url: URL) -> Bool {
        let fm = FileManager.default
        let baseSh = url.appendingPathComponent("lib/core/base.sh")
        let adaptersDir = url.appendingPathComponent("adapters")
        return fm.fileExists(atPath: baseSh.path) && fm.fileExists(atPath: adaptersDir.path)
    }
}

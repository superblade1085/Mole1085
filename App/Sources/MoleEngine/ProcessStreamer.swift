import Foundation
import MoleCore

/// Errors produced during subprocess streaming and execution.
public enum ProcessStreamerError: Error, LocalizedError, Equatable, Sendable {
    case processLaunchFailed(String)
    case processFailed(exitCode: Int32, reason: Process.TerminationReason)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .processLaunchFailed(let reason):
            return "Failed to launch process: \(reason)"
        case .processFailed(let exitCode, let reason):
            let reasonStr = reason == .exit ? "exit" : "uncaughtSignal"
            return "Process terminated with exit code \(exitCode) (reason: \(reasonStr))"
        case .cancelled:
            return "Process streaming was cancelled"
        }
    }
}

/// An async line streamer for external subprocesses with process group isolation.
public struct ProcessStreamer: Sendable {
    public init() {}

    /// Spawns a subprocess and streams its stdout line by line over an `AsyncThrowingStream`.
    ///
    /// - Parameters:
    ///   - executable: Absolute path to the executable.
    ///   - arguments: Command line arguments.
    ///   - environment: Optional custom environment dictionary.
    ///   - workingDirectory: Optional working directory URL.
    /// - Returns: An `AsyncThrowingStream` emitting lines of output.
    public func stream(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if let environment {
                process.environment = environment
            }
            if let workingDirectory {
                process.currentDirectoryURL = workingDirectory
            }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let stdinPipe = Pipe()
            
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.standardInput = stdinPipe

            // Drain stderr to prevent pipe buffer deadlock
            stderrPipe.fileHandleForReading.readabilityHandler = { _ in }

            let lineBuffer = LineBuffer()
            let streamState = StreamState()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    let remaining = lineBuffer.flushRemaining()
                    for line in remaining {
                        continuation.yield(line)
                    }
                    return
                }
                let lines = lineBuffer.append(data)
                for line in lines {
                    continuation.yield(line)
                }
            }

            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                guard streamState.markTerminated().shouldTerminate else { return }

                // Read any residual data left in pipe
                let remainingData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingData.isEmpty {
                    let lines = lineBuffer.append(remainingData)
                    for line in lines {
                        continuation.yield(line)
                    }
                }
                let remaining = lineBuffer.flushRemaining()
                for line in remaining {
                    continuation.yield(line)
                }

                if proc.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: ProcessStreamerError.processFailed(
                        exitCode: proc.terminationStatus,
                        reason: proc.terminationReason
                    ))
                }
            }

            continuation.onTermination = { @Sendable _ in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let result = streamState.markTerminated()
                if result.shouldTerminate && result.pid > 1 {
                    ProcessGroupManager.terminateGroup(pid: result.pid, gracePeriod: 0.5)
                }
            }

            do {
                try process.run()
                streamState.setPid(process.processIdentifier)

                // Ensure child process group
                _ = setpgid(process.processIdentifier, process.processIdentifier)
            } catch {
                _ = streamState.markTerminated()
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.finish(throwing: ProcessStreamerError.processLaunchFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - Thread-Safe Line Buffer

private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var remainder = Data()
    private var isFlushed = false

    func append(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard !isFlushed else { return [] }
        remainder.append(data)
        return extractLines(flushing: false)
    }

    func flushRemaining() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard !isFlushed else { return [] }
        isFlushed = true
        return extractLines(flushing: true)
    }

    private func extractLines(flushing: Bool) -> [String] {
        var lines: [String] = []
        var startIndex = remainder.startIndex

        while let newlineIndex = remainder[startIndex...].firstIndex(of: 0x0A) { // '\n'
            let lineData = remainder[startIndex..<newlineIndex]
            if let line = String(data: lineData, encoding: .utf8) {
                let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line
                lines.append(trimmed)
            }
            startIndex = remainder.index(after: newlineIndex)
        }

        if startIndex < remainder.endIndex {
            if flushing {
                let remainingData = remainder[startIndex...]
                if let line = String(data: remainingData, encoding: .utf8), !line.isEmpty {
                    let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line
                    lines.append(trimmed)
                }
                remainder.removeAll()
            } else {
                remainder = remainder[startIndex...]
            }
        } else {
            remainder.removeAll()
        }

        return lines
    }
}

// MARK: - Thread-Safe Stream State

private final class StreamState: @unchecked Sendable {
    private let lock = NSLock()
    private var childPid: pid_t = 0
    private var hasTerminated = false

    func setPid(_ pid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        self.childPid = pid
    }

    func markTerminated() -> (shouldTerminate: Bool, pid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        let already = hasTerminated
        hasTerminated = true
        return (!already, childPid)
    }
}

import Darwin
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

/// An async line streamer for external subprocesses with atomic process group isolation (`POSIX_SPAWN_SETPGROUP`).
public struct ProcessStreamer: Sendable {
    public init() {}

    /// Spawns an isolated subprocess in its own process group and streams its stdout line by line.
    ///
    /// - Parameters:
    ///   - executable: Absolute path to the executable or binary name in PATH.
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
            let lineBuffer = LineBuffer()
            let streamState = StreamState()

            let proc: IsolatedProcess
            do {
                proc = try IsolatedProcess(
                    executable: executable,
                    arguments: arguments,
                    environment: environment,
                    workingDirectory: workingDirectory
                ) { exitCode, reason in
                    let shouldComplete = streamState.markExited(code: exitCode, reason: reason)
                    if shouldComplete {
                        finishStream(
                            lineBuffer: lineBuffer,
                            streamState: streamState,
                            continuation: continuation
                        )
                    }
                }
                streamState.setProc(proc)
            } catch {
                continuation.finish(throwing: error)
                return
            }

            // Drain stderr to prevent pipe buffer deadlock
            proc.stderrHandle.readabilityHandler = { _ in }

            proc.stdoutHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    let shouldComplete = streamState.markStdoutClosed()
                    if shouldComplete {
                        finishStream(
                            lineBuffer: lineBuffer,
                            streamState: streamState,
                            continuation: continuation
                        )
                    }
                    return
                }
                let lines = lineBuffer.append(data)
                for line in lines {
                    continuation.yield(line)
                }
            }

            continuation.onTermination = { @Sendable _ in
                let (shouldCancel, pid) = streamState.markCancelled()
                if shouldCancel && pid > 1 {
                    ProcessGroupManager.terminateGroup(pid: pid, gracePeriod: 0.5)
                }
                proc.closeHandles()
            }
        }
    }
}

private func finishStream(
    lineBuffer: LineBuffer,
    streamState: StreamState,
    continuation: AsyncThrowingStream<String, Error>.Continuation
) {
    let proc = streamState.getProc()
    proc?.closeHandles()

    let remaining = lineBuffer.flushRemaining()
    for line in remaining {
        continuation.yield(line)
    }

    if let status = streamState.getExitStatus() {
        if status.code == 0 {
            continuation.finish()
        } else {
            continuation.finish(throwing: ProcessStreamerError.processFailed(
                exitCode: status.code,
                reason: status.reason
            ))
        }
    } else {
        continuation.finish()
    }
}

// MARK: - Native POSIX Isolated Process (posix_spawnp + POSIX_SPAWN_SETPGROUP)

internal final class IsolatedProcess: @unchecked Sendable {
    let pid: pid_t
    let stdoutHandle: FileHandle
    let stderrHandle: FileHandle
    private let exitSource: DispatchSourceProcess
    private let lock = NSLock()
    private var hasFinished = false

    init(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        workingDirectory: URL?,
        onTermination: @escaping @Sendable (Int32, Process.TerminationReason) -> Void
    ) throws {
        var stdoutFds: [Int32] = [0, 0]
        guard Darwin.pipe(&stdoutFds) == 0 else {
            throw ProcessStreamerError.processLaunchFailed("pipe stdout failed: \(errno)")
        }
        let stdoutRead = stdoutFds[0]
        let stdoutWrite = stdoutFds[1]

        var stderrFds: [Int32] = [0, 0]
        guard Darwin.pipe(&stderrFds) == 0 else {
            Darwin.close(stdoutRead)
            Darwin.close(stdoutWrite)
            throw ProcessStreamerError.processLaunchFailed("pipe stderr failed: \(errno)")
        }
        let stderrRead = stderrFds[0]
        let stderrWrite = stderrFds[1]

        let devNullFd = Darwin.open("/dev/null", O_RDONLY)

        var actions: posix_spawn_file_actions_t? = nil
        Darwin.posix_spawn_file_actions_init(&actions)
        defer { Darwin.posix_spawn_file_actions_destroy(&actions) }

        if devNullFd >= 0 {
            Darwin.posix_spawn_file_actions_adddup2(&actions, devNullFd, STDIN_FILENO)
            Darwin.posix_spawn_file_actions_addclose(&actions, devNullFd)
        }
        Darwin.posix_spawn_file_actions_adddup2(&actions, stdoutWrite, STDOUT_FILENO)
        Darwin.posix_spawn_file_actions_adddup2(&actions, stderrWrite, STDERR_FILENO)

        Darwin.posix_spawn_file_actions_addclose(&actions, stdoutRead)
        Darwin.posix_spawn_file_actions_addclose(&actions, stdoutWrite)
        Darwin.posix_spawn_file_actions_addclose(&actions, stderrRead)
        Darwin.posix_spawn_file_actions_addclose(&actions, stderrWrite)

        if let workingDirectory = workingDirectory {
            Darwin.posix_spawn_file_actions_addchdir_np(&actions, workingDirectory.path)
        }

        var attr: posix_spawnattr_t? = nil
        Darwin.posix_spawnattr_init(&attr)
        defer { Darwin.posix_spawnattr_destroy(&attr) }

        // Atomic process group isolation: PGID == PID at spawn before exec
        Darwin.posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETPGROUP))
        Darwin.posix_spawnattr_setpgroup(&attr, 0)

        let allArgs = [executable] + arguments
        let cArgs: [UnsafeMutablePointer<CChar>?] = allArgs.map { strdup($0) } + [nil]
        defer {
            for ptr in cArgs where ptr != nil { free(ptr) }
        }

        let envStrings: [String]
        if let environment = environment {
            envStrings = environment.map { "\($0.key)=\($0.value)" }
        } else {
            envStrings = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
        }
        let cEnv: [UnsafeMutablePointer<CChar>?] = envStrings.map { strdup($0) } + [nil]
        defer {
            for ptr in cEnv where ptr != nil { free(ptr) }
        }

        var childPid: pid_t = 0
        let spawnRes = Darwin.posix_spawnp(&childPid, executable, &actions, &attr, cArgs, cEnv)

        // Close parent write ends immediately
        Darwin.close(stdoutWrite)
        Darwin.close(stderrWrite)
        if devNullFd >= 0 {
            Darwin.close(devNullFd)
        }

        guard spawnRes == 0 else {
            Darwin.close(stdoutRead)
            Darwin.close(stderrRead)
            throw ProcessStreamerError.processLaunchFailed("posix_spawn failed with error \(spawnRes)")
        }

        self.pid = childPid
        self.stdoutHandle = FileHandle(fileDescriptor: stdoutRead, closeOnDealloc: true)
        self.stderrHandle = FileHandle(fileDescriptor: stderrRead, closeOnDealloc: true)

        let queue = DispatchQueue(label: "com.mole.process.exit.\(childPid)", qos: .utility)
        let source = DispatchSource.makeProcessSource(identifier: childPid, eventMask: .exit, queue: queue)
        self.exitSource = source

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.handleExit(onTermination: onTermination)
        }
        source.resume()
    }

    private func handleExit(onTermination: @escaping @Sendable (Int32, Process.TerminationReason) -> Void) {
        lock.lock()
        guard !hasFinished else {
            lock.unlock()
            return
        }
        hasFinished = true
        exitSource.cancel()
        lock.unlock()

        var status: Int32 = 0
        Darwin.waitpid(pid, &status, 0)

        let exitCode: Int32
        let reason: Process.TerminationReason
        if (status & 0x7f) == 0 {
            exitCode = (status >> 8) & 0xff
            reason = .exit
        } else {
            exitCode = status & 0x7f
            reason = .uncaughtSignal
        }

        onTermination(exitCode, reason)
    }

    func closeHandles() {
        stdoutHandle.readabilityHandler = nil
        stderrHandle.readabilityHandler = nil
        try? stdoutHandle.close()
        try? stderrHandle.close()
    }
}

// MARK: - Lossless UTF-8 Line Buffer

internal final class LineBuffer: @unchecked Sendable {
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
            let line = String(decoding: lineData, as: UTF8.self)
            let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line
            lines.append(trimmed)
            startIndex = remainder.index(after: newlineIndex)
        }

        if startIndex < remainder.endIndex {
            if flushing {
                let remainingData = remainder[startIndex...]
                let line = String(decoding: remainingData, as: UTF8.self)
                if !line.isEmpty {
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
    private var proc: IsolatedProcess?
    private var stdoutClosed = false
    private var exitStatus: (code: Int32, reason: Process.TerminationReason)?
    private var isCancelled = false
    private var hasCompleted = false

    func setProc(_ proc: IsolatedProcess) {
        lock.lock()
        defer { lock.unlock() }
        self.proc = proc
    }

    func getProc() -> IsolatedProcess? {
        lock.lock()
        defer { lock.unlock() }
        return proc
    }

    func markStdoutClosed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        stdoutClosed = true
        return checkCompletionLocked()
    }

    func markExited(code: Int32, reason: Process.TerminationReason) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        exitStatus = (code, reason)
        return checkCompletionLocked()
    }

    func markCancelled() -> (shouldCancel: Bool, pid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasCompleted && !isCancelled else { return (false, 0) }
        isCancelled = true
        let pid = proc?.pid ?? 0
        return (true, pid)
    }

    private func checkCompletionLocked() -> Bool {
        if stdoutClosed && exitStatus != nil && !hasCompleted && !isCancelled {
            hasCompleted = true
            return true
        }
        return false
    }

    func getExitStatus() -> (code: Int32, reason: Process.TerminationReason)? {
        lock.lock()
        defer { lock.unlock() }
        return exitStatus
    }
}

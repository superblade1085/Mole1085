import XCTest
@testable import MoleEngine

final class ProcessStreamerTests: XCTestCase {
    func testStreamProcessLines() async throws {
        let streamer = ProcessStreamer()
        var lines: [String] = []
        for try await line in streamer.stream(executable: "/bin/echo", arguments: ["hello\nworld"]) {
            lines.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        XCTAssertEqual(lines, ["hello", "world"])
    }

    func testStreamProcessFailureThrows() async {
        let streamer = ProcessStreamer()
        do {
            for try await _ in streamer.stream(executable: "/bin/sh", arguments: ["-c", "echo 'failing'; exit 42"]) {
                // consume lines
            }
            XCTFail("Stream should have thrown an error on non-zero exit code")
        } catch let error as ProcessStreamerError {
            if case .processFailed(let code, _) = error {
                XCTAssertEqual(code, 42)
            } else {
                XCTFail("Unexpected ProcessStreamerError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testLargeStreamChunks() async throws {
        let streamer = ProcessStreamer()
        var count = 0
        for try await line in streamer.stream(executable: "/bin/sh", arguments: ["-c", "for i in $(seq 1 500); do echo \"line $i\"; done"]) {
            if line.hasPrefix("line ") {
                count += 1
            }
        }
        XCTAssertEqual(count, 500)
    }

    func testEnvironmentAndWorkingDirectory() async throws {
        let streamer = ProcessStreamer()
        var foundVar = false
        let env = ["MOLE_UNIT_TEST_VAR": "ACTIVE_1234"]
        for try await line in streamer.stream(executable: "/usr/bin/env", arguments: [], environment: env) {
            if line.contains("MOLE_UNIT_TEST_VAR=ACTIVE_1234") {
                foundVar = true
            }
        }
        XCTAssertTrue(foundVar, "Custom environment variable should have been passed to subprocess")
    }

    func testCancellationTerminatesSubprocess() async throws {
        let streamer = ProcessStreamer()
        
        let task = Task { () -> Int in
            var lineCount = 0
            for try await _ in streamer.stream(executable: "/bin/sh", arguments: ["-c", "echo 'started'; sleep 10; echo 'finished'"]) {
                lineCount += 1
                // Cancel immediately after first line
                throw CancellationError()
            }
            return lineCount
        }
        
        do {
            _ = try await task.value
            XCTFail("Task was expected to throw CancellationError")
        } catch is CancellationError {
            // Expected
        }
        
        // Wait briefly to allow process cleanup
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    func testProcessGroupTermination() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        
        let pid = process.processIdentifier
        XCTAssertTrue(ProcessGroupManager.isProcessRunning(pid: pid))
        
        ProcessGroupManager.terminateGroup(pid: pid, gracePeriod: 0.1)
        
        // Wait briefly for SIGTERM/SIGKILL escalation
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertFalse(ProcessGroupManager.isProcessRunning(pid: pid))
    }

    func testInvalidPidsDoNotCrashOrSignalSelf() {
        XCTAssertNil(ProcessGroupManager.terminateGroup(pid: 0))
        XCTAssertNil(ProcessGroupManager.terminateGroup(pid: -1))
        XCTAssertNil(ProcessGroupManager.terminateGroup(pid: 1))
        XCTAssertFalse(ProcessGroupManager.isProcessRunning(pid: 0))
        XCTAssertFalse(ProcessGroupManager.isProcessRunning(pid: -1))
    }

    func testPosixSpawnProcessGroupIsolation() throws {
        let proc = try IsolatedProcess(
            executable: "/bin/sleep",
            arguments: ["5"],
            environment: nil,
            workingDirectory: nil
        ) { _, _ in }

        let pid = proc.pid
        XCTAssertGreaterThan(pid, 1)

        let pgid = getpgid(pid)
        XCTAssertEqual(pgid, pid, "Subprocess PGID must be identical to its PID due to POSIX_SPAWN_SETPGROUP")

        ProcessGroupManager.terminateGroup(pid: pid, gracePeriod: 0.05)
    }

    func testLineBufferDecodesLosslessUtf8() {
        let buffer = LineBuffer()
        // Sequence with invalid UTF-8 byte 0xFF
        let data = Data([0x68, 0x65, 0x6C, 0x6C, 0x6F, 0xFF, 0x77, 0x6F, 0x72, 0x6C, 0x64, 0x0A])
        let lines = buffer.append(data)
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].contains("hello"))
        XCTAssertTrue(lines[0].contains("world"))
    }

    func testStderrLargeDrainDoesNotDeadlockOrSpin() async throws {
        let streamer = ProcessStreamer()
        // Subprocess emits 100 KB to stderr and 'done' to stdout.
        // If stderr readability handler does not read availableData, this blocks indefinitely.
        var lines: [String] = []
        for try await line in streamer.stream(
            executable: "/bin/sh",
            arguments: ["-c", "head -c 100000 /dev/zero | tr '\\0' 'x' >&2; echo 'done'"]
        ) {
            lines.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        XCTAssertEqual(lines, ["done"])
    }
}

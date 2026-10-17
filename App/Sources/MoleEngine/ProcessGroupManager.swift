import Foundation

/// Manages process group lifecycles, signal delivery, and escalation for subprocesses.
public enum ProcessGroupManager {
    
    /// Checks if a process with the specified PID is currently running.
    public static func isProcessRunning(pid: pid_t) -> Bool {
        guard pid > 1 else { return false }
        let res = kill(pid, 0)
        return res == 0 || errno == EPERM
    }
    
    /// Checks if any process belonging to the specified process group ID is running.
    public static func isProcessGroupRunning(pgid: pid_t) -> Bool {
        guard pgid > 1 else { return false }
        let res = kill(-pgid, 0)
        return res == 0 || errno == EPERM
    }
    
    /// Gracefully terminates the process group via SIGTERM, scheduling an async escalation
    /// to SIGKILL if processes remain active after `gracePeriod` seconds.
    ///
    /// - Parameters:
    ///   - pid: The target process ID / process group leader ID (must be > 1).
    ///   - gracePeriod: Delay before escalating to SIGKILL (default: 1.5 seconds).
    /// - Returns: The background escalation Task, or nil if PID is invalid (<= 1).
    @discardableResult
    public static func terminateGroup(pid: pid_t, gracePeriod: TimeInterval = 1.5) -> Task<Void, Never>? {
        guard pid > 1 else { return nil }
        
        // 1. Send SIGTERM to the process group and to the process directly.
        _ = kill(-pid, SIGTERM)
        _ = kill(pid, SIGTERM)
        
        // 2. Schedule async escalation to SIGKILL if processes in group remain alive.
        return Task {
            let nanoSeconds = UInt64(max(0.01, gracePeriod) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoSeconds)
            
            if isProcessRunning(pid: pid) || isProcessGroupRunning(pgid: pid) {
                _ = kill(-pid, SIGKILL)
                _ = kill(pid, SIGKILL)
            }
        }
    }
}

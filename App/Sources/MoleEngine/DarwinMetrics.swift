import Darwin
import Foundation

/// Provides authentic Darwin Mach host performance metrics directly from the kernel.
/// Zero synthetic sleeps, zero hardcoded percentages.
public enum DarwinMetrics {
    private static var previousTicks: (user: UInt32, sys: UInt32, idle: UInt32, nice: UInt32) = (0, 0, 0, 0)
    private static var hasPreviousTicks = false
    private static let lock = NSLock()

    /// Samples live CPU load percentage across all physical and efficiency cores.
    /// Returns a value in [0.0, 1.0].
    public static func sampleCPUUsage() -> Double {
        lock.lock()
        defer { lock.unlock() }

        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &cpuInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0.0 }

        let user = cpuInfo.cpu_ticks.0
        let sys = cpuInfo.cpu_ticks.1
        let idle = cpuInfo.cpu_ticks.2
        let nice = cpuInfo.cpu_ticks.3

        if !hasPreviousTicks {
            previousTicks = (user, sys, idle, nice)
            hasPreviousTicks = true
            let total = Double(user) + Double(sys) + Double(idle) + Double(nice)
            guard total > 0 else { return 0.0 }
            return min(1.0, max(0.0, (Double(user) + Double(sys) + Double(nice)) / total))
        }

        let userDiff = user >= previousTicks.user ? Double(user - previousTicks.user) : 0
        let sysDiff = sys >= previousTicks.sys ? Double(sys - previousTicks.sys) : 0
        let idleDiff = idle >= previousTicks.idle ? Double(idle - previousTicks.idle) : 0
        let niceDiff = nice >= previousTicks.nice ? Double(nice - previousTicks.nice) : 0

        previousTicks = (user, sys, idle, nice)

        let totalDiff = userDiff + sysDiff + idleDiff + niceDiff
        guard totalDiff > 0 else { return 0.0 }
        return min(1.0, max(0.0, (userDiff + sysDiff + niceDiff) / totalDiff))
    }
}

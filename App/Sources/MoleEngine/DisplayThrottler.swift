import Foundation

/// A high-performance generic batch coalescer operating at 60 Hz (16ms intervals by default).
/// Coalesces rapid streams of events (such as thousands of file scan events per second)
/// into batched arrays to allow smooth 120 fps ProMotion SwiftUI rendering without UI thread starvation.
public final class DisplayThrottler<T: Sendable>: @unchecked Sendable {
    private let interval: TimeInterval
    private let queue: DispatchQueue
    private let onBatch: ([T]) -> Void

    private let lock = NSLock()
    private var buffer: [T] = []
    private var timer: DispatchSourceTimer?
    private var isFinished = false

    /// Initializes a throttler with the specified interval and batch delivery callback.
    ///
    /// - Parameters:
    ///   - interval: Coalescing window in seconds (default: 0.016s ≈ 60 Hz / 16ms).
    ///   - queue: The dispatch queue on which timer events and batches will be delivered (default: .main).
    ///   - onBatch: Callback invoked with coalesced batches.
    public init(
        interval: TimeInterval = 0.016,
        queue: DispatchQueue = .main,
        onBatch: @escaping ([T]) -> Void
    ) {
        self.interval = max(0.001, interval)
        self.queue = queue
        self.onBatch = onBatch
        setupTimer()
    }

    deinit {
        finish()
    }

    /// Emits a single item into the accumulator buffer.
    public func emit(value: T) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        buffer.append(value)
        lock.unlock()
    }

    /// Emits multiple items into the accumulator buffer.
    public func emit(contentsOf values: [T]) {
        guard !values.isEmpty else { return }
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        buffer.append(contentsOf: values)
        lock.unlock()
    }

    /// Immediately flushes all currently buffered items to the consumer.
    public func flush() {
        let batch = drainBuffer()
        deliver(batch: batch, synchronous: true)
    }

    /// Flushes any pending items and permanently stops the throttler timer.
    public func finish() {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        timer?.cancel()
        timer = nil
        let batch = buffer
        buffer.removeAll()
        lock.unlock()

        deliver(batch: batch, synchronous: true)
    }

    private func setupTimer() {
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        let intervalMs = Int(interval * 1000)
        timer.schedule(
            deadline: .now() + .milliseconds(intervalMs),
            repeating: .milliseconds(intervalMs),
            leeway: .milliseconds(1)
        )
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let batch = self.drainBuffer()
            if !batch.isEmpty {
                self.onBatch(batch)
            }
        }
        timer.resume()
        self.timer = timer
    }

    private func drainBuffer() -> [T] {
        lock.lock()
        defer { lock.unlock() }
        guard !buffer.isEmpty else { return [] }
        let batch = buffer
        buffer.removeAll()
        return batch
    }

    private func deliver(batch: [T], synchronous: Bool) {
        guard !batch.isEmpty else { return }
        if synchronous {
            if queue === DispatchQueue.main {
                if Thread.isMainThread {
                    onBatch(batch)
                } else {
                    queue.sync {
                        self.onBatch(batch)
                    }
                }
            } else {
                onBatch(batch)
            }
        } else {
            queue.async { [onBatch] in
                onBatch(batch)
            }
        }
    }
}

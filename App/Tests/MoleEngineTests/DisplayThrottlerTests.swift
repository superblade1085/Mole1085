import XCTest
@testable import MoleEngine

final class DisplayThrottlerTests: XCTestCase {
    private actor BatchCollector {
        private(set) var batches: [[Int]] = []
        
        func append(_ batch: [Int]) -> Int {
            batches.append(batch)
            return batches.flatMap { $0 }.count
        }
        
        func getBatches() -> [[Int]] {
            batches
        }
    }

    private final class ThreadSafeBox<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: T

        init(_ value: T) {
            self.value = value
        }

        func get() -> T {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func set(_ newValue: T) {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }

        func mutate(_ transform: (inout T) -> Void) {
            lock.lock()
            defer { lock.unlock() }
            transform(&value)
        }
    }

    func testThrottlerBatchesRapidEmits() async throws {
        let expectation = expectation(description: "All items received")
        let collector = BatchCollector()
        let totalItems = 100

        let throttler = DisplayThrottler<Int>(interval: 0.016, queue: .global()) { batch in
            Task {
                let currentTotal = await collector.append(batch)
                if currentTotal == totalItems {
                    expectation.fulfill()
                }
            }
        }

        for i in 0..<totalItems {
            throttler.emit(value: i)
        }

        await fulfillment(of: [expectation], timeout: 2.0)
        throttler.finish()

        let batches = await collector.getBatches()
        let flattened = batches.flatMap { $0 }
        let batchCount = batches.count

        XCTAssertEqual(flattened, Array(0..<totalItems))
        // Verify coalescing occurred: should be far fewer batches than 100
        XCTAssertLessThan(batchCount, totalItems / 2, "Expected batch coalescing instead of one item per callback")
    }

    func testThrottlerFlushDeliversImmediately() async throws {
        let expectation = expectation(description: "Flush delivered")
        let box = ThreadSafeBox<[[String]]>([])
        let throttler = DisplayThrottler<String>(interval: 0.5, queue: .global()) { batch in
            box.mutate { $0.append(batch) }
            expectation.fulfill()
        }

        throttler.emit(value: "immediate_1")
        throttler.emit(value: "immediate_2")
        throttler.flush()

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(box.get(), [["immediate_1", "immediate_2"]])
        throttler.finish()
    }

    func testThrottlerMainQueueDeliveryDoesNotDeadlock() async throws {
        let expectation = expectation(description: "Delivered to main queue")
        let box = ThreadSafeBox<Bool>(false)

        let throttler = DisplayThrottler<String>(interval: 0.01, queue: .main) { batch in
            XCTAssertTrue(Thread.isMainThread)
            if batch.contains("ping") {
                box.set(true)
                expectation.fulfill()
            }
        }

        Task.detached {
            throttler.emit(value: "ping")
            throttler.flush()
        }

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertTrue(box.get())
        throttler.finish()
    }

    func testDisplayThrottlerInterleavedEmitsDuringDelivery() async throws {
        let expectation = expectation(description: "All 50 items received without stranded items")
        let collector = BatchCollector()
        let totalItems = 50

        let throttler = DisplayThrottler<Int>(interval: 0.016, queue: .global()) { batch in
            Task {
                let count = await collector.append(batch)
                if count == totalItems {
                    expectation.fulfill()
                }
            }
        }

        // Emit first batch
        for i in 0..<25 {
            throttler.emit(value: i)
        }

        // Interleave emissions during active coalescing
        Task.detached {
            try? await Task.sleep(nanoseconds: 12_000_000)
            for i in 25..<totalItems {
                throttler.emit(value: i)
            }
        }

        await fulfillment(of: [expectation], timeout: 2.0)
        let batches = await collector.getBatches()
        let all = batches.flatMap { $0 }
        XCTAssertEqual(all.sorted(), Array(0..<totalItems))
        throttler.finish()
    }
}

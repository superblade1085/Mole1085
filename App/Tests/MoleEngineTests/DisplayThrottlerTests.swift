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

    func testThrottlerFlushDeliversImmediately() {
        var receivedBatches: [[String]] = []
        let throttler = DisplayThrottler<String>(interval: 0.5, queue: .global()) { batch in
            receivedBatches.append(batch)
        }

        throttler.emit(value: "immediate_1")
        throttler.emit(value: "immediate_2")
        throttler.flush()

        XCTAssertEqual(receivedBatches, [["immediate_1", "immediate_2"]])
        throttler.finish()
    }
}

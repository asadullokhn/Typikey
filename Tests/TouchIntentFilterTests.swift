import XCTest
@testable import Typikey

final class TouchIntentFilterTests: XCTestCase {
    private let frames = [
        CGRect(x: 0, y: 0, width: 100, height: 100),
        CGRect(x: 100, y: 0, width: 100, height: 100),
        CGRect(x: 200, y: 0, width: 100, height: 100),
    ]

    func testStationaryTapSelectsLiftOffKeyAndFavorsItsCentroid() {
        var filter = TouchIntentFilter()
        XCTAssertNil(filter.consume(
            TouchSample(point: CGPoint(x: 49, y: 51), timestamp: 1, phase: .began),
            keyFrames: frames))

        let evidence = filter.consume(
            TouchSample(point: CGPoint(x: 51, y: 49), timestamp: 1.1, phase: .ended),
            keyFrames: frames)

        XCTAssertEqual(evidence?.intendedKeyIndex, 0)
        XCTAssertEqual(evidence?.filteredPoint.x ?? 0, 50, accuracy: 3)
        XCTAssertGreaterThan(evidence?.neighborLikelihoods[0] ?? 0,
                             evidence?.neighborLikelihoods[1] ?? 0)
    }

    func testSymmetricTremorRemainsNearCentroid() {
        var filter = TouchIntentFilter()
        let points: [CGFloat] = [50, 62, 39, 61, 40, 58, 42, 50]
        for (index, x) in points.enumerated() {
            let phase: TouchSample.Phase = index == 0 ? .began : .moved
            _ = filter.consume(
                TouchSample(point: CGPoint(x: x, y: 50),
                            timestamp: 2 + Double(index) * 0.02,
                            phase: phase),
                keyFrames: frames)
        }

        let evidence = filter.consume(
            TouchSample(point: CGPoint(x: 50, y: 50), timestamp: 2.2, phase: .ended),
            keyFrames: frames)

        XCTAssertEqual(evidence?.intendedKeyIndex, 0)
        XCTAssertEqual(evidence?.filteredPoint.x ?? 0, 50, accuracy: 10)
    }

    func testDeliberateSlideUsesLiftOffKey() {
        var filter = TouchIntentFilter()
        _ = filter.consume(
            TouchSample(point: CGPoint(x: 50, y: 50), timestamp: 3, phase: .began),
            keyFrames: frames)
        _ = filter.consume(
            TouchSample(point: CGPoint(x: 110, y: 50), timestamp: 3.1, phase: .moved),
            keyFrames: frames)
        let evidence = filter.consume(
            TouchSample(point: CGPoint(x: 150, y: 50), timestamp: 3.2, phase: .ended),
            keyFrames: frames)

        XCTAssertEqual(evidence?.intendedKeyIndex, 1)
        XCTAssertGreaterThan(evidence?.neighborLikelihoods[1] ?? 0,
                             evidence?.neighborLikelihoods[0] ?? 0)
    }

    func testFrameReplacementDropsOldTrace() {
        var filter = TouchIntentFilter()
        _ = filter.consume(
            TouchSample(point: CGPoint(x: 50, y: 50), timestamp: 4, phase: .began),
            keyFrames: frames)

        let rotated = [
            CGRect(x: 0, y: 0, width: 200, height: 50),
            CGRect(x: 0, y: 50, width: 200, height: 50),
        ]
        _ = filter.consume(
            TouchSample(point: CGPoint(x: 100, y: 75), timestamp: 4.1, phase: .moved),
            keyFrames: rotated)
        let evidence = filter.consume(
            TouchSample(point: CGPoint(x: 100, y: 75), timestamp: 4.2, phase: .ended),
            keyFrames: rotated)

        XCTAssertEqual(evidence?.intendedKeyIndex, 1)
        XCTAssertEqual(evidence?.filteredPoint.y ?? 0, 75, accuracy: 2)
    }

    func testCancellationClearsTrace() {
        var filter = TouchIntentFilter()
        _ = filter.consume(
            TouchSample(point: CGPoint(x: 50, y: 50), timestamp: 5, phase: .began),
            keyFrames: frames)
        XCTAssertNil(filter.consume(
            TouchSample(point: CGPoint(x: 80, y: 50), timestamp: 5.1, phase: .cancelled),
            keyFrames: frames))

        _ = filter.consume(
            TouchSample(point: CGPoint(x: 150, y: 50), timestamp: 6, phase: .began),
            keyFrames: frames)
        let evidence = filter.consume(
            TouchSample(point: CGPoint(x: 150, y: 50), timestamp: 6.1, phase: .ended),
            keyFrames: frames)
        XCTAssertEqual(evidence?.intendedKeyIndex, 1)
        XCTAssertEqual(evidence?.filteredPoint.x ?? 0, 150, accuracy: 2)
    }

    func testOutOfOrderSampleIsIgnored() {
        var filter = TouchIntentFilter()
        _ = filter.consume(
            TouchSample(point: CGPoint(x: 50, y: 50), timestamp: 7, phase: .began),
            keyFrames: frames)
        XCTAssertNil(filter.consume(
            TouchSample(point: CGPoint(x: 250, y: 50), timestamp: 6.9, phase: .moved),
            keyFrames: frames))
        let evidence = filter.consume(
            TouchSample(point: CGPoint(x: 50, y: 50), timestamp: 7.1, phase: .ended),
            keyFrames: frames)
        XCTAssertEqual(evidence?.intendedKeyIndex, 0)
        XCTAssertEqual(evidence?.filteredPoint.x ?? 0, 50, accuracy: 2)
    }

    func testProcessingP95BudgetIsBelowFiveMilliseconds() {
        var durations: [Double] = []
        durations.reserveCapacity(500)
        for trace in 0..<500 {
            var filter = TouchIntentFilter()
            let start = ContinuousClock.now
            for sample in 0..<12 {
                let phase: TouchSample.Phase = sample == 0 ? .began : (sample == 11 ? .ended : .moved)
                _ = filter.consume(
                    TouchSample(point: CGPoint(x: 48 + sample % 5, y: 50),
                                timestamp: Double(trace) + Double(sample) * 0.01,
                                phase: phase),
                    keyFrames: frames)
            }
            let elapsed = start.duration(to: .now).components
            durations.append(Double(elapsed.seconds) * 1_000
                + Double(elapsed.attoseconds) / 1_000_000_000_000_000)
        }
        durations.sort()
        let p95 = durations[Int(Double(durations.count - 1) * 0.95)]
        XCTAssertLessThan(p95, 5)
    }
}

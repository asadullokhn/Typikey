import CoreGraphics
import Foundation

struct TouchSample: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case began
        case moved
        case ended
        case cancelled
    }

    let point: CGPoint
    let timestamp: TimeInterval
    let phase: Phase
}

struct TouchEvidence: Equatable, Sendable {
    let filteredPoint: CGPoint
    let intendedKeyIndex: Int
    let neighborLikelihoods: [Int: Double]
}

struct TouchIntentFilter: Sendable {
    private var filteredPoint: CGPoint?
    private var velocity = CGVector.zero
    private var lastTimestamp: TimeInterval?
    private var keyFrames: [CGRect] = []

    mutating func consume(_ sample: TouchSample, keyFrames newFrames: [CGRect]) -> TouchEvidence? {
        guard !newFrames.isEmpty else {
            reset()
            return nil
        }
        if keyFrames != newFrames {
            resetTrace()
            keyFrames = newFrames
        }

        if sample.phase == .cancelled {
            reset()
            return nil
        }

        if sample.phase == .began {
            begin(at: sample.point, timestamp: sample.timestamp)
            return nil
        }

        guard let previousTimestamp = lastTimestamp,
              sample.timestamp >= previousTimestamp else {
            if filteredPoint == nil {
                begin(at: sample.point, timestamp: sample.timestamp)
            }
            return nil
        }

        update(to: sample.point,
               timestamp: sample.timestamp,
               ending: sample.phase == .ended)

        guard sample.phase == .ended,
              let filteredPoint,
              let selected = nearestKey(to: sample.point, in: newFrames) else {
            return nil
        }
        let evidence = TouchEvidence(
            filteredPoint: filteredPoint,
            intendedKeyIndex: selected,
            neighborLikelihoods: likelihoods(
                around: selected, point: filteredPoint, frames: newFrames))
        resetTrace()
        return evidence
    }

    mutating func reset() {
        resetTrace()
        keyFrames = []
    }

    private mutating func begin(at point: CGPoint, timestamp: TimeInterval) {
        filteredPoint = point
        velocity = .zero
        lastTimestamp = timestamp
    }

    private mutating func update(to measured: CGPoint,
                                 timestamp: TimeInterval,
                                 ending: Bool) {
        guard let filteredPoint, let lastTimestamp else {
            begin(at: measured, timestamp: timestamp)
            return
        }
        let elapsed = CGFloat(min(max(timestamp - lastTimestamp, 1.0 / 240.0), 0.1))
        let predicted = CGPoint(
            x: filteredPoint.x + velocity.dx * elapsed,
            y: filteredPoint.y + velocity.dy * elapsed)
        let residual = CGVector(
            dx: measured.x - predicted.x,
            dy: measured.y - predicted.y)
        let alpha: CGFloat = ending ? 0.8 : 0.55
        let beta: CGFloat = ending ? 0.2 : 0.15
        self.filteredPoint = CGPoint(
            x: predicted.x + alpha * residual.dx,
            y: predicted.y + alpha * residual.dy)
        velocity = CGVector(
            dx: velocity.dx + beta * residual.dx / elapsed,
            dy: velocity.dy + beta * residual.dy / elapsed)
        self.lastTimestamp = timestamp
    }

    private mutating func resetTrace() {
        filteredPoint = nil
        velocity = .zero
        lastTimestamp = nil
    }

    private func nearestKey(to point: CGPoint, in frames: [CGRect]) -> Int? {
        for (index, frame) in frames.enumerated() where frame.contains(point) {
            return index
        }
        return frames.indices.min { left, right in
            distanceSquared(from: point, to: frames[left].center)
                < distanceSquared(from: point, to: frames[right].center)
        }
    }

    private func likelihoods(around selected: Int,
                             point: CGPoint,
                             frames: [CGRect]) -> [Int: Double] {
        let selectedFrame = frames[selected]
        let nearbyRegion = selectedFrame.insetBy(
            dx: -selectedFrame.width * 0.35,
            dy: -selectedFrame.height * 0.35)
        var indexes = frames.indices.filter {
            $0 == selected || nearbyRegion.intersects(frames[$0])
        }
        if indexes.count == 1 {
            indexes = frames.indices.sorted {
                distanceSquared(from: selectedFrame.center, to: frames[$0].center)
                    < distanceSquared(from: selectedFrame.center, to: frames[$1].center)
            }.prefix(3).map { $0 }
        }

        let sigma = max(12, Double(min(selectedFrame.width, selectedFrame.height)) * 0.55)
        var weights: [Int: Double] = [:]
        var total = 0.0
        for index in indexes {
            let squared = Double(distanceSquared(from: point, to: frames[index].center))
            let weight = exp(-squared / (2 * sigma * sigma))
            weights[index] = weight
            total += weight
        }
        guard total > 0 else { return [selected: 1] }
        return weights.mapValues { $0 / total }
    }

    private func distanceSquared(from point: CGPoint, to other: CGPoint) -> CGFloat {
        let dx = point.x - other.x
        let dy = point.y - other.y
        return dx * dx + dy * dy
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

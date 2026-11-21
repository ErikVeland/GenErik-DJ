import Foundation

/// Positions use source frames. Contact X uses the retained surface width.
struct WaveformDragMotion {
    private(set) var frame: Double
    private(set) var velocity = 0.0
    private(set) var lastMovement: TimeInterval
    private var lastX: Double
    private var lastTime: TimeInterval
    let span: Double
    let limit: Double

    init(frame: Double, x: Double, time: TimeInterval, span: Double, limit: Double) {
        self.frame = frame
        lastX = x
        lastTime = time
        lastMovement = time
        self.span = span
        self.limit = limit
    }
    mutating func move(x: Double, time: TimeInterval) {
        let delta = -(x - lastX) * span
        let next = min(limit, max(0, frame + delta))
        velocity = (next - frame) / max(0.001, time - lastTime)
        frame = next
        lastX = x
        lastTime = time
        lastMovement = time
    }
}

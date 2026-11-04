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
    func coast(at time: TimeInterval) -> WaveformCoast? {
        guard time - lastMovement < 0.08, abs(velocity) / span > 0.02 else { return nil }
        return WaveformCoast(frame: frame, velocity: velocity, time: time, span: span, limit: limit)
    }
}

struct WaveformCoast {
    let frame: Double
    let velocity: Double
    let time: TimeInterval
    let span: Double
    let limit: Double

    func sample(at now: TimeInterval) -> (frame: Double, velocity: Double, finished: Bool) {
        let elapsed = max(0, now - time)
        // This is equivalent to a scroll deceleration factor of 0.998 per millisecond.
        let friction = -log(0.998) * 1000
        let decay = exp(-friction * elapsed)
        let proposed = frame + velocity * (1 - decay) / friction
        let bounded = min(limit, max(0, proposed))
        let finished = bounded != proposed || abs(velocity * decay) / span < 0.002
        return (bounded, finished ? 0 : velocity * decay, finished)
    }
}

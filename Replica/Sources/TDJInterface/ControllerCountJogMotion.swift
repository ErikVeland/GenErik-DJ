import Foundation

/**
 * Tracks count-based platter movement in source frames using the waveform motion contract.
 */
struct ControllerCountJogMotion {
    static let defaultResolution = 1024.0
    static let idleNanoseconds: UInt64 = 50_000_000
    let generation: UInt64
    let resolution: Double
    private var turns = 0.0
    private var motion: WaveformDragMotion
    var frame: Double { motion.frame }
    var velocity: Double { motion.velocity }

    static func validResolution(_ value: Double) -> Bool {
        value.isFinite && (16...65536).contains(value)
    }

    init?(frame: Double, generation: UInt64, sampleRate: Double, limit: Double, resolution: Double, time: TimeInterval)
    {
        guard frame.isFinite, limit.isFinite, limit >= 0, sampleRate.isFinite, sampleRate > 0,
            Self.validResolution(resolution), time.isFinite
        else { return nil }
        self.generation = generation
        self.resolution = resolution
        motion = .init(
            frame: min(limit, max(0, frame)), x: 0, time: time - 1.0 / 60, span: sampleRate * 1.8, limit: limit)
    }

    mutating func move(counts: Double, time: TimeInterval) {
        let next = turns - counts / resolution
        guard counts.isFinite, next.isFinite, time.isFinite, time >= motion.lastMovement else { return }
        turns = next
        motion.move(x: turns, time: time)
    }
}

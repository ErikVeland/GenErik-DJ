import Foundation

/// Maps the Transpose Stretch effect to a semitone offset and matches compatible deck keys.
public enum KeyShift {
    public static func semitones(for position: Double) -> Double? {
        guard position.isFinite, (0...1).contains(position) else { return nil }
        return (position - 0.5) * (position <= 0.5 ? 120 : 24)
    }

    public static func position(for semitones: Double) -> Double? {
        guard semitones.isFinite, (-60...12).contains(semitones) else { return nil }
        return semitones <= 0 ? 0.5 + semitones / 120 : 0.5 + semitones / 24
    }

    /// Returns the shortest semitone change when both keys have the same mode.
    public static func matchOffset(from source: MusicalKey, to target: MusicalKey) -> Int? {
        guard source.mode == target.mode else { return nil }
        let upward = (target.tonic - source.tonic + 12) % 12
        return upward > 6 ? upward - 12 : upward
    }
}

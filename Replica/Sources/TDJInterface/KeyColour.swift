import SwiftUI
import TDJCore

/// Keys in colour around the Open Key wheel: neighbours share nearby hues, major keys are lighter.
enum KeyColour {
    static func hue(_ key: MusicalKey) -> Double {
        let relativeMajor = key.mode == .major ? key.tonic : (key.tonic + 3) % 12
        return Double((relativeMajor * 7) % 12) / 12
    }
    static func colour(_ key: MusicalKey?) -> Color {
        guard let key else { return PerformancePalette.secondaryText }
        return Color(hue: hue(key), saturation: 0.55, brightness: key.mode == .major ? 0.98 : 0.82)
    }
}
